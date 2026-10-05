package com.rgctraining.chatbot.model;

import jakarta.persistence.*;
import java.time.LocalDateTime;

@Entity
@Table(name = "training_phrases")
public class TrainingPhrase {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "intent_id", nullable = false)
    private Long intentId;

    @Column(nullable = false)
    private String texto;

    /** 'seed' = carregada no banco de conhecimento inicial. 'aprendida' = veio de feedback confirmado. */
    @Column(nullable = false)
    private String origem = "seed";

    @Column(name = "conversation_id")
    private Long conversationId;

    @Column(name = "created_at")
    private LocalDateTime createdAt = LocalDateTime.now();

    public Long getId() { return id; }
    public Long getIntentId() { return intentId; }
    public String getTexto() { return texto; }
    public String getOrigem() { return origem; }
    public Long getConversationId() { return conversationId; }
    public LocalDateTime getCreatedAt() { return createdAt; }

    public void setId(Long id) { this.id = id; }
    public void setIntentId(Long intentId) { this.intentId = intentId; }
    public void setTexto(String texto) { this.texto = texto; }
    public void setOrigem(String origem) { this.origem = origem; }
    public void setConversationId(Long conversationId) { this.conversationId = conversationId; }
    public void setCreatedAt(LocalDateTime createdAt) { this.createdAt = createdAt; }
}
