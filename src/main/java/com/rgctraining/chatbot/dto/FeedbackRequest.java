package com.rgctraining.chatbot.dto;

public class FeedbackRequest {
    private Long conversationId;
    private String intentCorreta;

    public Long getConversationId() { return conversationId; }
    public void setConversationId(Long conversationId) { this.conversationId = conversationId; }
    public String getIntentCorreta() { return intentCorreta; }
    public void setIntentCorreta(String intentCorreta) { this.intentCorreta = intentCorreta; }
}
