package com.rgctraining.chatbot.service;

import com.rgctraining.chatbot.nlp.ClassificadorTfIdf.Candidato;
import com.rgctraining.chatbot.nlp.ClassificadorTfIdf.Classificacao;
import com.rgctraining.chatbot.service.PoliticaDecisao.Decisao;
import com.rgctraining.chatbot.service.PoliticaDecisao.Motivo;
import org.junit.jupiter.api.Test;

import java.util.List;

import static org.junit.jupiter.api.Assertions.*;

class PoliticaDecisaoTest {

    // limiar 0.40, margem mínima 0.10, fração mínima 0.5
    private final PoliticaDecisao politica = new PoliticaDecisao(0.40, 0.10, 0.5);

    private static Classificacao classif(double fracao, String i1, double s1, String i2, double s2) {
        return new Classificacao(i1, s1, List.of(new Candidato(i1, s1), new Candidato(i2, s2)), List.of("x"), fracao);
    }

    @Test
    void respondeQuandoTudoPassa() {
        Decisao d = politica.decidir(classif(1.0, "horario", 0.9, "planos", 0.2));
        assertFalse(d.fallback());
        assertEquals("horario", d.intent());
        assertEquals(Motivo.OK, d.motivo());
    }

    @Test
    void scoreBaixoVaiParaFallback() {
        Decisao d = politica.decidir(classif(1.0, "horario", 0.30, "planos", 0.0));
        assertTrue(d.fallback());
        assertNull(d.intent());
        assertEquals(Motivo.SCORE_BAIXO, d.motivo());
    }

    @Test
    void scoreIgualAoLimiarAindaResponde() {
        assertFalse(politica.decidir(classif(1.0, "horario", 0.40, "planos", 0.0)).fallback());
    }

    @Test
    void margemPequenaSemContextoVaiParaFallback() {
        Decisao d = politica.decidir(classif(1.0, "plano_mensal", 0.80, "plano_anual", 0.75));
        assertTrue(d.fallback());
        assertEquals(Motivo.MARGEM_PEQUENA, d.motivo());
    }

    @Test
    void tokensDesconhecidosVaiParaFallbackMesmoComScoreAlto() {
        Decisao d = politica.decidir(classif(0.4, "horario", 0.95, "planos", 0.1));
        assertTrue(d.fallback());
        assertEquals(Motivo.TOKENS_DESCONHECIDOS, d.motivo());
    }

    @Test
    void semCandidatoVaiParaFallbackPorTokensDesconhecidos() {
        Decisao d = politica.decidir(Classificacao.vazia(List.of(), 0.0));
        assertTrue(d.fallback());
        assertEquals(Motivo.TOKENS_DESCONHECIDOS, d.motivo());
    }

    @Test
    void ordemDasRegrasFracaoDepoisScoreDepoisMargem() {
        // falha nas três: o motivo é o da primeira regra
        assertEquals(Motivo.TOKENS_DESCONHECIDOS, politica.decidir(classif(0.1, "a", 0.2, "b", 0.19)).motivo());
        // fração ok, falha em score e margem: score_baixo
        assertEquals(Motivo.SCORE_BAIXO, politica.decidir(classif(1.0, "a", 0.2, "b", 0.19)).motivo());
    }

    @Test
    void contextoDesempataParaASegundaQuandoEUltimaIntentDaSessao() {
        Decisao d = politica.decidir(classif(1.0, "plano_mensal", 0.80, "plano_anual", 0.78), "plano_anual");
        assertFalse(d.fallback());
        assertEquals("plano_anual", d.intent());
        assertEquals(0.78, d.score());
        assertEquals(Motivo.CONTEXTO, d.motivo());
    }

    @Test
    void contextoDesempataParaAPrimeiraQuandoEUltimaIntentDaSessao() {
        Decisao d = politica.decidir(classif(1.0, "plano_mensal", 0.80, "plano_anual", 0.78), "plano_mensal");
        assertEquals("plano_mensal", d.intent());
        assertEquals(Motivo.CONTEXTO, d.motivo());
    }

    @Test
    void contextoAceitaIntentDaMesmaFamilia() {
        // última = planos_valores (pai); as duas candidatas são filhas dele: fica a 1ª
        Decisao d = politica.decidir(classif(1.0, "plano_mensal", 0.80, "plano_anual", 0.78), "planos_valores");
        assertEquals("plano_mensal", d.intent());
        assertEquals(Motivo.CONTEXTO, d.motivo());
        // última = plano_trimestral (irmã): também é da família
        assertEquals(Motivo.CONTEXTO,
                politica.decidir(classif(1.0, "plano_mensal", 0.80, "plano_anual", 0.78), "plano_trimestral").motivo());
    }

    @Test
    void contextoDeOutraFamiliaNaoDesempata() {
        Decisao d = politica.decidir(classif(1.0, "plano_mensal", 0.80, "plano_anual", 0.78), "horario_funcionamento");
        assertTrue(d.fallback());
        assertEquals(Motivo.MARGEM_PEQUENA, d.motivo());
    }

    @Test
    void contextoNaoInterfereQuandoAMargemEGrande() {
        Decisao d = politica.decidir(classif(1.0, "plano_mensal", 0.90, "plano_anual", 0.30), "plano_anual");
        assertEquals("plano_mensal", d.intent());
        assertEquals(Motivo.OK, d.motivo());
    }

    @Test
    void contextoNaoSalvaScoreBaixoNemTokensDesconhecidos() {
        assertEquals(Motivo.SCORE_BAIXO,
                politica.decidir(classif(1.0, "plano_mensal", 0.20, "plano_anual", 0.19), "plano_anual").motivo());
        assertEquals(Motivo.TOKENS_DESCONHECIDOS,
                politica.decidir(classif(0.2, "plano_mensal", 0.80, "plano_anual", 0.79), "plano_anual").motivo());
    }

    @Test
    void codigoDoMotivoVaiEmMinusculas() {
        assertEquals("tokens_desconhecidos", Motivo.TOKENS_DESCONHECIDOS.codigo());
        assertEquals("contexto", Motivo.CONTEXTO.codigo());
    }
}
