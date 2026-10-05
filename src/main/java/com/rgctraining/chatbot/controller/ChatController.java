package com.rgctraining.chatbot.controller;

import com.rgctraining.chatbot.dto.ChatRequest;
import com.rgctraining.chatbot.dto.ChatResponse;
import com.rgctraining.chatbot.dto.FeedbackRequest;
import com.rgctraining.chatbot.service.ChatService;
import com.rgctraining.chatbot.service.FeedbackService;
import com.rgctraining.chatbot.service.IntentClassifierService;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/chat")
public class ChatController {

    private final ChatService chatService;
    private final IntentClassifierService classifierService;
    private final FeedbackService feedbackService;

    public ChatController(ChatService chatService,
                           IntentClassifierService classifierService,
                           FeedbackService feedbackService) {
        this.chatService = chatService;
        this.classifierService = classifierService;
        this.feedbackService = feedbackService;
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
    public String recarregarModelo() {
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
    public String feedback(@RequestBody FeedbackRequest request) {
        feedbackService.confirmarIntent(request.getConversationId(), request.getIntentCorreta());
        return "Feedback registrado e modelo recarregado.";
    }
}
