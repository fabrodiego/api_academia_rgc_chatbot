package com.rgctraining.chatbot.avaliacao;

import com.rgctraining.chatbot.nlp.ClassificadorTfIdf;
import com.rgctraining.chatbot.nlp.Preprocessador;

import com.rgctraining.chatbot.service.PoliticaDecisao;

import java.util.ArrayList;
import java.util.List;
import java.util.Locale;

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

    /** Uma linha da varredura: parâmetros e o que aconteceria com as frases de treino. */
    public record Linha(double limiar, double margem, double fracao,
                        int acertos, int errosResposta, int fallbackPositivas,
                        int foraEscopoRejeitadas, int foraEscopoTotal, int total) {

        /** Acerto com equivalência sobre todas as frases (positivas + fora_escopo). */
        public double acuracia() {
            return total == 0 ? 0 : (double) acertos / total;
        }

        /** Acertos menos respostas erradas: encaminhar ao humano custa 0, responder errado custa 1. */
        public int utilidade() {
            return acertos - errosResposta;
        }
    }

    public static final double[] LIMIARES = faixa(0.0, 0.60, 0.02);
    public static final double[] MARGENS = {0.0, 0.01, 0.02, 0.03, 0.05, 0.08, 0.10, 0.15};
    public static final double[] FRACOES = {0.0, 0.25, 0.34, 0.50, 0.67, 0.75, 1.0};

    private static double[] faixa(double de, double ate, double passo) {
        int n = (int) Math.round((ate - de) / passo) + 1;
        double[] r = new double[n];
        for (int i = 0; i < n; i++) r[i] = Math.round((de + i * passo) * 1000) / 1000.0;
        return r;
    }

    /**
     * Varre limiar x margem x fração mínima sobre as amostras LOO. As frases da
     * intent fora_escopo funcionam como negativas: o certo é cair no fallback
     * ou na própria fora_escopo (mesma regra de EquivalenciaIntents para NULL).
     * As demais acertam por igualdade ou equivalência pai -> filha.
     */
    public static List<Linha> varrer(List<Amostra> amostras) {
        List<Linha> linhas = new ArrayList<>();
        for (double limiar : LIMIARES) {
            for (double margem : MARGENS) {
                for (double fracao : FRACOES) {
                    PoliticaDecisao politica = new PoliticaDecisao(limiar, margem, fracao);
                    int acertos = 0, erros = 0, fbPos = 0, foraOk = 0, foraTotal = 0;
                    for (Amostra a : amostras) {
                        boolean negativa = EquivalenciaIntents.FORA_ESCOPO.equals(a.intentEsperada());
                        String esperada = negativa ? null : a.intentEsperada();
                        PoliticaDecisao.Decisao d = politica.decidir(a.classificacao());
                        String obtida = d.fallback() ? null : d.intent();
                        boolean certo = EquivalenciaIntents.acertoComEquivalencia(esperada, obtida);
                        if (negativa) foraTotal++;
                        if (certo) {
                            acertos++;
                            if (negativa) foraOk++;
                        } else if (d.fallback()) {
                            fbPos++;
                        } else {
                            erros++;
                        }
                    }
                    linhas.add(new Linha(limiar, margem, fracao, acertos, erros, fbPos, foraOk, foraTotal, amostras.size()));
                }
            }
        }
        return linhas;
    }

    /** Fração da utilidade máxima aceita como "praticamente empatada" (ver {@link #escolher}). */
    public static final double TOLERANCIA_UTILIDADE = 0.99;

    /**
     * Critério: a utilidade (acertos - respostas erradas) máxima é um pico
     * estreito e conservador demais (o ponto de máxima utilidade responde menos
     * da metade das perguntas). Por isso: entre as configurações com utilidade
     * de pelo menos 99% da máxima, escolhe-se a que mais acerta. Empate nisso:
     * os parâmetros mais brandos (menor limiar, margem e fração).
     */
    public static Linha escolher(List<Linha> linhas) {
        int maxima = linhas.stream().mapToInt(Linha::utilidade).max().orElseThrow();
        return linhas.stream()
                .filter(l -> l.utilidade() >= TOLERANCIA_UTILIDADE * maxima)
                .max(java.util.Comparator
                        .comparingInt(Linha::acertos)
                        .thenComparing(Linha::limiar, java.util.Comparator.reverseOrder())
                        .thenComparing(Linha::margem, java.util.Comparator.reverseOrder())
                        .thenComparing(Linha::fracao, java.util.Comparator.reverseOrder()))
                .orElseThrow();
    }

    public static String csv(List<Linha> linhas, Linha escolhida) {
        StringBuilder sb = new StringBuilder(
                "limiar,margem,fracao_minima,acertos,erros_resposta,fallback_positivas,fora_escopo_rejeitadas,"
                + "fora_escopo_total,total,acuracia_equivalencia,utilidade,escolhido\n");
        for (Linha l : linhas) {
            sb.append(String.format(Locale.ROOT, "%.2f,%.2f,%.2f,%d,%d,%d,%d,%d,%d,%.4f,%d,%d%n",
                    l.limiar(), l.margem(), l.fracao(), l.acertos(), l.errosResposta(), l.fallbackPositivas(),
                    l.foraEscopoRejeitadas(), l.foraEscopoTotal(), l.total(), l.acuracia(), l.utilidade(),
                    l.equals(escolhida) ? 1 : 0));
        }
        return sb.toString();
    }
}
