package com.rgctraining.chatbot.avaliacao;

import java.util.*;

/**
 * Métricas da avaliação do classificador, calculadas a partir dos resultados
 * dos casos de teste. Não depende de banco nem de Spring (testável isolado).
 *
 * Regras:
 * - Acerto estrito: intent obtida == intent esperada. Esperada NULL só acerta
 *   se o bot cair no fallback. Campos acertos/acuracia.
 * - Acerto com equivalência ({@link EquivalenciaIntents}): além do estrito,
 *   NULL aceita também fora_escopo e a intent genérica aceita suas filhas.
 *   Campos acertosEquivalencia/acuraciaEquivalencia.
 * - A matriz de confusão e precisão/recall usam sempre a intent obtida real.
 * - O fallback é tratado como uma classe própria, "(fallback)", na matriz de
 *   confusão e em precisão/recall.
 * - Precisão/recall macro: média sobre as classes que aparecem como esperadas
 *   nos testes. Classe nunca prevista tem precisão 0.
 */
public record MetricasAvaliacao(
        int total,
        int acertos,
        double acuracia,
        int acertosEquivalencia,
        double acuraciaEquivalencia,
        double taxaFallback,
        Map<String, PorTipo> porTipo,
        Map<String, PorClasse> porClasse,
        double precisaoMacro,
        double recallMacro,
        Map<String, Map<String, Integer>> matrizConfusao,
        List<ResultadoCaso> erros,
        List<ResultadoCaso> acertosPorEquivalencia) {

    public static final String FALLBACK = "(fallback)";

    public record PorTipo(int total, int acertos, double acuracia,
                          int acertosEquivalencia, double acuraciaEquivalencia) {}

    public record PorClasse(int verdadeirosPositivos, int falsosPositivos, int falsosNegativos,
                            double precisao, double recall) {}

    public static MetricasAvaliacao calcular(List<ResultadoCaso> casos) {
        int total = casos.size();
        int acertos = 0;
        int acertosEq = 0;
        int fallbacks = 0;
        Map<String, int[]> tipos = new TreeMap<>();
        Map<String, Map<String, Integer>> matriz = new TreeMap<>();
        Set<String> classes = new TreeSet<>();
        Set<String> classesEsperadas = new TreeSet<>();
        List<ResultadoCaso> erros = new ArrayList<>();
        List<ResultadoCaso> porEquivalencia = new ArrayList<>();

        for (ResultadoCaso c : casos) {
            String esperada = rotulo(c.intentEsperada());
            String obtida = rotulo(c.intentObtida());
            classes.add(esperada);
            classes.add(obtida);
            classesEsperadas.add(esperada);

            int[] t = tipos.computeIfAbsent(c.tipo(), k -> new int[3]);
            t[0]++;
            if (c.acertoEstrito()) {
                acertos++;
                t[1]++;
            }
            if (c.acerto()) {
                acertosEq++;
                t[2]++;
                if (!c.acertoEstrito()) porEquivalencia.add(c);
            } else {
                erros.add(c); // erro mesmo com a equivalência
            }
            if (c.intentObtida() == null) {
                fallbacks++;
            }
            matriz.computeIfAbsent(esperada, k -> new TreeMap<>()).merge(obtida, 1, Integer::sum);
        }

        Map<String, PorTipo> porTipo = new LinkedHashMap<>();
        tipos.forEach((tipo, t) -> porTipo.put(tipo, new PorTipo(t[0], t[1], razao(t[1], t[0]), t[2], razao(t[2], t[0]))));

        Map<String, PorClasse> porClasse = new LinkedHashMap<>();
        for (String classe : classes) {
            int vp = 0, fp = 0, fn = 0;
            for (ResultadoCaso c : casos) {
                boolean esp = classe.equals(rotulo(c.intentEsperada()));
                boolean obt = classe.equals(rotulo(c.intentObtida()));
                if (esp && obt) vp++;
                else if (obt) fp++;
                else if (esp) fn++;
            }
            porClasse.put(classe, new PorClasse(vp, fp, fn, razao(vp, vp + fp), razao(vp, vp + fn)));
        }

        double precisaoMacro = classesEsperadas.stream()
                .mapToDouble(k -> porClasse.get(k).precisao()).average().orElse(0);
        double recallMacro = classesEsperadas.stream()
                .mapToDouble(k -> porClasse.get(k).recall()).average().orElse(0);

        return new MetricasAvaliacao(total, acertos, razao(acertos, total), acertosEq, razao(acertosEq, total),
                razao(fallbacks, total),
                porTipo, porClasse, precisaoMacro, recallMacro, matriz, erros, porEquivalencia);
    }

    private static String rotulo(String intent) {
        return intent == null ? FALLBACK : intent;
    }

    private static double razao(int a, int b) {
        return b == 0 ? 0.0 : (double) a / b;
    }
}
