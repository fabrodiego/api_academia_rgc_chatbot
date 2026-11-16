package com.rgctraining.chatbot.avaliacao;

/**
 * Resultado de um caso de teste. intentEsperada/intentObtida null = fallback.
 */
public record ResultadoCaso(Long id, String pergunta, String tipo,
                            String intentEsperada, String intentObtida, double score) {

    public boolean acerto() {
        return java.util.Objects.equals(intentEsperada, intentObtida);
    }
}
