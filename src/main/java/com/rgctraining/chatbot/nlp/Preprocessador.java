package com.rgctraining.chatbot.nlp;

import java.util.ArrayList;
import java.util.List;

/**
 * Pré-processamento único, usado igualmente no treino e na mensagem:
 * tokeniza (minúsculas, sem acento, sem pontuação), remove stopwords e trata
 * a negação conforme o {@link ModoNegacao}.
 */
public class Preprocessador {

    /** Como a palavra "não" entra no modelo. */
    public enum ModoNegacao {
        /** "não" é só mais uma stopword e some (comportamento original). */
        IGNORAR,
        /** "não" deixa de ser stopword e vira um token próprio. */
        MANTER,
        /** "não" funde com o próximo token que não é stopword: "não quero" vira "nao_quero". */
        FUNDIR,
        /**
         * Igual a FUNDIR, mas na mensagem um token fundido que o treino nunca viu
         * ("nao_estacionamento") volta ao token simples ("estacionamento"), para a
         * negação não apagar uma palavra conhecida só porque nenhuma frase de treino
         * a nega. O treino é montado igual a FUNDIR.
         */
        FUNDIR_COM_RECUO;

        public static ModoNegacao de(String valor) {
            return valueOf(valor.trim().toUpperCase());
        }
    }

    public static final String NEGACAO = "nao";
    public static final String PREFIXO_NEGACAO = NEGACAO + "_";

    private final Tokenizer tokenizer = new Tokenizer();
    private final StopWordsFilter stopWordsFilter = new StopWordsFilter();
    private final ModoNegacao modoNegacao;

    public Preprocessador() {
        this(ModoNegacao.FUNDIR_COM_RECUO);
    }

    public Preprocessador(ModoNegacao modoNegacao) {
        this.modoNegacao = modoNegacao;
    }

    public ModoNegacao getModoNegacao() {
        return modoNegacao;
    }

    public List<String> processar(String texto) {
        List<String> tokens = tokenizer.tokenize(texto);
        if (modoNegacao == ModoNegacao.IGNORAR) {
            return stopWordsFilter.filtrar(tokens);
        }
        List<String> saida = new ArrayList<>();
        boolean negando = false;
        for (String t : tokens) {
            if (NEGACAO.equals(t)) {
                if (modoNegacao == ModoNegacao.MANTER) {
                    saida.add(t);
                } else {
                    negando = true;
                }
            } else if (!stopWordsFilter.ehStopword(t)) {
                saida.add(negando ? PREFIXO_NEGACAO + t : t);
                negando = false;
            }
        }
        return saida;
    }
}
