package com.rgctraining.chatbot.repository;

import com.rgctraining.chatbot.model.Conversation;
import org.springframework.data.jpa.repository.JpaRepository;

public interface ConversationRepository extends JpaRepository<Conversation, Long> {
}
