package com.rgctraining.chatbot.dto;

import java.util.List;

/**
 * Resposta de POST /api/chat/explicar: o passo a passo da decisão.
 * margem = diferença observada entre a 1ª e a 2ª intent; margemMinima e
 * fracaoMinima são os valores configurados (assim como limiar).
 */
public record ExplicarResponse(
        List<String> tokens,
        double fracaoConhecida,
        List<Candidato> top,
        double limiar,
        double margem,
        double margemMinima,
        double fracaoMinima,
        String decisao,
        String motivo,
        String intent,
        String resposta,
        long latenciaMs) {

    public record Candidato(String intent, double score) {}
}
