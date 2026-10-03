package com.rgctraining.chatbot.dto;

public class ChatRequest {
    private String sessionId;
    private String mensagem;

    public String getSessionId() { return sessionId; }
    public void setSessionId(String sessionId) { this.sessionId = sessionId; }
    public String getMensagem() { return mensagem; }
    public void setMensagem(String mensagem) { this.mensagem = mensagem; }
}
