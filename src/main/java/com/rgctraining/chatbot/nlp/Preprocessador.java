package com.rgctraining.chatbot.nlp;

import java.util.List;

/**
 * Pré-processamento único, usado igualmente no treino e na mensagem:
 * tokeniza (minúsculas, sem acento, sem pontuação) e remove stopwords.
 */
public class Preprocessador {

    private final Tokenizer tokenizer = new Tokenizer();
    private final StopWordsFilter stopWordsFilter = new StopWordsFilter();

    public List<String> processar(String texto) {
        return stopWordsFilter.filtrar(tokenizer.tokenize(texto));
    }
}
