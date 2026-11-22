package com.rgctraining.chatbot.nlp;

import com.rgctraining.chatbot.nlp.ClassificadorTfIdf.Classificacao;
import com.rgctraining.chatbot.nlp.Preprocessador.ModoNegacao;
import org.junit.jupiter.api.Test;

import java.util.List;

import static org.junit.jupiter.api.Assertions.*;

class ClassificadorTfIdfTest {

    private static final List<String> TEXTOS = List.of(
            "quero ser aluno", "quero me matricular", "nao quero mais treinar",
            "quanto custa o plano mensal", "valor do plano mensal",
            "quanto custa o plano anual", "qual o horario de funcionamento", "tem estacionamento");
    private static final List<String> INTENTS = List.of(
            "matricula", "matricula", "cancelamento",
            "plano_mensal", "plano_mensal", "plano_anual", "horario", "estacionamento");

    private ClassificadorTfIdf modelo(ModoNegacao modo) {
        return new ClassificadorTfIdf(new Preprocessador(modo), TEXTOS, INTENTS);
    }

    @Test
    void topKTemIntentsDistintasOrdenadasPeloMelhorScore() {
        Classificacao c = modelo(ModoNegacao.FUNDIR).classificar("quanto custa o plano mensal", 3);

        assertEquals(3, c.top().size());
        assertEquals("plano_mensal", c.intentCodigo());
        assertEquals(c.top().get(0).score(), c.score());
        assertEquals(3, c.top().stream().map(ClassificadorTfIdf.Candidato::intent).distinct().count());
        for (int i = 1; i < c.top().size(); i++) {
            assertTrue(c.top().get(i - 1).score() >= c.top().get(i).score());
        }
        // plano_mensal tem duas frases, mas aparece uma vez só, com a melhor
        assertEquals(1, c.top().stream().filter(x -> x.intent().equals("plano_mensal")).count());
    }

    @Test
    void kMaiorQueNumeroDeIntentsDevolveTodas() {
        Classificacao c = modelo(ModoNegacao.FUNDIR).classificar("plano mensal", 50);
        assertEquals(6, c.top().size());
    }

    @Test
    void devolveTokensAposPreProcessamento() {
        Classificacao c = modelo(ModoNegacao.FUNDIR).classificar("Qual o horário de funcionamento?", 3);
        assertEquals(List.of("horario", "funcionamento"), c.tokens());
    }

    @Test
    void fracaoConhecidaConsideraSoOVocabularioDeTreino() {
        ClassificadorTfIdf m = modelo(ModoNegacao.FUNDIR);
        assertEquals(1.0, m.classificar("horario funcionamento", 3).fracaoConhecida());
        assertEquals(0.5, m.classificar("horario zumbaia", 3).fracaoConhecida());
        assertEquals(0.0, m.classificar("zumbaia blabla", 3).fracaoConhecida());
        assertEquals(0.0, m.classificar("a o de", 3).fracaoConhecida()); // só stopwords: sem tokens
    }

    @Test
    void margemEADiferencaEntreAPrimeiraEASegunda() {
        Classificacao c = modelo(ModoNegacao.FUNDIR).classificar("quanto custa o plano mensal", 3);
        assertEquals(c.score() - c.top().get(1).score(), c.margem(), 1e-12);
    }

    @Test
    void negacaoFundidaAproximaDaIntentDeCancelamento() {
        // sem tratar a negação, "não" some e a mensagem fica idêntica a "quero ... aluno"
        Classificacao ignorar = modelo(ModoNegacao.IGNORAR).classificar("não quero mais ser aluno", 3);
        Classificacao fundir = modelo(ModoNegacao.FUNDIR).classificar("não quero mais ser aluno", 3);

        assertEquals("matricula", ignorar.intentCodigo());
        assertEquals(List.of("nao_quero", "aluno"), fundir.tokens());
        double cancelaIgnorar = scoreDe(ignorar, "cancelamento");
        double cancelaFundir = scoreDe(fundir, "cancelamento");
        assertTrue(cancelaFundir > cancelaIgnorar, "a negação tem de puxar cancelamento: " + cancelaIgnorar + " -> " + cancelaFundir);
    }

    @Test
    void recuoVoltaAoTokenSimplesQuandoOTreinoNaoConheceANegacaoFundida() {
        // "nao_estacionamento" nunca aparece no treino; com recuo vira "estacionamento"
        Classificacao semRecuo = modelo(ModoNegacao.FUNDIR).classificar("não tem estacionamento", 3);
        Classificacao comRecuo = modelo(ModoNegacao.FUNDIR_COM_RECUO).classificar("não tem estacionamento", 3);

        assertEquals(List.of("nao_estacionamento"), semRecuo.tokens());
        assertEquals(0.0, semRecuo.fracaoConhecida());
        assertEquals(List.of("estacionamento"), comRecuo.tokens());
        assertEquals("estacionamento", comRecuo.intentCodigo());
    }

    @Test
    void recuoNaoMexeNaNegacaoQueOTreinoConhece() {
        Classificacao c = modelo(ModoNegacao.FUNDIR_COM_RECUO).classificar("não quero mais treinar", 3);
        assertEquals(List.of("nao_quero", "treinar"), c.tokens());
        assertEquals("cancelamento", c.intentCodigo());
    }

    private static double scoreDe(Classificacao c, String intent) {
        return c.top().stream().filter(x -> x.intent().equals(intent)).mapToDouble(ClassificadorTfIdf.Candidato::score).findFirst().orElse(0.0);
    }
}
