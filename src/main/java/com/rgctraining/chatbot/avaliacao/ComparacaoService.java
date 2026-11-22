package com.rgctraining.chatbot.avaliacao;

import com.rgctraining.chatbot.model.Intent;
import com.rgctraining.chatbot.model.TestCase;
import com.rgctraining.chatbot.model.TrainingPhrase;
import com.rgctraining.chatbot.nlp.NaiveBayes;
import com.rgctraining.chatbot.nlp.Preprocessador;
import com.rgctraining.chatbot.repository.IntentRepository;
import com.rgctraining.chatbot.repository.TestCaseRepository;
import com.rgctraining.chatbot.repository.TrainingPhraseRepository;
import com.rgctraining.chatbot.service.ChatService;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/**
 * Compara o classificador do chat (TF-IDF + cosseno + regras de decisão) com um
 * baseline simples (Naive Bayes multinomial, sem regras) nos mesmos test_cases.
 * Somente leitura: não grava em test_cases nem em conversations.
 */
@Service
public class ComparacaoService {

    public record Resumo(int total, int acertosEstrito, double acuraciaEstrita,
                         int acertosEquivalencia, double acuraciaEquivalencia) {}

    public record Desempenho(String descricao, Resumo geral, Map<String, Resumo> porTipo) {}

    public record Comparacao(int totalCasos, Map<String, Desempenho> classificadores) {}

    private final TestCaseRepository testCaseRepository;
    private final TrainingPhraseRepository trainingPhraseRepository;
    private final IntentRepository intentRepository;
    private final ChatService chatService;
    // baseline simples de propósito: sem tratamento de negação
    private final Preprocessador preprocessador = new Preprocessador(Preprocessador.ModoNegacao.IGNORAR);

    public ComparacaoService(TestCaseRepository testCaseRepository,
                             TrainingPhraseRepository trainingPhraseRepository,
                             IntentRepository intentRepository,
                             ChatService chatService) {
        this.testCaseRepository = testCaseRepository;
        this.trainingPhraseRepository = trainingPhraseRepository;
        this.intentRepository = intentRepository;
        this.chatService = chatService;
    }

    @Transactional(readOnly = true)
    public Comparacao comparar() {
        List<TestCase> casos = testCaseRepository.findAllByOrderByIdAsc();
        NaiveBayes nb = montarBaseline();

        List<ResultadoCaso> tfidf = new ArrayList<>();
        List<ResultadoCaso> baseline = new ArrayList<>();
        for (TestCase c : casos) {
            ChatService.RespostaChat r = chatService.gerarResposta(c.getPergunta());
            tfidf.add(resultado(c, r.intentDetectado(), r.score()));
            baseline.add(resultado(c, nb.classificar(preprocessador.processar(c.getPergunta())), 0.0));
        }

        Map<String, Desempenho> mapa = new LinkedHashMap<>();
        mapa.put("tfidf", desempenho("TF-IDF + cosseno 1-NN + regras de decisão (o mesmo do /api/chat, sem contexto)", tfidf));
        mapa.put("baseline", desempenho("Naive Bayes multinomial (Laplace), sem limiar nem regras; fallback só se nenhum token é conhecido", baseline));
        return new Comparacao(casos.size(), mapa);
    }

    private NaiveBayes montarBaseline() {
        Map<Long, String> codigoPorId = new HashMap<>();
        for (Intent i : intentRepository.findAll()) codigoPorId.put(i.getId(), i.getCodigo());
        List<List<String>> docs = new ArrayList<>();
        List<String> intents = new ArrayList<>();
        for (TrainingPhrase f : trainingPhraseRepository.findAll()) {
            docs.add(preprocessador.processar(f.getTexto()));
            intents.add(codigoPorId.get(f.getIntentId()));
        }
        return new NaiveBayes(docs, intents);
    }

    private static ResultadoCaso resultado(TestCase c, String obtida, double score) {
        return new ResultadoCaso(c.getId(), c.getPergunta(), c.getTipo(), c.getIntentEsperada(), obtida, score);
    }

    private static Desempenho desempenho(String descricao, List<ResultadoCaso> resultados) {
        MetricasAvaliacao m = MetricasAvaliacao.calcular(resultados);
        Map<String, Resumo> porTipo = new LinkedHashMap<>();
        m.porTipo().forEach((tipo, t) -> porTipo.put(tipo,
                new Resumo(t.total(), t.acertos(), t.acuracia(), t.acertosEquivalencia(), t.acuraciaEquivalencia())));
        return new Desempenho(descricao,
                new Resumo(m.total(), m.acertos(), m.acuracia(), m.acertosEquivalencia(), m.acuraciaEquivalencia()),
                porTipo);
    }
}
