package com.rgctraining.chatbot.service;

import com.rgctraining.chatbot.model.BotResponse;
import com.rgctraining.chatbot.model.Conversation;
import com.rgctraining.chatbot.model.Intent;
import com.rgctraining.chatbot.repository.BotResponseRepository;
import com.rgctraining.chatbot.repository.ConversationRepository;
import com.rgctraining.chatbot.repository.IntentRepository;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import java.util.List;
import java.util.Map;
import java.util.Random;
import java.util.concurrent.ConcurrentHashMap;

@Service
public class ChatService {

    private static final String RESPOSTA_FALLBACK =
            "Não entendi bem sua pergunta. Vou encaminhar para um atendente humano da Academia RGC Training te responder em breve.";

    private final IntentClassifierService classifierService;
    private final BotResponseRepository botResponseRepository;
    private final IntentRepository intentRepository;
    private final ConversationRepository conversationRepository;
    private final Random random = new Random();

    // contexto mínimo: última intenção detectada por sessão (em memória)
    private final Map<String, String> ultimaIntentPorSessao = new ConcurrentHashMap<>();

    @Value("${chatbot.fallback-threshold:0.18}")
    private double limiarFallback;

    public ChatService(IntentClassifierService classifierService,
                        BotResponseRepository botResponseRepository,
                        IntentRepository intentRepository,
                        ConversationRepository conversationRepository) {
        this.classifierService = classifierService;
        this.botResponseRepository = botResponseRepository;
        this.intentRepository = intentRepository;
        this.conversationRepository = conversationRepository;
    }

    public record RespostaChat(String resposta, String intentDetectado, double score, boolean fallback) {}

    public RespostaChat responder(String sessionId, String mensagem) {
        IntentClassifierService.Classificacao classificacao = classifierService.classificar(mensagem);

        boolean fallback = classificacao.intentCodigo() == null || classificacao.score() < limiarFallback;
        String resposta;
        String intentDetectado;

        if (fallback) {
            resposta = RESPOSTA_FALLBACK;
            intentDetectado = null;
        } else {
            intentDetectado = classificacao.intentCodigo();
            resposta = buscarRespostaAleatoria(intentDetectado);
            ultimaIntentPorSessao.put(sessionId, intentDetectado);
        }

        registrarLog(sessionId, mensagem, intentDetectado, classificacao.score(), resposta);
        return new RespostaChat(resposta, intentDetectado, classificacao.score(), fallback);
    }

    private String buscarRespostaAleatoria(String intentCodigo) {
        Intent intent = intentRepository.findAll().stream()
                .filter(i -> i.getCodigo().equals(intentCodigo))
                .findFirst()
                .orElse(null);
        if (intent == null) {
            return RESPOSTA_FALLBACK;
        }
        List<BotResponse> respostas = botResponseRepository.findByIntentId(intent.getId());
        if (respostas.isEmpty()) {
            return RESPOSTA_FALLBACK;
        }
        return respostas.get(random.nextInt(respostas.size())).getTexto();
    }

    private void registrarLog(String sessionId, String mensagem, String intent, double score, String resposta) {
        Conversation c = new Conversation();
        c.setSessionId(sessionId);
        c.setMensagemUsuario(mensagem);
        c.setIntentDetectado(intent);
        c.setScore(score);
        c.setResposta(resposta);
        conversationRepository.save(c);
    }
}
