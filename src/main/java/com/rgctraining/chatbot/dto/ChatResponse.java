package com.rgctraining.chatbot.dto;

public class ChatResponse {
    private String resposta;
    private String intentDetectado;
    private double score;
    private boolean fallback;

    public ChatResponse(String resposta, String intentDetectado, double score, boolean fallback) {
        this.resposta = resposta;
        this.intentDetectado = intentDetectado;
        this.score = score;
        this.fallback = fallback;
    }

    public String getResposta() { return resposta; }
    public String getIntentDetectado() { return intentDetectado; }
    public double getScore() { return score; }
    public boolean isFallback() { return fallback; }
}
