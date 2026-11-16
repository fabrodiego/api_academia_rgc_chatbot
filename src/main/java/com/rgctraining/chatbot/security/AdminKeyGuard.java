package com.rgctraining.chatbot.security;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Component;
import org.springframework.web.server.ResponseStatusException;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;

/**
 * Proteção dos endpoints de dev (header X-Admin-Key).
 * Sem chave configurada, tudo fica bloqueado. A comparação é em tempo constante.
 */
@Component
public class AdminKeyGuard {

    private final String adminKey;

    public AdminKeyGuard(@Value("${chatbot.admin-key}") String adminKey) {
        this.adminKey = adminKey;
    }

    public void exigir(String chave) {
        if (adminKey.isBlank() || chave == null
                || !MessageDigest.isEqual(adminKey.getBytes(StandardCharsets.UTF_8),
                chave.getBytes(StandardCharsets.UTF_8))) {
            throw new ResponseStatusException(HttpStatus.UNAUTHORIZED, "Chave de admin inválida.");
        }
    }
}
