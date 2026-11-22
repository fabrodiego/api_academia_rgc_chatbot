package com.rgctraining.chatbot.nlp;

import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/**
 * Classificador 1-NN por TF-IDF + cosseno, imutável e sem dependência de
 * Spring/banco (por isso também serve à calibração leave-one-out).
 *
 * Cada frase de treino é um documento. A mensagem recebe a intent da frase
 * mais parecida; o resultado traz as k melhores intents distintas (melhor
 * score de cada intent), os tokens após o pré-processamento e a fração
 * desses tokens que existe no vocabulário de treino.
 */
public final class ClassificadorTfIdf {

    public record Candidato(String intent, double score) {}

    public record Classificacao(String intentCodigo, double score, List<Candidato> top,
                                List<String> tokens, double fracaoConhecida) {

        public static Classificacao vazia(List<String> tokens, double fracaoConhecida) {
            return new Classificacao(null, 0.0, List.of(), tokens, fracaoConhecida);
        }

        /** Score da segunda intent (0 se só houver uma). */
        public double scoreSegunda() {
            return top.size() > 1 ? top.get(1).score() : 0.0;
        }

        /** Diferença entre a 1ª e a 2ª intent. */
        public double margem() {
            return score - scoreSegunda();
        }
    }

    private final Preprocessador preprocessador;
    private final TfIdfVectorizer vectorizer;
    private final List<String> intentPorFrase;
    private final CosineSimilarity cosine = new CosineSimilarity();

    public ClassificadorTfIdf(Preprocessador preprocessador, List<String> textos, List<String> intentPorFrase) {
        if (textos.size() != intentPorFrase.size()) {
            throw new IllegalArgumentException("textos e intents com tamanhos diferentes");
        }
        this.preprocessador = preprocessador;
        List<List<String>> corpus = new ArrayList<>();
        for (String texto : textos) {
            corpus.add(preprocessador.processar(texto));
        }
        this.vectorizer = new TfIdfVectorizer(corpus);
        this.intentPorFrase = List.copyOf(intentPorFrase);
    }

    public Classificacao classificar(String mensagem, int k) {
        List<String> tokens = aplicarRecuo(preprocessador.processar(mensagem));
        double fracao = fracaoConhecida(tokens);
        double[] vetor = vectorizer.vetorizar(tokens);

        Map<String, Double> melhorPorIntent = new LinkedHashMap<>();
        List<double[]> corpus = vectorizer.getVetoresDoCorpus();
        for (int i = 0; i < corpus.size(); i++) {
            melhorPorIntent.merge(intentPorFrase.get(i), cosine.calcular(vetor, corpus.get(i)), Math::max);
        }
        List<Candidato> top = melhorPorIntent.entrySet().stream()
                .map(e -> new Candidato(e.getKey(), e.getValue()))
                .sorted((a, b) -> Double.compare(b.score(), a.score())) // estável: empate fica na ordem do treino
                .limit(Math.max(1, k))
                .toList();
        if (top.isEmpty()) {
            return Classificacao.vazia(tokens, fracao);
        }
        return new Classificacao(top.get(0).intent(), top.get(0).score(), top, tokens, fracao);
    }

    /** Só no modo FUNDIR_COM_RECUO: negação fundida desconhecida volta ao token simples. */
    private List<String> aplicarRecuo(List<String> tokens) {
        if (preprocessador.getModoNegacao() != Preprocessador.ModoNegacao.FUNDIR_COM_RECUO) {
            return tokens;
        }
        List<String> saida = new ArrayList<>(tokens.size());
        for (String t : tokens) {
            boolean fundidoDesconhecido = t.startsWith(Preprocessador.PREFIXO_NEGACAO) && !vectorizer.conhece(t);
            saida.add(fundidoDesconhecido ? t.substring(Preprocessador.PREFIXO_NEGACAO.length()) : t);
        }
        return saida;
    }

    private double fracaoConhecida(List<String> tokens) {
        if (tokens.isEmpty()) return 0.0;
        long conhecidos = tokens.stream().filter(vectorizer::conhece).count();
        return (double) conhecidos / tokens.size();
    }
}
