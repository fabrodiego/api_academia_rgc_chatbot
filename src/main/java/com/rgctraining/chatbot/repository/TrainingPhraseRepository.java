package com.rgctraining.chatbot.repository;

import com.rgctraining.chatbot.model.TrainingPhrase;
import org.springframework.data.jpa.repository.JpaRepository;

public interface TrainingPhraseRepository extends JpaRepository<TrainingPhrase, Long> {
}
