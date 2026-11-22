package com.rgctraining.chatbot.service;

import com.rgctraining.chatbot.nlp.ClassificadorTfIdf.Classificacao;

/**
 * Regras de decisão que ficam por cima da similaridade. O TF-IDF só diz
 * "quão parecido"; quem decide se o bot responde ou encaminha são estas regras,
 * na ordem:
 * <ol>
 *   <li>fração de tokens conhecidos &lt; mínima → fallback (tokens_desconhecidos)</li>
 *   <li>score da 1ª intent &lt; limiar → fallback (score_baixo)</li>
 *   <li>margem entre a 1ª e a 2ª intent &lt; mínima → fallback (margem_pequena)</li>
 *   <li>senão → responde com a 1ª intent (ok)</li>
 * </ol>
 * Sem Spring: testável isolado. Valores vêm de application.yml.
 */
public class PoliticaDecisao {

    public enum Motivo {
        OK, SCORE_BAIXO, MARGEM_PEQUENA, TOKENS_DESCONHECIDOS, CONTEXTO;

        /** Nome usado na API (minúsculas). */
        public String codigo() {
            return name().toLowerCase();
        }
    }

    public record Decisao(boolean fallback, String intent, double score, Motivo motivo) {}

    private final double limiar;
    private final double margemMinima;
    private final double fracaoMinima;

    public PoliticaDecisao(double limiar, double margemMinima, double fracaoMinima) {
        this.limiar = limiar;
        this.margemMinima = margemMinima;
        this.fracaoMinima = fracaoMinima;
    }

    public double getLimiar() { return limiar; }
    public double getMargemMinima() { return margemMinima; }
    public double getFracaoMinima() { return fracaoMinima; }

    public Decisao decidir(Classificacao c) {
        if (c.intentCodigo() == null) {
            return new Decisao(true, null, c.score(), Motivo.TOKENS_DESCONHECIDOS);
        }
        if (c.fracaoConhecida() < fracaoMinima) {
            return new Decisao(true, null, c.score(), Motivo.TOKENS_DESCONHECIDOS);
        }
        if (c.score() < limiar) {
            return new Decisao(true, null, c.score(), Motivo.SCORE_BAIXO);
        }
        if (c.margem() < margemMinima) {
            return new Decisao(true, null, c.score(), Motivo.MARGEM_PEQUENA);
        }
        return new Decisao(false, c.intentCodigo(), c.score(), Motivo.OK);
    }
}
