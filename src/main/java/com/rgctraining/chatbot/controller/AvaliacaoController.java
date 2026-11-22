package com.rgctraining.chatbot.controller;

import com.rgctraining.chatbot.avaliacao.AvaliacaoService;
import com.rgctraining.chatbot.avaliacao.CalibracaoService;
import com.rgctraining.chatbot.avaliacao.ComparacaoService;
import com.rgctraining.chatbot.security.AdminKeyGuard;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.nio.charset.StandardCharsets;

/**
 * Avaliação do classificador com os casos de teste do banco (test_cases).
 * Endpoints de dev: exigem o header X-Admin-Key.
 */
@RestController
@RequestMapping("/api/avaliacao")
public class AvaliacaoController {

    private final AvaliacaoService avaliacaoService;
    private final CalibracaoService calibracaoService;
    private final ComparacaoService comparacaoService;
    private final AdminKeyGuard adminKeyGuard;

    public AvaliacaoController(AvaliacaoService avaliacaoService, CalibracaoService calibracaoService,
                               ComparacaoService comparacaoService,
                               AdminKeyGuard adminKeyGuard) {
        this.avaliacaoService = avaliacaoService;
        this.calibracaoService = calibracaoService;
        this.comparacaoService = comparacaoService;
        this.adminKeyGuard = adminKeyGuard;
    }

    /** Executa todos os casos de teste, grava o resultado em test_cases e devolve as métricas. */
    @PostMapping
    public AvaliacaoService.Avaliacao executar(@RequestHeader(value = "X-Admin-Key", required = false) String chave) {
        adminKeyGuard.exigir(chave);
        return avaliacaoService.executar();
    }

    /**
     * Roda os casos de teste no TF-IDF (com as regras do chat) e no baseline Naive Bayes e
     * devolve acurácia estrita e com equivalência de cada um, geral e por tipo. Não grava nada.
     */
    @GetMapping("/comparacao")
    public ComparacaoService.Comparacao comparacao(@RequestHeader(value = "X-Admin-Key", required = false) String chave) {
        adminKeyGuard.exigir(chave);
        return comparacaoService.comparar();
    }

    /** Métricas da última execução, sem rodar de novo. */
    @GetMapping
    public AvaliacaoService.Avaliacao ultima(@RequestHeader(value = "X-Admin-Key", required = false) String chave) {
        adminKeyGuard.exigir(chave);
        return avaliacaoService.ultimaExecucao();
    }

    /** Planilha da última execução (CSV para Excel em pt-BR). */
    @GetMapping("/casos.csv")
    public ResponseEntity<byte[]> csv(@RequestHeader(value = "X-Admin-Key", required = false) String chave) {
        adminKeyGuard.exigir(chave);
        return ResponseEntity.ok()
                .header(HttpHeaders.CONTENT_DISPOSITION, "attachment; filename=\"casos-de-teste.csv\"")
                .contentType(new MediaType("text", "csv", StandardCharsets.UTF_8))
                .body(avaliacaoService.exportarCsv().getBytes(StandardCharsets.UTF_8));
    }

    /**
     * Varredura leave-one-out (limiar x margem x fração) só sobre as frases de treino,
     * em CSV. Demora alguns segundos. Parâmetro opcional "negacao" para comparar os modos.
     */
    @GetMapping("/calibracao")
    public ResponseEntity<byte[]> calibracao(@RequestHeader(value = "X-Admin-Key", required = false) String chave,
                                             @RequestParam(value = "negacao", required = false) String negacao) {
        adminKeyGuard.exigir(chave);
        return ResponseEntity.ok()
                .contentType(new MediaType("text", "csv", StandardCharsets.UTF_8))
                .body(calibracaoService.varreduraCsv(negacao).getBytes(StandardCharsets.UTF_8));
    }
}
