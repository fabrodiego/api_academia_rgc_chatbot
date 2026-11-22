package com.rgctraining.chatbot.service;

import com.rgctraining.chatbot.dto.ExplicarResponse;
import com.rgctraining.chatbot.model.BotResponse;
import com.rgctraining.chatbot.model.Intent;
import com.rgctraining.chatbot.nlp.ClassificadorTfIdf.Candidato;
import com.rgctraining.chatbot.nlp.ClassificadorTfIdf.Classificacao;
import com.rgctraining.chatbot.repository.BotResponseRepository;
import com.rgctraining.chatbot.repository.ConversationRepository;
import com.rgctraining.chatbot.repository.IntentRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import java.util.List;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

class ChatServiceExplicarTest {

    private IntentClassifierService classificador;
    private BotResponseRepository respostas;
    private IntentRepository intents;
    private ConversationRepository conversas;
    private ChatService chat;

    @BeforeEach
    void montar() {
        classificador = mock(IntentClassifierService.class);
        respostas = mock(BotResponseRepository.class);
        intents = mock(IntentRepository.class);
        conversas = mock(ConversationRepository.class);
        // limiar 0.40, margem 0.10, fração 0.5, margem de contexto 0.10, TTL 30 min, 100 sessões
        chat = new ChatService(classificador, respostas, intents, conversas, 0.40, 0.10, 0.5, 0.10, 30, 100);

        Intent horario = new Intent();
        horario.setId(1L);
        horario.setCodigo("horario");
        when(intents.findByCodigo("horario")).thenReturn(Optional.of(horario));
        BotResponse r = new BotResponse();
        r.setTexto("Abrimos às 6h.");
        when(respostas.findByIntentId(1L)).thenReturn(List.of(r));
    }

    private void classificacao(double fracao, String i1, double s1, String i2, double s2, String i3, double s3) {
        when(classificador.classificar(any())).thenReturn(new Classificacao(i1, s1,
                List.of(new Candidato(i1, s1), new Candidato(i2, s2), new Candidato(i3, s3)),
                List.of("horario", "funcionamento"), fracao));
    }

    @Test
    void explicaRespostaOk() {
        classificacao(1.0, "horario", 0.9, "planos", 0.3, "aulas", 0.1);

        ExplicarResponse e = chat.explicar("s1", "qual o horário");

        assertEquals("resposta", e.decisao());
        assertEquals("ok", e.motivo());
        assertEquals("horario", e.intent());
        assertEquals("Abrimos às 6h.", e.resposta());
        assertEquals(List.of("horario", "funcionamento"), e.tokens());
        assertEquals(1.0, e.fracaoConhecida());
        assertEquals(3, e.top().size());
        assertEquals("horario", e.top().get(0).intent());
        assertEquals(0.40, e.limiar());
        assertEquals(0.6, e.margem(), 1e-9);
        assertTrue(e.latenciaMs() >= 0);
    }

    @Test
    void explicaFallbackPorScoreBaixo() {
        classificacao(1.0, "horario", 0.2, "planos", 0.1, "aulas", 0.0);

        ExplicarResponse e = chat.explicar("s1", "x");

        assertEquals("fallback", e.decisao());
        assertEquals("score_baixo", e.motivo());
        assertNull(e.intent());
        assertTrue(e.resposta().startsWith("Não entendi"));
    }

    @Test
    void explicaFallbackPorMargemPequenaETokensDesconhecidos() {
        classificacao(1.0, "horario", 0.80, "planos", 0.78, "aulas", 0.1);
        assertEquals("margem_pequena", chat.explicar("s1", "x").motivo());

        classificacao(0.2, "horario", 0.9, "planos", 0.1, "aulas", 0.0);
        assertEquals("tokens_desconhecidos", chat.explicar("s1", "x").motivo());
    }

    @Test
    void explicaDesempatePorContextoSemAlterarOContexto() {
        // sessão com contexto: responde (via /chat) algo claro sobre horario antes
        classificacao(1.0, "horario", 0.9, "planos", 0.1, "aulas", 0.0);
        chat.responder("s1", "qual o horário");
        assertEquals("horario", chat.ultimaIntentDa("s1"));

        classificacao(1.0, "planos", 0.80, "horario", 0.78, "aulas", 0.1);
        ExplicarResponse e = chat.explicar("s1", "e os planos?");

        assertEquals("contexto", e.motivo());
        assertEquals("horario", e.intent());
        assertEquals("horario", chat.ultimaIntentDa("s1"), "explicar não muda o contexto");
    }

    @Test
    void explicarNaoGravaConversa() {
        classificacao(1.0, "horario", 0.9, "planos", 0.3, "aulas", 0.1);
        chat.explicar("s1", "qual o horário");
        verifyNoInteractions(conversas);
    }

    @Test
    void chatNormalGravaConversaEGuardaContexto() {
        classificacao(1.0, "horario", 0.9, "planos", 0.3, "aulas", 0.1);
        chat.responder("s1", "qual o horário");
        verify(conversas, times(1)).save(any());
        assertEquals("horario", chat.ultimaIntentDa("s1"));
    }

    @Test
    void sessaoAnonimaNaoUsaContexto() {
        classificacao(1.0, "horario", 0.9, "planos", 0.3, "aulas", 0.1);
        chat.responder(ChatService.SESSAO_ANONIMA, "qual o horário");
        assertNull(chat.ultimaIntentDa(ChatService.SESSAO_ANONIMA));
    }

    @Test
    void fallbackNaoSobrescreveOContexto() {
        classificacao(1.0, "horario", 0.9, "planos", 0.3, "aulas", 0.1);
        chat.responder("s1", "qual o horário");
        classificacao(1.0, "planos", 0.1, "horario", 0.05, "aulas", 0.0);
        chat.responder("s1", "blá");
        assertEquals("horario", chat.ultimaIntentDa("s1"));
    }
}
