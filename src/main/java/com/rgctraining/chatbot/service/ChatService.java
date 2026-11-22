package com.rgctraining.chatbot.service;

import com.rgctraining.chatbot.model.BotResponse;
import com.rgctraining.chatbot.model.Conversation;
import com.rgctraining.chatbot.model.Intent;
import com.rgctraining.chatbot.nlp.ClassificadorTfIdf;
import com.rgctraining.chatbot.repository.BotResponseRepository;
import com.rgctraining.chatbot.repository.ConversationRepository;
import com.rgctraining.chatbot.repository.IntentRepository;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import java.util.List;
import java.util.Random;
import java.time.Clock;
import java.time.Duration;

@Service
public class ChatService {

    private static final String RESPOSTA_FALLBACK =
            "Não entendi bem sua pergunta. Vou encaminhar para um atendente humano da Academia RGC Training te responder em breve.";

    public static final String SESSAO_ANONIMA = "anonimo";

    private final IntentClassifierService classifierService;
    private final BotResponseRepository botResponseRepository;
    private final IntentRepository intentRepository;
    private final ConversationRepository conversationRepository;
    private final Random random = new Random();

    // contexto mínimo: última intenção respondida por sessão (em memória, com TTL e tamanho máximo)
    private final ContextoSessao ultimaIntentPorSessao;

    private final PoliticaDecisao politica;

    public ChatService(IntentClassifierService classifierService,
                        BotResponseRepository botResponseRepository,
                        IntentRepository intentRepository,
                        ConversationRepository conversationRepository,
                        @Value("${chatbot.fallback-threshold:0.18}") double limiar,
                        @Value("${chatbot.margem-minima:0.0}") double margemMinima,
                        @Value("${chatbot.fracao-minima-conhecida:0.0}") double fracaoMinima,
                        @Value("${chatbot.contexto.ttl-minutos:30}") long ttlMinutos,
                        @Value("${chatbot.contexto.max-sessoes:10000}") int maxSessoes) {
        this.ultimaIntentPorSessao = new ContextoSessao(Duration.ofMinutes(ttlMinutos), maxSessoes, Clock.systemUTC());
        this.politica = new PoliticaDecisao(limiar, margemMinima, fracaoMinima);
        this.classifierService = classifierService;
        this.botResponseRepository = botResponseRepository;
        this.intentRepository = intentRepository;
        this.conversationRepository = conversationRepository;
    }

    public record RespostaChat(String resposta, String intentDetectado, double score, boolean fallback) {}

    public RespostaChat responder(String sessionId, String mensagem) {
        RespostaChat r = gerarResposta(mensagem, ultimaIntentDa(sessionId));
        if (!r.fallback() && usaContexto(sessionId)) {
            ultimaIntentPorSessao.registrar(sessionId, r.intentDetectado());
        }
        registrarLog(sessionId, mensagem, r.intentDetectado(), r.score(), r.resposta());
        return r;
    }

    /**
     * Decide a resposta sem gravar nada e sem contexto de sessão (classificação +
     * regras de decisão). Usada pelo executor de casos de teste, que são perguntas isoladas.
     */
    public RespostaChat gerarResposta(String mensagem) {
        return gerarResposta(mensagem, null);
    }

    public RespostaChat gerarResposta(String mensagem, String ultimaIntent) {
        Analise a = analisar(mensagem, ultimaIntent);
        if (a.decisao().fallback()) {
            return new RespostaChat(RESPOSTA_FALLBACK, null, a.decisao().score(), true);
        }
        String intent = a.decisao().intent();
        return new RespostaChat(buscarRespostaAleatoria(intent), intent, a.decisao().score(), false);
    }

    /** Classificação + decisão, sem montar resposta nem gravar nada. */
    public record Analise(ClassificadorTfIdf.Classificacao classificacao, PoliticaDecisao.Decisao decisao) {}

    public Analise analisar(String mensagem, String ultimaIntent) {
        ClassificadorTfIdf.Classificacao classificacao = classifierService.classificar(mensagem);
        return new Analise(classificacao, politica.decidir(classificacao, ultimaIntent));
    }

    /** Última intent da sessão (só leitura); null se não há, expirou ou a sessão é anônima. */
    public String ultimaIntentDa(String sessionId) {
        return usaContexto(sessionId) ? ultimaIntentPorSessao.ultimaIntent(sessionId).orElse(null) : null;
    }

    // sem sessionId o controller usa "anonimo", compartilhado por todo mundo: não vale como contexto
    private static boolean usaContexto(String sessionId) {
        return sessionId != null && !SESSAO_ANONIMA.equals(sessionId);
    }

    public double getLimiarFallback() {
        return politica.getLimiar();
    }

    private String buscarRespostaAleatoria(String intentCodigo) {
        Intent intent = intentRepository.findByCodigo(intentCodigo).orElse(null);
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
