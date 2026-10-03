package com.rgctraining.chatbot.nlp;

import org.springframework.core.io.ClassPathResource;

import java.io.BufferedReader;
import java.io.IOException;
import java.io.InputStreamReader;
import java.nio.charset.StandardCharsets;
import java.text.Normalizer;
import java.util.HashSet;
import java.util.List;
import java.util.Set;
import java.util.stream.Collectors;

/**
 * Remove stopwords (palavras sem valor discriminativo para PLN: artigos,
 * preposições etc.). Lista carregada de resources/stopwords/pt_stopwords.txt
 */
public class StopWordsFilter {

    private final Set<String> stopWords = new HashSet<>();

    public StopWordsFilter() {
        try (BufferedReader reader = new BufferedReader(new InputStreamReader(
                new ClassPathResource("stopwords/pt_stopwords.txt").getInputStream(), StandardCharsets.UTF_8))) {
            String linha;
            while ((linha = reader.readLine()) != null) {
                linha = linha.trim();
                if (!linha.isEmpty()) {
                    stopWords.add(normalizar(linha));
                }
            }
        } catch (IOException e) {
            throw new IllegalStateException("Não foi possível carregar a lista de stopwords", e);
        }
    }

    private String normalizar(String palavra) {
        String semAcento = Normalizer.normalize(palavra.toLowerCase(), Normalizer.Form.NFD);
        return semAcento.replaceAll("\\p{InCombiningDiacriticalMarks}+", "");
    }

    public List<String> filtrar(List<String> tokens) {
        return tokens.stream()
                .filter(t -> !stopWords.contains(t))
                .collect(Collectors.toList());
    }
}
