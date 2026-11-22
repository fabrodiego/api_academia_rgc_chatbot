package com.rgctraining.chatbot.service;

import com.rgctraining.chatbot.avaliacao.EquivalenciaIntents;
import com.rgctraining.chatbot.nlp.ClassificadorTfIdf.Candidato;
import com.rgctraining.chatbot.nlp.ClassificadorTfIdf.Classificacao;

/**
 * Regras de decisão que ficam por cima da similaridade. O TF-IDF só diz
 * "quão parecido"; quem decide se o bot responde ou encaminha são estas regras,
 * na ordem:
 * <ol>
 *   <li>fração de tokens conhecidos &lt; mínima → fallback (tokens_desconhecidos)</li>
 *   <li>score da 1ª intent &lt; limiar → fallback (score_baixo)</li>
 *   <li>margem entre a 1ª e a 2ª intent &lt; margem de contexto → desempate pela última intent
 *       da sessão, se ela ajudar (motivo contexto); se não ajudar, segue</li>
 *   <li>margem &lt; margem mínima (0 = desligada) → fallback (margem_pequena)</li>
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
    private final double margemContexto;

    /** Sem faixa própria de contexto: usa a margem mínima também para o desempate. */
    public PoliticaDecisao(double limiar, double margemMinima, double fracaoMinima) {
        this(limiar, margemMinima, fracaoMinima, margemMinima);
    }

    /**
     * @param margemMinima   abaixo disso (e sem contexto que ajude) vai para fallback; 0 = regra desligada
     * @param margemContexto abaixo disso o contexto da sessão pode desempatar; independe do fallback por margem
     */
    public PoliticaDecisao(double limiar, double margemMinima, double fracaoMinima, double margemContexto) {
        this.limiar = limiar;
        this.margemMinima = margemMinima;
        this.fracaoMinima = fracaoMinima;
        this.margemContexto = margemContexto;
    }

    public double getMargemContexto() { return margemContexto; }

    public double getLimiar() { return limiar; }
    public double getMargemMinima() { return margemMinima; }
    public double getFracaoMinima() { return fracaoMinima; }

    public Decisao decidir(Classificacao c) {
        return decidir(c, null);
    }

    /**
     * @param ultimaIntent última intent respondida na sessão (ou null). Só entra em
     *                     jogo quando a margem entre a 1ª e a 2ª intent é menor que a margem de contexto:
     *                     se uma das duas for a última intent da sessão (ou da mesma
     *                     família em {@link EquivalenciaIntents}), ela é escolhida.
     */
    public Decisao decidir(Classificacao c, String ultimaIntent) {
        if (c.intentCodigo() == null) {
            return new Decisao(true, null, c.score(), Motivo.TOKENS_DESCONHECIDOS);
        }
        if (c.fracaoConhecida() < fracaoMinima) {
            return new Decisao(true, null, c.score(), Motivo.TOKENS_DESCONHECIDOS);
        }
        if (c.score() < limiar) {
            return new Decisao(true, null, c.score(), Motivo.SCORE_BAIXO);
        }
        if (c.margem() < margemContexto) {
            Candidato escolhida = desempatarPorContexto(c, ultimaIntent);
            if (escolhida != null) {
                return new Decisao(false, escolhida.intent(), escolhida.score(), Motivo.CONTEXTO);
            }
        }
        if (c.margem() < margemMinima) {
            return new Decisao(true, null, c.score(), Motivo.MARGEM_PEQUENA);
        }
        return new Decisao(false, c.intentCodigo(), c.score(), Motivo.OK);
    }

    /** Entre a 1ª e a 2ª intent: a igual à última da sessão; senão, a da mesma família (a 1ª tem preferência). */
    private static Candidato desempatarPorContexto(Classificacao c, String ultimaIntent) {
        if (ultimaIntent == null || c.top().size() < 2) return null;
        Candidato primeira = c.top().get(0);
        Candidato segunda = c.top().get(1);
        if (primeira.intent().equals(ultimaIntent)) return primeira;
        if (segunda.intent().equals(ultimaIntent)) return segunda;
        if (EquivalenciaIntents.mesmaFamilia(ultimaIntent, primeira.intent())) return primeira;
        if (EquivalenciaIntents.mesmaFamilia(ultimaIntent, segunda.intent())) return segunda;
        return null;
    }
}
