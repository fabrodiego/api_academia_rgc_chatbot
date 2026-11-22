package com.rgctraining.chatbot.service;

import org.junit.jupiter.api.Test;

import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.time.ZoneOffset;

import static org.junit.jupiter.api.Assertions.*;

class ContextoSessaoTest {

    /** Relógio que anda só quando o teste manda. */
    private static final class RelogioManual extends Clock {
        private Instant agora = Instant.parse("2026-01-01T12:00:00Z");

        void avancar(Duration d) { agora = agora.plus(d); }

        @Override public java.time.ZoneId getZone() { return ZoneOffset.UTC; }
        @Override public Clock withZone(java.time.ZoneId zone) { return this; }
        @Override public Instant instant() { return agora; }
    }

    private final RelogioManual relogio = new RelogioManual();

    @Test
    void guardaEDevolveAUltimaIntent() {
        var ctx = new ContextoSessao(Duration.ofMinutes(30), 10, relogio);
        ctx.registrar("s1", "plano_mensal");
        assertEquals("plano_mensal", ctx.ultimaIntent("s1").orElseThrow());
        assertTrue(ctx.ultimaIntent("outra").isEmpty());
    }

    @Test
    void expiraDepoisDoTtl() {
        var ctx = new ContextoSessao(Duration.ofMinutes(30), 10, relogio);
        ctx.registrar("s1", "plano_mensal");

        relogio.avancar(Duration.ofMinutes(29));
        assertTrue(ctx.ultimaIntent("s1").isPresent());

        relogio.avancar(Duration.ofMinutes(1)); // 30 min exatos: expirou
        assertTrue(ctx.ultimaIntent("s1").isEmpty());
        assertEquals(0, ctx.tamanho(), "a entrada expirada é removida");
    }

    @Test
    void novoRegistroRenovaOTtl() {
        var ctx = new ContextoSessao(Duration.ofMinutes(30), 10, relogio);
        ctx.registrar("s1", "plano_mensal");
        relogio.avancar(Duration.ofMinutes(20));
        ctx.registrar("s1", "plano_anual");
        relogio.avancar(Duration.ofMinutes(20));
        assertEquals("plano_anual", ctx.ultimaIntent("s1").orElseThrow());
    }

    @Test
    void naoPassaDoLimiteDeSessoesEDescartaAMenosUsada() {
        var ctx = new ContextoSessao(Duration.ofMinutes(30), 3, relogio);
        ctx.registrar("a", "i1");
        ctx.registrar("b", "i2");
        ctx.registrar("c", "i3");
        ctx.ultimaIntent("a"); // "a" foi usada agora; "b" ficou a mais antiga
        ctx.registrar("d", "i4");

        assertEquals(3, ctx.tamanho());
        assertTrue(ctx.ultimaIntent("b").isEmpty());
        assertTrue(ctx.ultimaIntent("a").isPresent());
        assertTrue(ctx.ultimaIntent("d").isPresent());
    }

    @Test
    void aoEncherDescartaPrimeiroAsExpiradas() {
        var ctx = new ContextoSessao(Duration.ofMinutes(30), 2, relogio);
        ctx.registrar("velha", "i1");
        relogio.avancar(Duration.ofMinutes(31));
        ctx.registrar("recente", "i2");
        ctx.registrar("nova", "i3");

        assertEquals(2, ctx.tamanho());
        assertTrue(ctx.ultimaIntent("recente").isPresent(), "a recente não deve ser descartada");
        assertTrue(ctx.ultimaIntent("nova").isPresent());
    }

    @Test
    void atualizarSessaoExistenteNaoDescartaNinguem() {
        var ctx = new ContextoSessao(Duration.ofMinutes(30), 2, relogio);
        ctx.registrar("a", "i1");
        ctx.registrar("b", "i2");
        ctx.registrar("a", "i3");
        assertEquals(2, ctx.tamanho());
        assertTrue(ctx.ultimaIntent("b").isPresent());
    }
}
