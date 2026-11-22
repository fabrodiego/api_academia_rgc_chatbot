package com.rgctraining.chatbot.avaliacao;

import org.junit.jupiter.api.Test;

import static com.rgctraining.chatbot.avaliacao.EquivalenciaIntents.acertoComEquivalencia;
import static com.rgctraining.chatbot.avaliacao.EquivalenciaIntents.acertoEstrito;
import static org.junit.jupiter.api.Assertions.*;

class EquivalenciaIntentsTest {

    @Test
    void nuloComFallbackAcerta() {
        assertTrue(acertoComEquivalencia(null, null));
        assertTrue(acertoEstrito(null, null));
    }

    @Test
    void nuloComForaEscopoAcertaSoComEquivalencia() {
        assertTrue(acertoComEquivalencia(null, "fora_escopo"));
        assertFalse(acertoEstrito(null, "fora_escopo"));
    }

    @Test
    void nuloComIntentDeNegocioErra() {
        assertFalse(acertoComEquivalencia(null, "planos_valores"));
    }

    @Test
    void paiAceitaFilha() {
        assertTrue(acertoComEquivalencia("planos_valores", "plano_mensal"));
        assertTrue(acertoComEquivalencia("aulas_modalidades", "aula_yoga"));
        assertTrue(acertoComEquivalencia("idade_minima", "crianca_boxe"));
        assertFalse(acertoEstrito("planos_valores", "plano_mensal"));
    }

    @Test
    void filhaNaoAceitaPai() {
        assertFalse(acertoComEquivalencia("plano_mensal", "planos_valores"));
        assertFalse(acertoComEquivalencia("horario_fim_semana_feriado", "horario_funcionamento"));
    }

    @Test
    void horarioGeralNaoAceitaSoFimDeSemana() {
        assertFalse(acertoComEquivalencia("horario_funcionamento", "horario_fim_semana_feriado"));
    }

    @Test
    void filhaNaoAceitaIrma() {
        assertFalse(acertoComEquivalencia("plano_mensal", "plano_anual"));
        assertFalse(acertoComEquivalencia("aula_yoga", "aula_bike"));
    }

    @Test
    void paiNaoAceitaIntentDeOutroGrupo() {
        assertFalse(acertoComEquivalencia("planos_valores", "aula_yoga"));
        assertFalse(acertoComEquivalencia("planos_valores", null));
        assertFalse(acertoComEquivalencia("aulas_modalidades", "crianca_yoga"));
    }

    @Test
    void esperadoNaoNuloComForaEscopoErra() {
        assertFalse(acertoComEquivalencia("planos_valores", "fora_escopo"));
    }

    @Test
    void mapaSoTemFilhasQueNaoSaoOProprioPai() {
        EquivalenciaIntents.FILHAS_POR_PAI.forEach((pai, filhas) -> assertFalse(filhas.contains(pai)));
    }

    @Test
    void mesmaFamiliaCobrePaiFilhaEIrmas() {
        assertTrue(EquivalenciaIntents.mesmaFamilia("plano_mensal", "plano_mensal"));
        assertTrue(EquivalenciaIntents.mesmaFamilia("planos_valores", "plano_anual"));
        assertTrue(EquivalenciaIntents.mesmaFamilia("plano_anual", "planos_valores"));
        assertTrue(EquivalenciaIntents.mesmaFamilia("plano_mensal", "plano_anual"));
        assertFalse(EquivalenciaIntents.mesmaFamilia("plano_mensal", "aula_boxe"));
        assertFalse(EquivalenciaIntents.mesmaFamilia("horario_funcionamento", "horario_fim_semana_feriado"));
        assertFalse(EquivalenciaIntents.mesmaFamilia(null, "plano_anual"));
    }
}
