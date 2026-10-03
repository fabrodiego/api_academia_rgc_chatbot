package com.rgctraining.chatbot.nlp;

public class CosineSimilarity {

    /** Vetores já devem estar L2-normalizados; nesse caso cos = produto escalar. */
    public double calcular(double[] a, double[] b) {
        if (a.length != b.length) {
            throw new IllegalArgumentException("Vetores de tamanhos diferentes");
        }
        double soma = 0;
        for (int i = 0; i < a.length; i++) {
            soma += a[i] * b[i];
        }
        return soma;
    }
}
