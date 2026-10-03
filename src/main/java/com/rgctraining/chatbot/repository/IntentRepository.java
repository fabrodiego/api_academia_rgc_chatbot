package com.rgctraining.chatbot.repository;

import com.rgctraining.chatbot.model.Intent;
import org.springframework.data.jpa.repository.JpaRepository;

public interface IntentRepository extends JpaRepository<Intent, Long> {
}
