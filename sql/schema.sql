-- Rode conectado no banco academia_rgc_chatbot (psql -d academia_rgc_chatbot -f schema.sql)
CREATE SCHEMA IF NOT EXISTS chatbot;
SET search_path TO chatbot;

CREATE TABLE intents (
    id BIGSERIAL PRIMARY KEY,
    codigo VARCHAR(80) NOT NULL UNIQUE,
    categoria VARCHAR(80) NOT NULL,
    descricao TEXT
);

CREATE TABLE training_phrases (
    id BIGSERIAL PRIMARY KEY,
    intent_id BIGINT NOT NULL REFERENCES intents(id) ON DELETE CASCADE,
    texto TEXT NOT NULL
);

CREATE TABLE bot_responses (
    id BIGSERIAL PRIMARY KEY,
    intent_id BIGINT NOT NULL REFERENCES intents(id) ON DELETE CASCADE,
    texto TEXT NOT NULL
);

CREATE TABLE conversations (
    id BIGSERIAL PRIMARY KEY,
    session_id VARCHAR(100) NOT NULL,
    mensagem_usuario TEXT NOT NULL,
    intent_detectado VARCHAR(80),
    score NUMERIC(5,4),
    resposta TEXT,
    created_at TIMESTAMP NOT NULL DEFAULT now()
);

CREATE TABLE test_cases (
    id BIGSERIAL PRIMARY KEY,
    pergunta TEXT NOT NULL,
    resposta_esperada TEXT,
    resposta_obtida TEXT,
    resultado VARCHAR(20), -- 'ACERTO' | 'ERRO' | 'FALLBACK_ESPERADO'
    created_at TIMESTAMP NOT NULL DEFAULT now()
);

CREATE INDEX idx_training_phrases_intent ON training_phrases(intent_id);
CREATE INDEX idx_bot_responses_intent ON bot_responses(intent_id);
CREATE INDEX idx_conversations_session ON conversations(session_id);
