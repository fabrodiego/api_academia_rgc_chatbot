package com.rgctraining.chatbot.model;

import jakarta.persistence.*;
import java.time.LocalDateTime;

/**
 * Caso de teste do classificador (tabela test_cases).
 * intent_esperada NULL = a resposta certa é o fallback (pergunta fora do escopo).
 * Os campos "obtidos" são preenchidos pelo executor de testes.
 */
@Entity
@Table(name = "test_cases")
public class TestCase {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false)
    private String pergunta;

    @Column(name = "intent_esperada")
    private String intentEsperada;

    @Column(nullable = false)
    private String tipo;

    @Column(name = "intent_obtida")
    private String intentObtida;

    private Double score;

    @Column(name = "resposta_obtida")
    private String respostaObtida;

    private String resultado;

    @Column(name = "executado_em")
    private LocalDateTime executadoEm;

    public Long getId() { return id; }
    public String getPergunta() { return pergunta; }
    public String getIntentEsperada() { return intentEsperada; }
    public String getTipo() { return tipo; }
    public String getIntentObtida() { return intentObtida; }
    public Double getScore() { return score; }
    public String getRespostaObtida() { return respostaObtida; }
    public String getResultado() { return resultado; }
    public LocalDateTime getExecutadoEm() { return executadoEm; }

    public void setId(Long id) { this.id = id; }
    public void setPergunta(String pergunta) { this.pergunta = pergunta; }
    public void setIntentEsperada(String intentEsperada) { this.intentEsperada = intentEsperada; }
    public void setTipo(String tipo) { this.tipo = tipo; }
    public void setIntentObtida(String intentObtida) { this.intentObtida = intentObtida; }
    public void setScore(Double score) { this.score = score; }
    public void setRespostaObtida(String respostaObtida) { this.respostaObtida = respostaObtida; }
    public void setResultado(String resultado) { this.resultado = resultado; }
    public void setExecutadoEm(LocalDateTime executadoEm) { this.executadoEm = executadoEm; }
}
