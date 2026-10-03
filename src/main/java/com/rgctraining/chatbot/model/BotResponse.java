package com.rgctraining.chatbot.model;

import jakarta.persistence.*;

@Entity
@Table(name = "bot_responses")
public class BotResponse {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "intent_id", nullable = false)
    private Long intentId;

    @Column(nullable = false)
    private String texto;

    public Long getId() { return id; }
    public Long getIntentId() { return intentId; }
    public String getTexto() { return texto; }
    public void setId(Long id) { this.id = id; }
    public void setIntentId(Long intentId) { this.intentId = intentId; }
    public void setTexto(String texto) { this.texto = texto; }
}
