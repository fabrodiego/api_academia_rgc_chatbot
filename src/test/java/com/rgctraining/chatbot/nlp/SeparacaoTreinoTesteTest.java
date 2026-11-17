package com.rgctraining.chatbot.nlp;

import org.junit.jupiter.api.Test;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.*;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

import static org.junit.jupiter.api.Assertions.*;

/**
 * Garante a separação entre treino e teste no sql/banco.sql: nenhum caso de
 * teste pode ser igual a uma frase de treino depois de normalizar com o
 * Tokenizer (minúsculas, sem acento, sem pontuação). Caso igual ao treino
 * acerta por memória e infla a acurácia.
 */
class SeparacaoTreinoTesteTest {

    private static final Path BANCO = Path.of("sql/banco.sql");
    private static final Pattern FRASE_TREINO =
            Pattern.compile("^\\s*\\(\\d+, '[a-z_]+', '((?:[^']|'')*)', '[a-z]+'\\)", Pattern.MULTILINE);
    private static final Pattern CASO_TESTE =
            Pattern.compile("^\\s*\\('((?:[^']|'')*)', (?:NULL|'[a-z_]+'), '[a-z_]+'\\)", Pattern.MULTILINE);

    private final Tokenizer tokenizer = new Tokenizer();

    @Test
    void nenhumCasoDeTesteEstaNoTreino() throws IOException {
        String sql = Files.readString(BANCO, StandardCharsets.UTF_8);
        Set<String> treino = new HashSet<>();
        for (String f : extrair(bloco(sql, "INSERT INTO training_phrases", ") AS v(ord, codigo, texto, origem)"), FRASE_TREINO)) {
            treino.add(normalizar(f));
        }
        List<String> testes = extrair(bloco(sql, "INSERT INTO test_cases", ";\n"), CASO_TESTE);

        assertFalse(treino.isEmpty(), "nenhuma frase de treino lida do banco.sql");
        assertTrue(testes.size() >= 20, "o enunciado pede pelo menos 20 casos de teste");

        List<String> vazados = testes.stream().filter(t -> treino.contains(normalizar(t))).toList();
        assertTrue(vazados.isEmpty(), "casos de teste iguais a frases de treino: " + vazados);
    }

    private String normalizar(String texto) {
        return String.join(" ", tokenizer.tokenize(texto));
    }

    private static String bloco(String sql, String inicio, String fim) {
        int i = sql.indexOf(inicio);
        assertTrue(i >= 0, "não achei: " + inicio);
        int j = sql.indexOf(fim, i);
        assertTrue(j >= 0, "não achei o fim do bloco: " + inicio);
        return sql.substring(i, j + fim.length());
    }

    private static List<String> extrair(String bloco, Pattern p) {
        List<String> r = new ArrayList<>();
        Matcher m = p.matcher(bloco);
        while (m.find()) {
            r.add(m.group(1).replace("''", "'"));
        }
        return r;
    }
}
