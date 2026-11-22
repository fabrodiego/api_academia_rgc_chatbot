package com.rgctraining.chatbot.nlp;

import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;

/**
 * Baseline: Naive Bayes multinomial feito à mão, com suavização de Laplace.
 *
 * P(intent | tokens) ∝ P(intent) * Π P(token | intent), calculado em log.
 * Usa o mesmo pré-processamento (a quem o chamar passa os tokens). Tokens fora
 * do vocabulário de treino são ignorados; sem nenhum token conhecido não há
 * evidência e o resultado é null (fallback). Não tem limiar, margem nem regras:
 * serve de comparação para o TF-IDF + regras de decisão.
 */
public final class NaiveBayes {

    private final Map<String, Double> logPrior = new HashMap<>();
    private final Map<String, Map<String, Integer>> contagem = new HashMap<>();
    private final Map<String, Integer> totalPorIntent = new HashMap<>();
    private final Set<String> vocabulario = new HashSet<>();

    /** @param documentos tokens de cada frase de treino; intents: a intent de cada uma. */
    public NaiveBayes(List<List<String>> documentos, List<String> intents) {
        if (documentos.size() != intents.size()) {
            throw new IllegalArgumentException("documentos e intents com tamanhos diferentes");
        }
        Map<String, Integer> docsPorIntent = new HashMap<>();
        for (int i = 0; i < documentos.size(); i++) {
            String intent = intents.get(i);
            docsPorIntent.merge(intent, 1, Integer::sum);
            Map<String, Integer> c = contagem.computeIfAbsent(intent, k -> new HashMap<>());
            for (String token : documentos.get(i)) {
                c.merge(token, 1, Integer::sum);
                totalPorIntent.merge(intent, 1, Integer::sum);
                vocabulario.add(token);
            }
        }
        double n = documentos.size();
        docsPorIntent.forEach((intent, qtd) -> logPrior.put(intent, Math.log(qtd / n)));
    }

    /** Intent mais provável, ou null se nenhum token da mensagem é conhecido. */
    public String classificar(List<String> tokens) {
        List<String> conhecidos = tokens.stream().filter(vocabulario::contains).toList();
        if (conhecidos.isEmpty()) {
            return null;
        }
        String melhor = null;
        double melhorLog = Double.NEGATIVE_INFINITY;
        int v = vocabulario.size();
        for (String intent : new java.util.TreeSet<>(logPrior.keySet())) { // ordem fixa: empate estável
            double log = logPrior.get(intent);
            Map<String, Integer> c = contagem.get(intent);
            int total = totalPorIntent.getOrDefault(intent, 0);
            for (String token : conhecidos) {
                log += Math.log((c.getOrDefault(token, 0) + 1.0) / (total + v));
            }
            if (log > melhorLog) {
                melhorLog = log;
                melhor = intent;
            }
        }
        return melhor;
    }
}
