package com.rgctraining.chatbot.nlp;

import java.util.*;

/**
 * Implementação própria de TF-IDF (Term Frequency - Inverse Document Frequency).
 *
 * TF (frequência do termo): quantas vezes a palavra aparece no documento,
 * normalizado pelo tamanho do documento.
 *
 * IDF (frequência inversa nos documentos): penaliza palavras que aparecem
 * em muitos documentos (pouco discriminativas) e valoriza as raras.
 *
 * Cada frase de treino vira um "documento". O corpus é todo o conjunto de
 * frases de treino carregadas do banco.
 */
public class TfIdfVectorizer {

    private final List<String> vocabulario = new ArrayList<>();
    private final Map<String, Integer> indiceDoTermo = new HashMap<>();
    private final double[] idf;
    private final List<double[]> vetoresDoCorpus = new ArrayList<>();

    public TfIdfVectorizer(List<List<String>> corpusTokenizado) {
        // 1. monta vocabulário
        Set<String> termosUnicos = new TreeSet<>();
        for (List<String> doc : corpusTokenizado) {
            termosUnicos.addAll(doc);
        }
        vocabulario.addAll(termosUnicos);
        for (int i = 0; i < vocabulario.size(); i++) {
            indiceDoTermo.put(vocabulario.get(i), i);
        }

        // 2. calcula IDF: idf(t) = ln((1 + N) / (1 + df(t))) + 1  (suavizado)
        int n = corpusTokenizado.size();
        int[] docFrequency = new int[vocabulario.size()];
        for (List<String> doc : corpusTokenizado) {
            Set<String> termosDoDoc = new HashSet<>(doc);
            for (String termo : termosDoDoc) {
                docFrequency[indiceDoTermo.get(termo)]++;
            }
        }
        idf = new double[vocabulario.size()];
        for (int i = 0; i < idf.length; i++) {
            idf[i] = Math.log((1.0 + n) / (1.0 + docFrequency[i])) + 1.0;
        }

        // 3. vetoriza cada documento do corpus (TF-IDF + normalização L2)
        for (List<String> doc : corpusTokenizado) {
            vetoresDoCorpus.add(vetorizar(doc));
        }
    }

    /** Calcula o vetor TF-IDF normalizado para um documento (lista de tokens). */
    public double[] vetorizar(List<String> tokensDoDocumento) {
        double[] vetor = new double[vocabulario.size()];
        if (tokensDoDocumento.isEmpty()) {
            return vetor;
        }
        Map<String, Integer> contagem = new HashMap<>();
        for (String token : tokensDoDocumento) {
            contagem.merge(token, 1, Integer::sum);
        }
        int totalTokens = tokensDoDocumento.size();
        for (Map.Entry<String, Integer> entry : contagem.entrySet()) {
            Integer idx = indiceDoTermo.get(entry.getKey());
            if (idx == null) {
                continue; // termo fora do vocabulário de treino (OOV) - ignorado
            }
            double tf = (double) entry.getValue() / totalTokens;
            vetor[idx] = tf * idf[idx];
        }
        return normalizarL2(vetor);
    }

    private double[] normalizarL2(double[] vetor) {
        double soma = 0;
        for (double v : vetor) soma += v * v;
        double norma = Math.sqrt(soma);
        if (norma == 0) return vetor;
        double[] resultado = new double[vetor.length];
        for (int i = 0; i < vetor.length; i++) resultado[i] = vetor[i] / norma;
        return resultado;
    }

    public List<double[]> getVetoresDoCorpus() {
        return vetoresDoCorpus;
    }

    public int tamanhoVocabulario() {
        return vocabulario.size();
    }
}
