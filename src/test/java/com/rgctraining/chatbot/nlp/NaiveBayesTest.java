package com.rgctraining.chatbot.nlp;

import org.junit.jupiter.api.Test;

import java.util.List;

import static org.junit.jupiter.api.Assertions.*;

class NaiveBayesTest {

    private final Preprocessador pre = new Preprocessador(Preprocessador.ModoNegacao.IGNORAR);

    private NaiveBayes treinar() {
        List<String> textos = List.of("quanto custa o plano", "valor do plano mensal", "preco do plano",
                "qual o horario de funcionamento", "que horas abre", "horario de abertura");
        List<String> intents = List.of("planos", "planos", "planos", "horario", "horario", "horario");
        return new NaiveBayes(textos.stream().map(pre::processar).toList(), intents);
    }

    @Test
    void escolheAIntentComMaisEvidencia() {
        NaiveBayes nb = treinar();
        assertEquals("planos", nb.classificar(pre.processar("qual o preço do plano")));
        assertEquals("horario", nb.classificar(pre.processar("horario de abertura")));
    }

    @Test
    void ignoraTokensDesconhecidosMasUsaOsConhecidos() {
        assertEquals("planos", treinar().classificar(pre.processar("plano zumbaia")));
    }

    @Test
    void semNenhumTokenConhecidoDevolveNulo() {
        assertNull(treinar().classificar(pre.processar("zumbaia blabla")));
        assertNull(treinar().classificar(List.of()));
    }

    @Test
    void tamanhosDiferentesSaoRejeitados() {
        assertThrows(IllegalArgumentException.class, () -> new NaiveBayes(List.of(List.of("a")), List.of()));
    }
}
