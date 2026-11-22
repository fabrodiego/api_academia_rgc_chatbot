package com.rgctraining.chatbot.service;

import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.util.Iterator;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.Optional;

/**
 * Contexto mínimo de conversa: a última intent respondida em cada sessão, em memória.
 *
 * Limites para não crescer sem controle: cada entrada expira após o TTL (30 min
 * sem atividade na sessão) e o mapa tem tamanho máximo; ao encher, descarta
 * primeiro as expiradas e depois a sessão usada há mais tempo (LRU).
 */
public class ContextoSessao {

    private record Entrada(String intent, Instant em) {}

    private final Duration ttl;
    private final int maxSessoes;
    private final Clock clock;
    // accessOrder=true: o iterador começa pela sessão usada há mais tempo
    private final Map<String, Entrada> mapa = new LinkedHashMap<>(16, 0.75f, true);

    public ContextoSessao(Duration ttl, int maxSessoes, Clock clock) {
        if (maxSessoes < 1) throw new IllegalArgumentException("maxSessoes deve ser >= 1");
        this.ttl = ttl;
        this.maxSessoes = maxSessoes;
        this.clock = clock;
    }

    /** Última intent da sessão, se ainda não expirou. */
    public synchronized Optional<String> ultimaIntent(String sessionId) {
        Entrada e = mapa.get(sessionId);
        if (e == null) return Optional.empty();
        if (expirada(e)) {
            mapa.remove(sessionId);
            return Optional.empty();
        }
        return Optional.of(e.intent());
    }

    public synchronized void registrar(String sessionId, String intent) {
        if (!mapa.containsKey(sessionId) && mapa.size() >= maxSessoes) {
            removerExpiradas();
            if (mapa.size() >= maxSessoes) {
                Iterator<String> it = mapa.keySet().iterator();
                it.next();
                it.remove();
            }
        }
        mapa.put(sessionId, new Entrada(intent, clock.instant()));
    }

    public synchronized int tamanho() {
        return mapa.size();
    }

    private void removerExpiradas() {
        mapa.values().removeIf(this::expirada);
    }

    private boolean expirada(Entrada e) {
        return !e.em().plus(ttl).isAfter(clock.instant());
    }
}
