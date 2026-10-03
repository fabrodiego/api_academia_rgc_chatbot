package com.rgctraining.chatbot.model;

import jakarta.persistence.*;

@Entity
@Table(name = "intents")
public class Intent {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false, unique = true)
    private String codigo;

    @Column(nullable = false)
    private String categoria;

    private String descricao;

    public Long getId() { return id; }
    public String getCodigo() { return codigo; }
    public String getCategoria() { return categoria; }
    public String getDescricao() { return descricao; }
    public void setId(Long id) { this.id = id; }
    public void setCodigo(String codigo) { this.codigo = codigo; }
    public void setCategoria(String categoria) { this.categoria = categoria; }
    public void setDescricao(String descricao) { this.descricao = descricao; }
}
