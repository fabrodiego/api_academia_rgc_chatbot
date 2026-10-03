package com.rgctraining.chatbot.controller;

import com.rgctraining.chatbot.dto.ChatRequest;
import com.rgctraining.chatbot.dto.ChatResponse;
import com.rgctraining.chatbot.service.ChatService;
import com.rgctraining.chatbot.service.IntentClassifierService;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/chat")
public class ChatController {

    private final ChatService chatService;
    private final IntentClassifierService classifierService;

    public ChatController(ChatService chatService, IntentClassifierService classifierService) {
        this.chatService = chatService;
        this.classifierService = classifierService;
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
}
