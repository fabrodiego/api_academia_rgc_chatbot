package com.rgctraining.chatbot.service;

import com.rgctraining.chatbot.model.Conversation;
import com.rgctraining.chatbot.model.Intent;
import com.rgctraining.chatbot.model.TrainingPhrase;
import com.rgctraining.chatbot.repository.ConversationRepository;
import com.rgctraining.chatbot.repository.IntentRepository;
import com.rgctraining.chatbot.repository.TrainingPhraseRepository;
import org.springframework.stereotype.Service;

import java.util.NoSuchElementException;

/**
 * Aprendizado por feedback CONFIRMADO.
 *
 * Importante: isso só vira dado de treino depois que um humano confirma qual
 * era a intenção correta. Não promovemos automaticamente toda conversa pro
 * treino — isso reforçaria erros de classificação ao invés de corrigi-los.
 */
@Service
public class FeedbackService {

    private final ConversationRepository conversationRepository;
    private final IntentRepository intentRepository;
    private final TrainingPhraseRepository trainingPhraseRepository;
    private final IntentClassifierService classifierService;

    public FeedbackService(ConversationRepository conversationRepository,
                            IntentRepository intentRepository,
                            TrainingPhraseRepository trainingPhraseRepository,
                            IntentClassifierService classifierService) {
        this.conversationRepository = conversationRepository;
        this.intentRepository = intentRepository;
        this.trainingPhraseRepository = trainingPhraseRepository;
        this.classifierService = classifierService;
    }

    public void confirmarIntent(Long conversationId, String intentCodigo) {
        Conversation conversa = conversationRepository.findById(conversationId)
                .orElseThrow(() -> new NoSuchElementException("Conversa não encontrada: " + conversationId));

        Intent intent = intentRepository.findAll().stream()
                .filter(i -> i.getCodigo().equals(intentCodigo))
                .findFirst()
                .orElseThrow(() -> new NoSuchElementException("Intent não encontrada: " + intentCodigo));

        TrainingPhrase novaFrase = new TrainingPhrase();
        novaFrase.setIntentId(intent.getId());
        novaFrase.setTexto(conversa.getMensagemUsuario());
        novaFrase.setOrigem("aprendida");
        novaFrase.setConversationId(conversa.getId());
        trainingPhraseRepository.save(novaFrase);

        // recarrega o modelo TF-IDF em memória para já considerar a nova frase
        classifierService.recarregar();
    }
}
