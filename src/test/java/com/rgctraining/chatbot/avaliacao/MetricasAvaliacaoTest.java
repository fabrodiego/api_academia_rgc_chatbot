package com.rgctraining.chatbot.avaliacao;

import org.junit.jupiter.api.Test;

import java.util.List;

import static org.junit.jupiter.api.Assertions.*;

class MetricasAvaliacaoTest {

    private static final double DELTA = 1e-9;

    private final List<ResultadoCaso> casos = List.of(
            new ResultadoCaso(1L, "oi", "padrao", "saudacao", "saudacao", 1.0),
            new ResultadoCaso(2L, "bom diaaa", "dificil", "saudacao", null, 0.0),
            new ResultadoCaso(3L, "quanto custa", "padrao", "planos_valores", "planos_valores", 0.8),
            new ResultadoCaso(4L, "quero uma pizza", "fora_escopo", null, null, 0.1),
            new ResultadoCaso(5L, "trocar o pneu", "fora_escopo", null, "troca_plano", 0.5));

    private final MetricasAvaliacao m = MetricasAvaliacao.calcular(casos);

    @Test
    void acuraciaUsaCriterioEstrito() {
        assertEquals(5, m.total());
        assertEquals(3, m.acertos());
        assertEquals(0.6, m.acuracia(), DELTA);
        // sem pares equivalentes neste conjunto: as duas acuracias coincidem
        assertEquals(3, m.acertosEquivalencia());
        assertEquals(0.6, m.acuraciaEquivalencia(), DELTA);
    }

    @Test
    void fallbackEsperadoSoAcertaSeCairNoFallback() {
        assertTrue(casos.get(3).acerto());
        assertFalse(casos.get(4).acerto());
    }

    @Test
    void taxaDeFallbackContaRespostasSemIntent() {
        assertEquals(2.0 / 5, m.taxaFallback(), DELTA);
    }

    @Test
    void acuraciaPorTipo() {
        assertEquals(new MetricasAvaliacao.PorTipo(2, 2, 1.0, 2, 1.0), m.porTipo().get("padrao"));
        assertEquals(new MetricasAvaliacao.PorTipo(1, 0, 0.0, 0, 0.0), m.porTipo().get("dificil"));
        assertEquals(new MetricasAvaliacao.PorTipo(2, 1, 0.5, 1, 0.5), m.porTipo().get("fora_escopo"));
    }

    @Test
    void matrizDeConfusaoTrataFallbackComoClasse() {
        String fb = MetricasAvaliacao.FALLBACK;
        assertEquals(1, m.matrizConfusao().get("saudacao").get(fb));
        assertEquals(1, m.matrizConfusao().get(fb).get("troca_plano"));
        assertEquals(1, m.matrizConfusao().get(fb).get(fb));
    }

    @Test
    void precisaoERecallPorClasse() {
        var saudacao = m.porClasse().get("saudacao");
        assertEquals(1.0, saudacao.precisao(), DELTA);
        assertEquals(0.5, saudacao.recall(), DELTA);

        var fallback = m.porClasse().get(MetricasAvaliacao.FALLBACK);
        assertEquals(0.5, fallback.precisao(), DELTA); // 1 certo de 2 previstos
        assertEquals(0.5, fallback.recall(), DELTA);   // 1 certo de 2 esperados
    }

    @Test
    void macroUsaSoClassesEsperadas() {
        // esperadas: saudacao, planos_valores, (fallback); troca_plano fica de fora
        assertEquals((1.0 + 1.0 + 0.5) / 3, m.precisaoMacro(), DELTA);
        assertEquals((0.5 + 1.0 + 0.5) / 3, m.recallMacro(), DELTA);
    }

    @Test
    void listaSoOsErros() {
        assertEquals(List.of(2L, 5L), m.erros().stream().map(ResultadoCaso::id).toList());
    }

    @Test
    void duasAcuraciasComEquivalencia() {
        var lista = List.of(
                new ResultadoCaso(1L, "a", "padrao", "planos_valores", "plano_anual", 0.9),   // pai->filha
                new ResultadoCaso(2L, "b", "padrao", "plano_anual", "planos_valores", 0.9),   // filha->pai
                new ResultadoCaso(3L, "c", "fora_escopo", null, "fora_escopo", 0.9),          // NULL+fora_escopo
                new ResultadoCaso(4L, "d", "fora_escopo", null, null, 0.1),                   // NULL+fallback
                new ResultadoCaso(5L, "e", "fora_escopo", null, "contato", 0.6),              // NULL+negocio
                new ResultadoCaso(6L, "f", "padrao", "saudacao", "saudacao", 1.0));           // igual
        var r = MetricasAvaliacao.calcular(lista);
        assertEquals(2, r.acertos());
        assertEquals(2.0 / 6, r.acuracia(), DELTA);
        assertEquals(4, r.acertosEquivalencia());
        assertEquals(4.0 / 6, r.acuraciaEquivalencia(), DELTA);
        assertEquals(List.of(1L, 3L), r.acertosPorEquivalencia().stream().map(ResultadoCaso::id).toList());
        assertEquals(List.of(2L, 5L), r.erros().stream().map(ResultadoCaso::id).toList());
        assertEquals(new MetricasAvaliacao.PorTipo(3, 1, 1.0 / 3, 2, 2.0 / 3), r.porTipo().get("fora_escopo"));
        // a matriz mantem a intent obtida real
        assertEquals(1, r.matrizConfusao().get("planos_valores").get("plano_anual"));
        assertEquals(1, r.matrizConfusao().get(MetricasAvaliacao.FALLBACK).get("fora_escopo"));
    }

    @Test
    void listaVaziaNaoQuebra() {
        var vazia = MetricasAvaliacao.calcular(List.of());
        assertEquals(0, vazia.total());
        assertEquals(0.0, vazia.acuracia(), DELTA);
    }
}
