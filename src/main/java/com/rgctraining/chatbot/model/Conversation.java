package com.rgctraining.chatbot.model;

import jakarta.persistence.*;
import java.time.LocalDateTime;

@Entity
@Table(name = "conversations")
public class Conversation {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "session_id", nullable = false)
    private String sessionId;

    @Column(name = "mensagem_usuario", nullable = false)
    private String mensagemUsuario;

    @Column(name = "intent_detectado")
    private String intentDetectado;

    private Double score;

    private String resposta;

    @Column(name = "created_at")
    private LocalDateTime createdAt = LocalDateTime.now();

    public Long getId() { return id; }
    public String getSessionId() { return sessionId; }
    public String getMensagemUsuario() { return mensagemUsuario; }
    public String getIntentDetectado() { return intentDetectado; }
    public Double getScore() { return score; }
    public String getResposta() { return resposta; }
    public LocalDateTime getCreatedAt() { return createdAt; }

    public void setId(Long id) { this.id = id; }
    public void setSessionId(String sessionId) { this.sessionId = sessionId; }
    public void setMensagemUsuario(String mensagemUsuario) { this.mensagemUsuario = mensagemUsuario; }
    public void setIntentDetectado(String intentDetectado) { this.intentDetectado = intentDetectado; }
    public void setScore(Double score) { this.score = score; }
    public void setResposta(String resposta) { this.resposta = resposta; }
    public void setCreatedAt(LocalDateTime createdAt) { this.createdAt = createdAt; }
}
