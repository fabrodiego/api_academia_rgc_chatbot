package com.rgctraining.chatbot.avaliacao;

/**
 * Resultado de um caso de teste. intentEsperada/intentObtida null = fallback.
 */
public record ResultadoCaso(Long id, String pergunta, String tipo,
                            String intentEsperada, String intentObtida, double score) {

    /** Acerto estrito: obtida == esperada. */
    public boolean acertoEstrito() {
        return EquivalenciaIntents.acertoEstrito(intentEsperada, intentObtida);
    }

    /** Acerto com a regra de equivalência (ver {@link EquivalenciaIntents}). */
    public boolean acerto() {
        return EquivalenciaIntents.acertoComEquivalencia(intentEsperada, intentObtida);
    }
}
