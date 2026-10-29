package com.rgctraining.chatbot.controller;

import com.rgctraining.chatbot.dto.ChatRequest;
import com.rgctraining.chatbot.dto.ChatResponse;
import com.rgctraining.chatbot.dto.FeedbackRequest;
import com.rgctraining.chatbot.service.ChatService;
import com.rgctraining.chatbot.service.FeedbackService;
import com.rgctraining.chatbot.service.IntentClassifierService;
import org.springframework.web.bind.annotation.*;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.web.server.ResponseStatusException;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;

@RestController
@RequestMapping("/api/chat")
public class ChatController {

    private final ChatService chatService;
    private final IntentClassifierService classifierService;
    private final FeedbackService feedbackService;
    private final String adminKey;

    public ChatController(ChatService chatService,
                          IntentClassifierService classifierService,
                          FeedbackService feedbackService,
                          @Value("${chatbot.admin-key}") String adminKey) {
        this.chatService = chatService;
        this.classifierService = classifierService;
        this.feedbackService = feedbackService;
        this.adminKey = adminKey;
    }

    @PostMapping
    public ChatResponse chat(@RequestBody ChatRequest request) {
        String sessionId = (request.getSessionId() == null || request.getSessionId().isBlank())
                ? "anonimo"
                : request.getSessionId();

        ChatService.RespostaChat r = chatService.responder(sessionId, request.getMensagem());
        return new ChatResponse(r.resposta(), r.intentDetectado(), r.score(), r.fallback());
    }


    /** Use depois de alterar frases de treino no banco, para recarregar o modelo sem reiniciar o app. */
    @PostMapping("/recarregar-modelo")
    public String recarregarModelo(@RequestHeader(value = "X-Admin-Key", required = false) String chave) {
        exigirAdmin(chave);
        classifierService.recarregar();
        return "Modelo recarregado.";
    }

    /**
     * Feedback humano confirmado: diz qual era a intenção correta de uma
     * conversa já registrada. Isso gera uma nova training_phrase (origem =
     * "aprendida") e recarrega o modelo. Não existe aprendizado automático
     * sem essa confirmação — ver FeedbackService para o motivo.
     */
    @PostMapping("/feedback")
    public String feedback(@RequestHeader(value = "X-Admin-Key", required = false) String chave,
                           @RequestBody FeedbackRequest request) {
        exigirAdmin(chave);
        feedbackService.confirmarIntent(request.getConversationId(), request.getIntentCorreta());
        return "Feedback registrado e modelo recarregado.";
    }

    /** Endpoints de dev: só com a chave ADMIN_KEY. Sem chave configurada, tudo bloqueado. */
    private void exigirAdmin(String chave) {
        if (adminKey.isBlank() || chave == null
                || !MessageDigest.isEqual(adminKey.getBytes(StandardCharsets.UTF_8),
                chave.getBytes(StandardCharsets.UTF_8))) {
            throw new ResponseStatusException(HttpStatus.UNAUTHORIZED, "Chave de admin inválida.");
        }
    }
}