package com.rgctraining.chatbot.repository;

import com.rgctraining.chatbot.model.TestCase;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface TestCaseRepository extends JpaRepository<TestCase, Long> {
    List<TestCase> findAllByOrderByIdAsc();
}
