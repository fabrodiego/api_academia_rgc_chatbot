package com.rgctraining.chatbot.nlp;

import com.rgctraining.chatbot.nlp.Preprocessador.ModoNegacao;
import org.junit.jupiter.api.Test;

import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;

class PreprocessadorTest {

    @Test
    void ignorarMantemComportamentoOriginalENaoSome() {
        var p = new Preprocessador(ModoNegacao.IGNORAR);
        assertEquals(List.of("quero", "aluno"), p.processar("Não quero mais ser aluno"));
    }

    @Test
    void manterDeixaNaoComoTokenProprio() {
        var p = new Preprocessador(ModoNegacao.MANTER);
        assertEquals(List.of("nao", "quero", "aluno"), p.processar("Não quero mais ser aluno"));
    }

    @Test
    void fundirGrudaNaoNoProximoTokenQueNaoEStopword() {
        var p = new Preprocessador(ModoNegacao.FUNDIR);
        assertEquals(List.of("nao_quero", "aluno"), p.processar("Não quero mais ser aluno"));
        // "é" e "o" são stopwords: a negação espera o próximo token de conteúdo
        assertEquals(List.of("nao_bom"), p.processar("nao é o bom"));
    }

    @Test
    void fundirAceitaNaoComESemAcentoENegacaoSoVale_ParaUmToken() {
        var p = new Preprocessador(ModoNegacao.FUNDIR);
        assertEquals(p.processar("nao quero treinar"), p.processar("NÃO quero treinar"));
        assertEquals(List.of("nao_quero", "treinar"), p.processar("não quero treinar"));
    }

    @Test
    void fundirDescartaNaoSemTokenDepois() {
        var p = new Preprocessador(ModoNegacao.FUNDIR);
        assertEquals(List.of("quero"), p.processar("quero não"));
    }

    @Test
    void fraseSemNegacaoNaoMudaEntreOsModos() {
        String f = "qual o horario de funcionamento";
        List<String> esperado = new Preprocessador(ModoNegacao.IGNORAR).processar(f);
        assertEquals(esperado, new Preprocessador(ModoNegacao.FUNDIR).processar(f));
        assertEquals(esperado, new Preprocessador(ModoNegacao.MANTER).processar(f));
    }
}
