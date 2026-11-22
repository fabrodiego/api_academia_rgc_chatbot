package com.rgctraining.chatbot.controller;

import com.rgctraining.chatbot.dto.ChatRequest;
import com.rgctraining.chatbot.dto.ChatResponse;
import com.rgctraining.chatbot.dto.ExplicarResponse;
import com.rgctraining.chatbot.dto.FeedbackRequest;
import com.rgctraining.chatbot.service.ChatService;
import com.rgctraining.chatbot.service.FeedbackService;
import com.rgctraining.chatbot.service.IntentClassifierService;
import com.rgctraining.chatbot.security.AdminKeyGuard;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/chat")
public class ChatController {

    private final ChatService chatService;
    private final IntentClassifierService classifierService;
    private final FeedbackService feedbackService;
    private final AdminKeyGuard adminKeyGuard;

    public ChatController(ChatService chatService,
                          IntentClassifierService classifierService,
                          FeedbackService feedbackService,
                          AdminKeyGuard adminKeyGuard) {
        this.chatService = chatService;
        this.classifierService = classifierService;
        this.feedbackService = feedbackService;
        this.adminKeyGuard = adminKeyGuard;
    }

    @PostMapping
    public ChatResponse chat(@RequestBody ChatRequest request) {
        String sessionId = (request.getSessionId() == null || request.getSessionId().isBlank())
                ? ChatService.SESSAO_ANONIMA
                : request.getSessionId();

        ChatService.RespostaChat r = chatService.responder(sessionId, request.getMensagem());
        return new ChatResponse(r.resposta(), r.intentDetectado(), r.score(), r.fallback());
    }


    /**
     * Público e sem efeito colateral: mostra tokens, top-3, limiar/margem e o motivo da decisão.
     * Não grava em conversations nem altera o contexto da sessão.
     */
    @PostMapping("/explicar")
    public ExplicarResponse explicar(@RequestBody ChatRequest request) {
        String sessionId = (request.getSessionId() == null || request.getSessionId().isBlank())
                ? ChatService.SESSAO_ANONIMA
                : request.getSessionId();
        return chatService.explicar(sessionId, request.getMensagem());
    }

    /** Use depois de alterar frases de treino no banco, para recarregar o modelo sem reiniciar o app. */
    @PostMapping("/recarregar-modelo")
    public String recarregarModelo(@RequestHeader(value = "X-Admin-Key", required = false) String chave) {
        adminKeyGuard.exigir(chave);
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
        adminKeyGuard.exigir(chave);
        feedbackService.confirmarIntent(request.getConversationId(), request.getIntentCorreta());
        return "Feedback registrado e modelo recarregado.";
    }
}
