package com.rgctraining.chatbot.nlp;

import java.text.Normalizer;
import java.util.ArrayList;
import java.util.List;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * Tokenização por palavra: normaliza (minúsculas, remove acentos),
 * remove pontuação e divide em tokens.
 */
public class Tokenizer {

    private static final Pattern TOKEN_PATTERN = Pattern.compile("[a-zA-Z0-9]+");

    public List<String> tokenize(String texto) {
        if (texto == null) {
            return new ArrayList<>();
        }
        String semAcento = removerAcentos(texto.toLowerCase());
        List<String> tokens = new ArrayList<>();
        Matcher m = TOKEN_PATTERN.matcher(semAcento);
        while (m.find()) {
            tokens.add(m.group());
        }
        return tokens;
    }

    private String removerAcentos(String texto) {
        String normalizado = Normalizer.normalize(texto, Normalizer.Form.NFD);
        return normalizado.replaceAll("\\p{InCombiningDiacriticalMarks}+", "");
    }
}
