package com.rgctraining.chatbot.nlp;

import org.junit.jupiter.api.BeforeAll;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.List;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotEquals;

/**
 * Regressão do "aí" (ADR 0003) com as frases de treino reais do sql/banco.sql:
 * "aí" no fim da pergunta é advérbio de lugar e não pode puxar a mensagem
 * para saudação; "e aí" continua sendo cumprimento.
 */
class AiNoTreinoRealTest {

    private static final Pattern FRASE_TREINO =
            Pattern.compile("^\\s*\\(\\d+, '([a-z_]+)', '((?:[^']|'')*)', '[a-z]+'\\)", Pattern.MULTILINE);

    private static ClassificadorTfIdf modelo;

    @BeforeAll
    static void carregar() throws IOException {
        String sql = Files.readString(Path.of("sql/banco.sql"), StandardCharsets.UTF_8);
        int i = sql.indexOf("INSERT INTO training_phrases");
        int j = sql.indexOf(") AS v(ord, codigo, texto, origem)", i);
        List<String> textos = new ArrayList<>();
        List<String> intents = new ArrayList<>();
        Matcher m = FRASE_TREINO.matcher(sql.substring(i, j));
        while (m.find()) {
            intents.add(m.group(1));
            textos.add(m.group(2).replace("''", "'"));
        }
        modelo = new ClassificadorTfIdf(new Preprocessador(), textos, intents);
    }

    private static String intent(String mensagem) {
        return modelo.classificar(mensagem, 3).intentCodigo();
    }

    @ParameterizedTest
    @ValueSource(strings = {"tem crossfit", "tem cross fit", "tem pilates", "tem natação", "tem yoga",
            "tem boxe", "tem musculação", "tem estacionamento", "qual o horário", "quanto custa"})
    void aiNoFimNaoMudaAIntent(String pergunta) {
        assertEquals(intent(pergunta + "?"), intent(pergunta + " aí?"));
        assertNotEquals("saudacao", intent(pergunta + " aí?"));
    }

    @ParameterizedTest
    @ValueSource(strings = {"e aí", "E aí, beleza?", "fala aí", "e ai tudo bem"})
    void eAiContinuaSaudacao(String mensagem) {
        assertEquals("saudacao", intent(mensagem));
    }
}
