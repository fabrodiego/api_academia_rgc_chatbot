-- Banco do chatbot Academia RGC Training
-- Uso (instalação nova): psql -d academia_rgc_chatbot -f sql/banco.sql
-- Cria o schema, as tabelas e popula intents, frases de treino e respostas.
-- Tudo roda em uma transação: se der erro, nada é gravado.

BEGIN;

CREATE SCHEMA IF NOT EXISTS chatbot;
SET search_path TO chatbot;

-- =========================================================
-- ESTRUTURA
-- =========================================================

CREATE TABLE intents (
                         id        BIGSERIAL PRIMARY KEY,
                         codigo    VARCHAR(80) NOT NULL UNIQUE,
                         categoria VARCHAR(80) NOT NULL,
                         descricao TEXT
);

CREATE TABLE conversations (
                               id               BIGSERIAL PRIMARY KEY,
                               session_id       VARCHAR(100) NOT NULL,
                               mensagem_usuario TEXT NOT NULL,
                               intent_detectado VARCHAR(80),
                               score            NUMERIC(5,4),
                               resposta         TEXT,
                               created_at       TIMESTAMP NOT NULL DEFAULT now()
);

CREATE TABLE training_phrases (
                                  id              BIGSERIAL PRIMARY KEY,
                                  intent_id       BIGINT NOT NULL REFERENCES intents(id) ON DELETE CASCADE,
                                  texto           TEXT NOT NULL,
                                  origem          VARCHAR(20) NOT NULL DEFAULT 'seed', -- 'seed' | 'aprendida'
                                  conversation_id BIGINT REFERENCES conversations(id) ON DELETE SET NULL,
                                  created_at      TIMESTAMP NOT NULL DEFAULT now()
);

CREATE TABLE bot_responses (
                               id        BIGSERIAL PRIMARY KEY,
                               intent_id BIGINT NOT NULL REFERENCES intents(id) ON DELETE CASCADE,
                               texto     TEXT NOT NULL
);

CREATE TABLE test_cases (
                            id                BIGSERIAL PRIMARY KEY,
                            pergunta          TEXT NOT NULL,
                            resposta_esperada TEXT,
                            resposta_obtida   TEXT,
                            resultado         VARCHAR(20), -- 'ACERTO' | 'ERRO' | 'FALLBACK_ESPERADO'
                            created_at        TIMESTAMP NOT NULL DEFAULT now()
);

CREATE INDEX idx_training_phrases_intent ON training_phrases(intent_id);
CREATE INDEX idx_bot_responses_intent    ON bot_responses(intent_id);
CREATE INDEX idx_conversations_session   ON conversations(session_id);

-- =========================================================
-- DADOS: INTENTS
-- =========================================================

INSERT INTO intents (codigo, categoria, descricao) VALUES
                                                       ('horario_funcionamento',    'operacional', 'Perguntas sobre horário de abertura e fechamento da academia'),
                                                       ('planos_matricula',         'comercial',   'Perguntas sobre planos, valores e como se matricular'),
                                                       ('personal_trainer',         'servicos',    'Perguntas sobre contratacao de personal trainer'),
                                                       ('cancelamento_trancamento', 'comercial',   'Pedidos de cancelamento ou trancamento de matricula'),
                                                       ('aulas_modalidades',        'operacional', 'Perguntas sobre aulas coletivas e modalidades oferecidas');

-- =========================================================
-- DADOS: RESPOSTAS (ligadas pelo código da intent)
-- =========================================================

INSERT INTO bot_responses (intent_id, texto)
SELECT i.id, v.texto
FROM (VALUES
          ('horario_funcionamento',    'A Academia RGC Training funciona de segunda a sexta das 6h as 22h, e aos sabados das 8h as 14h. Fechamos aos domingos e feriados.'),
          ('planos_matricula',         'Temos planos mensal, trimestral e anual. Para matricula, voce pode vir na recepcao com documento com foto ou falar com um consultor pelo whatsapp.'),
          ('personal_trainer',         'Sim, temos personal trainers credenciados. O valor e combinado direto com o profissional. Posso te passar a lista de personais disponiveis.'),
          ('cancelamento_trancamento', 'Para cancelar ou trancar seu plano, e necessario comparecer a recepcao com documento ou enviar o pedido formal pelo nosso email. O trancamento tem prazo minimo de 30 dias.'),
          ('aulas_modalidades',        'Temos musculacao livre, spinning, funcional, yoga e jiu-jitsu. A grade completa de horarios fica na recepcao e no mural do app.')
     ) AS v(codigo, texto)
         JOIN intents i ON i.codigo = v.codigo;

-- =========================================================
-- DADOS: FRASES DE TREINO (ligadas pelo código da intent)
-- =========================================================

INSERT INTO training_phrases (intent_id, texto)
SELECT i.id, v.texto
FROM (VALUES
          -- horario_funcionamento (13)
          ('horario_funcionamento', 'qual o horario de funcionamento'),
          ('horario_funcionamento', 'a que horas a academia abre'),
          ('horario_funcionamento', 'voces fecham que horas'),
          ('horario_funcionamento', 'funciona aos domingos'),
          ('horario_funcionamento', 'tem academia aberta feriado'),
          ('horario_funcionamento', 'que horas voces abrem'),
          ('horario_funcionamento', 'que horas fecha a academia'),
          ('horario_funcionamento', 'academia aberta no sabado'),
          ('horario_funcionamento', 'academia aberta no domingo'),
          ('horario_funcionamento', 'horario de funcionamento hoje'),
          ('horario_funcionamento', 'voces abrem cedo'),
          ('horario_funcionamento', 'ate que horas da pra treinar'),
          ('horario_funcionamento', 'tem academia 24 horas'),

          -- planos_matricula (13)
          ('planos_matricula', 'quais sao os planos disponiveis'),
          ('planos_matricula', 'quanto custa a mensalidade'),
          ('planos_matricula', 'como faco para me matricular'),
          ('planos_matricula', 'tem plano trimestral'),
          ('planos_matricula', 'quero contratar um plano'),
          ('planos_matricula', 'quero saber os valores dos planos'),
          ('planos_matricula', 'tem desconto pra estudante'),
          ('planos_matricula', 'qual o plano mais barato'),
          ('planos_matricula', 'como faco pra ser aluno'),
          ('planos_matricula', 'precisa de exame medico pra matricular'),
          ('planos_matricula', 'tem taxa de matricula'),
          ('planos_matricula', 'quero informacoes sobre mensalidade'),
          ('planos_matricula', 'da pra pagar no cartao'),

          -- personal_trainer (10)
          ('personal_trainer', 'tem personal trainer disponivel'),
          ('personal_trainer', 'quero treinar com personal'),
          ('personal_trainer', 'quanto custa o personal'),
          ('personal_trainer', 'como contrato um personal trainer'),
          ('personal_trainer', 'voces indicam personal trainer'),
          ('personal_trainer', 'quero treino individual com professor'),
          ('personal_trainer', 'tem acompanhamento personalizado'),
          ('personal_trainer', 'quanto cobra um personal da academia'),
          ('personal_trainer', 'como faco pra ter um professor so pra mim'),
          ('personal_trainer', 'personal trainer e separado da mensalidade'),

          -- cancelamento_trancamento (10)
          ('cancelamento_trancamento', 'quero cancelar minha matricula'),
          ('cancelamento_trancamento', 'como tranco meu plano'),
          ('cancelamento_trancamento', 'nao quero mais ser aluno'),
          ('cancelamento_trancamento', 'quero pausar minha academia'),
          ('cancelamento_trancamento', 'quero dar baixa na minha matricula'),
          ('cancelamento_trancamento', 'vou viajar e preciso trancar'),
          ('cancelamento_trancamento', 'como faco pra cancelar o plano'),
          ('cancelamento_trancamento', 'tem multa pra cancelar'),
          ('cancelamento_trancamento', 'quero suspender temporariamente'),
          ('cancelamento_trancamento', 'nao quero renovar o plano'),

          -- aulas_modalidades (10)
          ('aulas_modalidades', 'quais modalidades voces tem'),
          ('aulas_modalidades', 'tem aula de spinning'),
          ('aulas_modalidades', 'tem horario de musculacao livre'),
          ('aulas_modalidades', 'quais aulas coletivas tem hoje'),
          ('aulas_modalidades', 'tem aula de muay thai'),
          ('aulas_modalidades', 'tem crossfit'),
          ('aulas_modalidades', 'horario das aulas de hoje'),
          ('aulas_modalidades', 'quais modalidades tem disponivel'),
          ('aulas_modalidades', 'tem aula pra iniciante'),
          ('aulas_modalidades', 'precisa agendar aula coletiva')
     ) AS v(codigo, texto)
         JOIN intents i ON i.codigo = v.codigo;

COMMIT;