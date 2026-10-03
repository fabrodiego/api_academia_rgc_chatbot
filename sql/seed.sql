SET search_path TO chatbot;

-- 1) Horário de funcionamento
INSERT INTO intents (codigo, categoria, descricao) VALUES
('horario_funcionamento', 'operacional', 'Perguntas sobre horário de abertura e fechamento da academia');

INSERT INTO training_phrases (intent_id, texto) VALUES
(1, 'qual o horario de funcionamento'),
(1, 'a que horas a academia abre'),
(1, 'voces fecham que horas'),
(1, 'funciona aos domingos'),
(1, 'tem academia aberta feriado');

INSERT INTO bot_responses (intent_id, texto) VALUES
(1, 'A Academia RGC Training funciona de segunda a sexta das 6h as 22h, e aos sabados das 8h as 14h. Fechamos aos domingos e feriados.');

-- 2) Planos e matrícula
INSERT INTO intents (codigo, categoria, descricao) VALUES
('planos_matricula', 'comercial', 'Perguntas sobre planos, valores e como se matricular');

INSERT INTO training_phrases (intent_id, texto) VALUES
(2, 'quais sao os planos disponiveis'),
(2, 'quanto custa a mensalidade'),
(2, 'como faco para me matricular'),
(2, 'tem plano trimestral'),
(2, 'quero contratar um plano');

INSERT INTO bot_responses (intent_id, texto) VALUES
(2, 'Temos planos mensal, trimestral e anual. Para matricula, voce pode vir na recepcao com documento com foto ou falar com um consultor pelo whatsapp.');

-- 3) Personal trainer
INSERT INTO intents (codigo, categoria, descricao) VALUES
('personal_trainer', 'servicos', 'Perguntas sobre contratacao de personal trainer');

INSERT INTO training_phrases (intent_id, texto) VALUES
(3, 'tem personal trainer disponivel'),
(3, 'quero treinar com personal'),
(3, 'quanto custa o personal'),
(3, 'como contrato um personal trainer');

INSERT INTO bot_responses (intent_id, texto) VALUES
(3, 'Sim, temos personal trainers credenciados. O valor e combinado direto com o profissional. Posso te passar a lista de personais disponiveis.');

-- 4) Cancelamento / trancamento
INSERT INTO intents (codigo, categoria, descricao) VALUES
('cancelamento_trancamento', 'comercial', 'Pedidos de cancelamento ou trancamento de matricula');

INSERT INTO training_phrases (intent_id, texto) VALUES
(4, 'quero cancelar minha matricula'),
(4, 'como tranco meu plano'),
(4, 'nao quero mais ser aluno'),
(4, 'quero pausar minha academia');

INSERT INTO bot_responses (intent_id, texto) VALUES
(4, 'Para cancelar ou trancar seu plano, e necessario comparecer a recepcao com documento ou enviar o pedido formal pelo nosso email. O trancamento tem prazo minimo de 30 dias.');

-- 5) Aulas e modalidades
INSERT INTO intents (codigo, categoria, descricao) VALUES
('aulas_modalidades', 'operacional', 'Perguntas sobre aulas coletivas e modalidades oferecidas');

INSERT INTO training_phrases (intent_id, texto) VALUES
(5, 'quais modalidades voces tem'),
(5, 'tem aula de spinning'),
(5, 'tem horario de musculacao livre'),
(5, 'quais aulas coletivas tem hoje');

INSERT INTO bot_responses (intent_id, texto) VALUES
(5, 'Temos musculacao livre, spinning, funcional, yoga e jiu-jitsu. A grade completa de horarios fica na recepcao e no mural do app.');
