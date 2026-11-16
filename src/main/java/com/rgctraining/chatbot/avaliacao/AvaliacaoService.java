package com.rgctraining.chatbot.avaliacao;

import com.rgctraining.chatbot.model.TestCase;
import com.rgctraining.chatbot.repository.TestCaseRepository;
import com.rgctraining.chatbot.service.ChatService;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.time.temporal.ChronoUnit;
import java.util.List;
import java.util.Locale;
import java.util.Objects;

/**
 * Executor dos casos de teste (tabela test_cases).
 *
 * Roda cada pergunta pela MESMA decisão do /api/chat (classificação + limiar
 * de fallback), sem gravar em conversations, e salva o resultado de volta na
 * própria tabela. As métricas saem de {@link MetricasAvaliacao}.
 */
@Service
public class AvaliacaoService {

    public record Avaliacao(LocalDateTime executadoEm, double limiarFallback, MetricasAvaliacao metricas) {}

    private final TestCaseRepository testCaseRepository;
    private final ChatService chatService;

    public AvaliacaoService(TestCaseRepository testCaseRepository, ChatService chatService) {
        this.testCaseRepository = testCaseRepository;
        this.chatService = chatService;
    }

    /** Executa todos os casos de teste, grava os resultados e devolve as métricas. */
    @Transactional
    public Avaliacao executar() {
        LocalDateTime agora = LocalDateTime.now().truncatedTo(ChronoUnit.SECONDS);
        List<TestCase> casos = testCaseRepository.findAllByOrderByIdAsc();

        for (TestCase caso : casos) {
            ChatService.RespostaChat r = chatService.gerarResposta(caso.getPergunta());
            caso.setIntentObtida(r.intentDetectado());
            caso.setScore(r.score());
            caso.setRespostaObtida(r.resposta());
            caso.setResultado(Objects.equals(caso.getIntentEsperada(), r.intentDetectado()) ? "ACERTO" : "ERRO");
            caso.setExecutadoEm(agora);
        }
        testCaseRepository.saveAll(casos);

        return new Avaliacao(agora, chatService.getLimiarFallback(), MetricasAvaliacao.calcular(resultados(casos)));
    }

    /** Métricas da última execução gravada, sem rodar de novo. */
    @Transactional(readOnly = true)
    public Avaliacao ultimaExecucao() {
        List<TestCase> executados = executados();
        LocalDateTime quando = executados.stream()
                .map(TestCase::getExecutadoEm).max(LocalDateTime::compareTo).orElse(null);
        return new Avaliacao(quando, chatService.getLimiarFallback(), MetricasAvaliacao.calcular(resultados(executados)));
    }

    /**
     * Resultados da última execução em CSV (a planilha de testes da entrega).
     * Separador ";" e decimal com vírgula, para abrir direto no Excel em pt-BR.
     */
    @Transactional(readOnly = true)
    public String exportarCsv() {
        StringBuilder sb = new StringBuilder("﻿"); // BOM: o Excel reconhece UTF-8 (acentos)
        sb.append("id;tipo;pergunta;intent_esperada;intent_obtida;score;resultado;resposta_obtida;executado_em\n");
        for (TestCase c : executados()) {
            sb.append(c.getId()).append(';')
              .append(campo(c.getTipo())).append(';')
              .append(campo(c.getPergunta())).append(';')
              .append(campo(nomeOuFallback(c.getIntentEsperada()))).append(';')
              .append(campo(nomeOuFallback(c.getIntentObtida()))).append(';')
              .append(c.getScore() == null ? "" : String.format(new Locale("pt", "BR"), "%.4f", c.getScore())).append(';')
              .append(campo(c.getResultado())).append(';')
              .append(campo(c.getRespostaObtida())).append(';')
              .append(c.getExecutadoEm()).append('\n');
        }
        return sb.toString();
    }

    private List<TestCase> executados() {
        return testCaseRepository.findAllByOrderByIdAsc().stream()
                .filter(c -> c.getExecutadoEm() != null)
                .toList();
    }

    private static List<ResultadoCaso> resultados(List<TestCase> casos) {
        return casos.stream()
                .map(c -> new ResultadoCaso(c.getId(), c.getPergunta(), c.getTipo(),
                        c.getIntentEsperada(), c.getIntentObtida(),
                        c.getScore() == null ? 0.0 : c.getScore()))
                .toList();
    }

    private static String nomeOuFallback(String intent) {
        return intent == null ? MetricasAvaliacao.FALLBACK : intent;
    }

    /** Escapa um campo de CSV: entre aspas, com aspas internas duplicadas. */
    private static String campo(String valor) {
        if (valor == null) return "";
        return '"' + valor.replace("\"", "\"\"").replace("\r", " ").replace("\n", " ") + '"';
    }
}
