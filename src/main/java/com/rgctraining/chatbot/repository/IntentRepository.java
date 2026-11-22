package com.rgctraining.chatbot.repository;

import com.rgctraining.chatbot.model.Intent;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.Optional;

public interface IntentRepository extends JpaRepository<Intent, Long> {
    Optional<Intent> findByCodigo(String codigo);
}
