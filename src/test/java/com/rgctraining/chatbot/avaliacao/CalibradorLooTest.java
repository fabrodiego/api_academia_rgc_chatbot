package com.rgctraining.chatbot.avaliacao;

import com.rgctraining.chatbot.avaliacao.CalibradorLoo.Amostra;
import com.rgctraining.chatbot.avaliacao.CalibradorLoo.Linha;
import com.rgctraining.chatbot.nlp.ClassificadorTfIdf.Candidato;
import com.rgctraining.chatbot.nlp.ClassificadorTfIdf.Classificacao;
import com.rgctraining.chatbot.nlp.Preprocessador;
import org.junit.jupiter.api.Test;

import java.util.List;

import static org.junit.jupiter.api.Assertions.*;

class CalibradorLooTest {

    private static Amostra amostra(String esperada, String obtida, double s1, double s2) {
        return new Amostra("x", esperada, new Classificacao(obtida, s1,
                List.of(new Candidato(obtida, s1), new Candidato("outra", s2)), List.of("x"), 1.0));
    }

    @Test
    void leaveOneOutNaoUsaAFraseQueEstaSendoClassificada() {
        List<String> textos = List.of("quero ser aluno", "tem estacionamento", "tem estacionamento coberto");
        List<String> intents = List.of("matricula", "estacionamento", "estacionamento");
        List<Amostra> r = CalibradorLoo.executar(textos, intents, new Preprocessador(), 3);

        assertEquals(3, r.size());
        // sem a própria frase, "quero ser aluno" não tem nenhuma palavra em comum com o resto
        assertEquals(0.0, r.get(0).classificacao().score());
        // as duas de estacionamento acertam uma à outra
        assertEquals("estacionamento", r.get(1).classificacao().intentCodigo());
        assertEquals("estacionamento", r.get(2).classificacao().intentCodigo());
    }

    @Test
    void varreduraContaAcertosErrosEForaDeEscopo() {
        List<Amostra> amostras = List.of(
                amostra("horario", "horario", 0.9, 0.1),          // acerta com folga
                amostra("horario", "planos", 0.5, 0.45),          // erra, margem pequena
                amostra("fora_escopo", "fora_escopo", 0.7, 0.1)); // negativa: acerta
        List<Linha> linhas = CalibradorLoo.varrer(amostras);

        Linha solta = linhas.stream().filter(l -> l.limiar() == 0.0 && l.margem() == 0.0 && l.fracao() == 0.0).findFirst().orElseThrow();
        assertEquals(2, solta.acertos());
        assertEquals(1, solta.errosResposta());
        assertEquals(1, solta.foraEscopoRejeitadas());
        assertEquals(1, solta.foraEscopoTotal());

        Linha comMargem = linhas.stream().filter(l -> l.limiar() == 0.0 && l.margem() == 0.08 && l.fracao() == 0.0).findFirst().orElseThrow();
        assertEquals(0, comMargem.errosResposta(), "a margem manda a resposta errada para o humano");
        assertEquals(1, comMargem.fallbackPositivas());
        assertEquals(2, comMargem.acertos());
    }

    @Test
    void escolhaFicaComAConfiguracaoQueMaisAcertaDentroDaTolerancia() {
        List<Amostra> amostras = List.of(
                amostra("a", "a", 0.9, 0.1), amostra("a", "a", 0.9, 0.1),
                amostra("a", "b", 0.5, 0.45));
        Linha escolhida = CalibradorLoo.escolher(CalibradorLoo.varrer(amostras));
        assertEquals(2, escolhida.acertos());
        assertEquals(0, escolhida.errosResposta());
        assertTrue(CalibradorLoo.csv(List.of(escolhida), escolhida).contains(",1\n"));
    }
}
