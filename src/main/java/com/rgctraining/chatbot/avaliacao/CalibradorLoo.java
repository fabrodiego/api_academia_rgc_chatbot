package com.rgctraining.chatbot.avaliacao;

import com.rgctraining.chatbot.nlp.ClassificadorTfIdf;
import com.rgctraining.chatbot.nlp.Preprocessador;

import java.util.ArrayList;
import java.util.List;

/**
 * Leave-one-out sobre as frases de TREINO: cada frase é classificada por um
 * modelo montado com todas as outras (inclusive o IDF, para a frase não
 * "vazar" para o próprio vocabulário). Nunca toca nos casos de teste.
 * Sem Spring nem banco.
 */
public final class CalibradorLoo {

    /** Uma frase de treino classificada contra as demais. */
    public record Amostra(String texto, String intentEsperada, ClassificadorTfIdf.Classificacao classificacao) {}

    private CalibradorLoo() {}

    public static List<Amostra> executar(List<String> textos, List<String> intents,
                                         Preprocessador preprocessador, int k) {
        List<Amostra> amostras = new ArrayList<>();
        for (int i = 0; i < textos.size(); i++) {
            List<String> t = new ArrayList<>(textos);
            List<String> it = new ArrayList<>(intents);
            t.remove(i);
            it.remove(i);
            ClassificadorTfIdf modelo = new ClassificadorTfIdf(preprocessador, t, it);
            amostras.add(new Amostra(textos.get(i), intents.get(i), modelo.classificar(textos.get(i), k)));
        }
        return amostras;
    }
}
