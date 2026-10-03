package com.rgctraining.chatbot.repository;

import com.rgctraining.chatbot.model.BotResponse;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface BotResponseRepository extends JpaRepository<BotResponse, Long> {
    List<BotResponse> findByIntentId(Long intentId);
}
