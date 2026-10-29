-- Banco do chatbot Academia RGC Training
-- Uso: psql -d academia_rgc_chatbot -v ON_ERROR_STOP=1 -f sql/banco.sql
-- Cria as tabelas se não existirem e SUBSTITUI todos os dados (as tabelas e
-- as permissões continuam). Roda em uma transação: se der erro, nada é gravado.

BEGIN;

CREATE SCHEMA IF NOT EXISTS chatbot;
SET search_path TO chatbot;

-- =========================================================
-- ESTRUTURA (só cria o que ainda não existe)
-- =========================================================

CREATE TABLE IF NOT EXISTS intents (
    id        BIGSERIAL PRIMARY KEY,
    codigo    VARCHAR(80) NOT NULL UNIQUE,
    categoria VARCHAR(80) NOT NULL,
    descricao TEXT
);

CREATE TABLE IF NOT EXISTS conversations (
    id               BIGSERIAL PRIMARY KEY,
    session_id       VARCHAR(100) NOT NULL,
    mensagem_usuario TEXT NOT NULL,
    intent_detectado VARCHAR(80),
    score            NUMERIC(5,4),
    resposta         TEXT,
    created_at       TIMESTAMP NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS training_phrases (
    id              BIGSERIAL PRIMARY KEY,
    intent_id       BIGINT NOT NULL REFERENCES intents(id) ON DELETE CASCADE,
    texto           TEXT NOT NULL,
    origem          VARCHAR(20) NOT NULL DEFAULT 'seed', -- 'seed' | 'aprendida'
    conversation_id BIGINT REFERENCES conversations(id) ON DELETE SET NULL,
    created_at      TIMESTAMP NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS bot_responses (
    id        BIGSERIAL PRIMARY KEY,
    intent_id BIGINT NOT NULL REFERENCES intents(id) ON DELETE CASCADE,
    texto     TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS test_cases (
    id              BIGSERIAL PRIMARY KEY,
    pergunta        TEXT NOT NULL,
    resposta_obtida TEXT,
    resultado       VARCHAR(20), -- 'ACERTO' | 'ERRO'
    created_at      TIMESTAMP NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_training_phrases_intent ON training_phrases(intent_id);
CREATE INDEX IF NOT EXISTS idx_bot_responses_intent    ON bot_responses(intent_id);
CREATE INDEX IF NOT EXISTS idx_conversations_session   ON conversations(session_id);

-- =========================================================
-- LIMPEZA: apaga as linhas de todas as tabelas e reinicia os IDs
-- =========================================================

TRUNCATE test_cases, training_phrases, bot_responses, conversations, intents RESTART IDENTITY;

-- Casos de teste para avaliação do classificador (acurácia e matriz de confusão).
-- intent_esperada NULL = a resposta certa é o fallback (pergunta fora do escopo).
-- intent_obtida, score, resposta_obtida, resultado e executado_em são preenchidos ao rodar os testes.
ALTER TABLE test_cases DROP COLUMN IF EXISTS resposta_esperada;
ALTER TABLE test_cases ADD COLUMN IF NOT EXISTS intent_esperada VARCHAR(80) REFERENCES intents(codigo) ON UPDATE CASCADE;
ALTER TABLE test_cases ADD COLUMN IF NOT EXISTS tipo VARCHAR(20) NOT NULL CHECK (tipo IN ('padrao', 'variacao', 'dificil', 'fora_escopo'));
ALTER TABLE test_cases ADD COLUMN IF NOT EXISTS intent_obtida VARCHAR(80);
ALTER TABLE test_cases ADD COLUMN IF NOT EXISTS score NUMERIC(5,4);
ALTER TABLE test_cases ADD COLUMN IF NOT EXISTS executado_em TIMESTAMP;

-- =========================================================
-- DADOS: INTENTS
-- =========================================================

INSERT INTO intents (codigo, categoria, descricao) VALUES
    ('saudacao', 'social', 'Cumprimentos e início de conversa'),
    ('despedida', 'social', 'Encerramento da conversa'),
    ('agradecimento', 'social', 'Agradecimentos e elogios ao atendimento'),
    ('sobre_bot', 'social', 'Perguntas sobre o próprio assistente'),
    ('atendimento_humano', 'suporte', 'Pedido para falar com uma pessoa da equipe'),
    ('reclamacao_sugestao', 'suporte', 'Reclamações, problemas e sugestões'),
    ('horario_funcionamento', 'operacional', 'Horário de abertura e fechamento da academia'),
    ('endereco_localizacao', 'operacional', 'Endereço, localização e como chegar'),
    ('contato', 'operacional', 'Telefone, WhatsApp e e-mail'),
    ('estacionamento', 'operacional', 'Estacionamento e bicicletário'),
    ('estrutura', 'operacional', 'Vestiário, armários, equipamentos e acessibilidade'),
    ('acesso_academia', 'operacional', 'Entrada na academia, catraca e biometria'),
    ('idade_minima', 'operacional', 'Idade mínima e público atendido'),
    ('planos_valores', 'comercial', 'Planos disponíveis e valores'),
    ('matricula', 'comercial', 'Como se matricular, documentos e taxa'),
    ('formas_pagamento', 'financeiro', 'Formas de pagamento aceitas'),
    ('descontos_promocoes', 'comercial', 'Descontos, promoções e convênios'),
    ('troca_plano', 'comercial', 'Troca, upgrade e renovação de plano'),
    ('pagamento_atrasado', 'financeiro', 'Mensalidade atrasada e segunda via'),
    ('cancelamento', 'comercial', 'Cancelamento de plano'),
    ('trancamento', 'comercial', 'Trancamento/pausa temporária do plano'),
    ('personal_trainer', 'servicos', 'Personal trainer'),
    ('avaliacao_fisica', 'servicos', 'Avaliação física e reavaliação'),
    ('aula_experimental', 'servicos', 'Aula experimental, visita e diária'),
    ('aulas_modalidades', 'servicos', 'Modalidades e aulas coletivas oferecidas'),
    ('horario_aulas', 'servicos', 'Grade de horários das aulas coletivas');

-- =========================================================
-- DADOS: RESPOSTAS (ligadas pelo código da intent; mais de uma = sorteio)
-- =========================================================

INSERT INTO bot_responses (intent_id, texto)
SELECT i.id, v.texto
FROM (VALUES

    -- saudacao (3)
    ('saudacao', 'Olá! Sou o assistente virtual da Academia RGC Training. Posso ajudar com horários, planos, pagamento, aulas, personal, matrícula e muito mais. Como posso ajudar?'),
    ('saudacao', 'Oi! Que bom ter você aqui na RGC Training. Me conta: o que você quer saber? Horários, planos, aulas, endereço…'),
    ('saudacao', 'Olá, tudo bem? Aqui é o assistente da RGC Training. Pode perguntar sobre planos, horários, modalidades, pagamento ou matrícula.'),

    -- despedida (3)
    ('despedida', 'Até mais! Bom treino e conte com a RGC Training. 💪'),
    ('despedida', 'Tchau! Se precisar de algo, é só chamar aqui no chat.'),
    ('despedida', 'Até logo! Qualquer dúvida, estamos por aqui.'),

    -- agradecimento (3)
    ('agradecimento', 'Por nada! Fico feliz em ajudar. Se tiver mais alguma dúvida, é só perguntar.'),
    ('agradecimento', 'Disponha! Estamos aqui para ajudar no que precisar.'),
    ('agradecimento', 'Imagina! Qualquer coisa, é só chamar.'),

    -- sobre_bot (2)
    ('sobre_bot', 'Sou o assistente virtual da RGC Training. Eu entendo a sua pergunta comparando com exemplos que aprendi (PLN com TF-IDF). Se eu não souber responder, encaminho para um atendente humano.'),
    ('sobre_bot', 'Eu sou um chatbot, um assistente automático da RGC Training. Respondo dúvidas sobre a academia a qualquer hora. Para casos mais específicos, chamo a equipe humana.'),

    -- atendimento_humano (1)
    ('atendimento_humano', 'Claro! Para falar com uma pessoa da equipe, chame no WhatsApp (48) 3000-0000, ligue no mesmo número ou passe na recepção. Atendemos no horário de funcionamento da academia.'),

    -- reclamacao_sugestao (2)
    ('reclamacao_sugestao', 'Sentimos muito pelo problema. Sua opinião é importante: envie a reclamação ou sugestão para contato@rgctraining.example ou fale com a recepção. A equipe responde em até 2 dias úteis.'),
    ('reclamacao_sugestao', 'Obrigado por avisar. Registre sua reclamação ou sugestão pelo e-mail contato@rgctraining.example ou na recepção, para a gerência analisar. Respondemos em até 2 dias úteis.'),

    -- horario_funcionamento (1)
    ('horario_funcionamento', 'A Academia RGC Training funciona de segunda a sexta das 5h30 às 23h, aos sábados das 7h às 19h, e aos domingos e feriados das 8h às 14h.'),

    -- endereco_localizacao (1)
    ('endereco_localizacao', 'Estamos na Av. Exemplo, 1200, Centro, Palhoça - SC, CEP 88130-000. No site tem o mapa com a localização.'),

    -- contato (1)
    ('contato', 'Você pode falar com a gente pelo telefone/WhatsApp (48) 3000-0000 ou pelo e-mail contato@rgctraining.example.'),

    -- estacionamento (1)
    ('estacionamento', 'Temos estacionamento próprio gratuito para alunos, com 30 vagas para carro, vagas para moto e bicicletário.'),

    -- estrutura (1)
    ('estrutura', 'A RGC tem vestiários masculino e feminino com chuveiro quente, armários de uso diário (traga seu cadeado), bebedouros, wi-fi gratuito e ar-condicionado. Os equipamentos são novos, com manutenção semanal, e temos rampa e banheiro adaptado.'),

    -- acesso_academia (1)
    ('acesso_academia', 'A entrada é feita por biometria (digital) na catraca. O cadastro da digital é feito na recepção no dia da matrícula. Se a catraca não liberar, procure a recepção.'),

    -- idade_minima (1)
    ('idade_minima', 'Aceitamos alunos a partir de 14 anos. Menores de 18 precisam de autorização assinada pelo responsável na matrícula. Não há idade máxima: idosos são muito bem-vindos.'),

    -- planos_valores (1)
    ('planos_valores', 'Temos 3 planos, todos com musculação e aulas coletivas:
• Mensal: R$ 129/mês, sem fidelidade.
• Trimestral: R$ 109/mês, com 1 reavaliação física e "traga um amigo" 2x por mês.
• Anual: R$ 89/mês, com matrícula grátis e trancamento de até 30 dias.
Matrícula: R$ 59 nos planos Mensal e Trimestral.'),

    -- matricula (1)
    ('matricula', 'Para se matricular, venha à recepção com documento com foto e CPF, ou comece pelo WhatsApp (48) 3000-0000. A taxa de matrícula é R$ 59 nos planos Mensal e Trimestral e grátis no Anual. Atestado médico não é obrigatório, mas recomendamos.'),

    -- formas_pagamento (1)
    ('formas_pagamento', 'Aceitamos Pix, cartão de crédito, cartão de débito e dinheiro na recepção. O plano Mensal pode ser cobrado no cartão de crédito recorrente. Trimestral e Anual podem ser parcelados no cartão de crédito sem juros (até 3x e 12x). Não trabalhamos com boleto.'),

    -- descontos_promocoes (1)
    ('descontos_promocoes', 'No momento não temos desconto para estudante, família ou convênio, e não aceitamos Wellhub (Gympass) nem TotalPass. O melhor custo é o plano Anual (R$ 89/mês, matrícula grátis). No Trimestral você pode trazer um amigo 2x por mês.'),

    -- troca_plano (1)
    ('troca_plano', 'Você pode trocar para um plano maior (upgrade) a qualquer momento na recepção, pagando só a diferença proporcional. A troca para um plano menor é feita na renovação.'),

    -- pagamento_atrasado (1)
    ('pagamento_atrasado', 'Se a mensalidade estiver atrasada, o acesso na catraca fica bloqueado até o pagamento. Você pode quitar na recepção ou pedir o Pix pelo WhatsApp (48) 3000-0000. Atraso tem multa de 2% mais juros de 1% ao mês.'),

    -- cancelamento (1)
    ('cancelamento', 'Para cancelar, faça o pedido na recepção com documento ou pelo e-mail contato@rgctraining.example. No plano Mensal não há multa. No Trimestral e no Anual a multa é de 10% sobre as mensalidades restantes.'),

    -- trancamento (1)
    ('trancamento', 'O trancamento é um benefício do plano Anual: até 30 dias por ano, pedido na recepção com 7 dias de antecedência. Em qualquer plano, com atestado médico, o plano pode ser congelado pelo período do atestado.'),

    -- personal_trainer (1)
    ('personal_trainer', 'Temos personal trainers formados em Educação Física, sob agendamento. A aula avulsa custa a partir de R$ 70 e há pacotes mensais com desconto. O valor do personal é separado da mensalidade. Agende na recepção ou pelo WhatsApp (48) 3000-0000.'),

    -- avaliacao_fisica (1)
    ('avaliacao_fisica', 'A avaliação física inicial é gratuita em todos os planos e inclui bioimpedância, medidas e teste postural. O plano Trimestral inclui 1 reavaliação. Avaliação avulsa custa R$ 40. Agende na recepção.'),

    -- aula_experimental (1)
    ('aula_experimental', 'A primeira aula é grátis! Agende pelo WhatsApp (48) 3000-0000 ou na recepção e traga um documento com foto. Se quiser treinar só um dia, a diária avulsa custa R$ 30.'),

    -- aulas_modalidades (1)
    ('aulas_modalidades', 'Oferecemos musculação livre e aulas coletivas de Funcional, Spinning, Yoga e Dança, com turmas pequenas e para todos os níveis. Todas estão incluídas em qualquer plano. No momento não temos pilates, crossfit, lutas nem natação.'),

    -- horario_aulas (1)
    ('horario_aulas', 'Grade das aulas coletivas:
• Funcional: seg, qua e sex às 7h e às 19h.
• Spinning: ter e qui às 6h30 e às 19h30; sáb às 9h.
• Yoga: ter e qui às 8h; sáb às 10h.
• Dança: seg e qua às 20h.
As vagas são por ordem de chegada.')
) AS v(codigo, texto)
JOIN intents i ON i.codigo = v.codigo;

-- =========================================================
-- DADOS: FRASES DE TREINO (ligadas pelo código da intent)
-- =========================================================

INSERT INTO training_phrases (intent_id, texto)
SELECT i.id, v.texto
FROM (VALUES

    -- saudacao (30)
    ('saudacao', 'oi'),
    ('saudacao', 'ola'),
    ('saudacao', 'oi tudo bem'),
    ('saudacao', 'ola tudo bem'),
    ('saudacao', 'bom dia'),
    ('saudacao', 'boa tarde'),
    ('saudacao', 'boa noite'),
    ('saudacao', 'eai'),
    ('saudacao', 'e ai'),
    ('saudacao', 'opa'),
    ('saudacao', 'opa tudo certo'),
    ('saudacao', 'salve'),
    ('saudacao', 'hey'),
    ('saudacao', 'hello'),
    ('saudacao', 'oii'),
    ('saudacao', 'oiii'),
    ('saudacao', 'oi boa tarde'),
    ('saudacao', 'ola bom dia'),
    ('saudacao', 'tudo bem'),
    ('saudacao', 'tudo bom'),
    ('saudacao', 'beleza'),
    ('saudacao', 'fala ai'),
    ('saudacao', 'oi pessoal'),
    ('saudacao', 'ola academia'),
    ('saudacao', 'oi gostaria de informacoes'),
    ('saudacao', 'bom dia tudo bem'),
    ('saudacao', 'boa noite tudo bem'),
    ('saudacao', 'oie'),
    ('saudacao', 'alo'),
    ('saudacao', 'oi alguem ai'),

    -- despedida (22)
    ('despedida', 'tchau'),
    ('despedida', 'tchau tchau'),
    ('despedida', 'xau'),
    ('despedida', 'ate logo'),
    ('despedida', 'ate mais'),
    ('despedida', 'ate amanha'),
    ('despedida', 'ate a proxima'),
    ('despedida', 'falou'),
    ('despedida', 'flw'),
    ('despedida', 'adeus'),
    ('despedida', 'fui'),
    ('despedida', 'ate breve'),
    ('despedida', 'era so isso'),
    ('despedida', 'so isso mesmo'),
    ('despedida', 'por hoje e so'),
    ('despedida', 'encerrar conversa'),
    ('despedida', 'vou nessa'),
    ('despedida', 'ate depois'),
    ('despedida', 'tenha um bom dia'),
    ('despedida', 'boa semana'),
    ('despedida', 'bom final de semana'),
    ('despedida', 'ate outro dia'),

    -- agradecimento (25)
    ('agradecimento', 'obrigado'),
    ('agradecimento', 'obrigada'),
    ('agradecimento', 'muito obrigado'),
    ('agradecimento', 'muito obrigada'),
    ('agradecimento', 'obg'),
    ('agradecimento', 'brigado'),
    ('agradecimento', 'brigadao'),
    ('agradecimento', 'valeu'),
    ('agradecimento', 'vlw'),
    ('agradecimento', 'valeu mesmo'),
    ('agradecimento', 'agradeco'),
    ('agradecimento', 'agradeco a ajuda'),
    ('agradecimento', 'obrigado pela ajuda'),
    ('agradecimento', 'obrigado pela informacao'),
    ('agradecimento', 'ajudou muito'),
    ('agradecimento', 'show'),
    ('agradecimento', 'show de bola'),
    ('agradecimento', 'perfeito'),
    ('agradecimento', 'otimo'),
    ('agradecimento', 'entendi obrigado'),
    ('agradecimento', 'top'),
    ('agradecimento', 'massa valeu'),
    ('agradecimento', 'gratidao'),
    ('agradecimento', 'excelente atendimento'),
    ('agradecimento', 'voce ajudou bastante'),

    -- sobre_bot (17)
    ('sobre_bot', 'voce e um robo'),
    ('sobre_bot', 'e um robo'),
    ('sobre_bot', 'estou falando com um robo'),
    ('sobre_bot', 'voce e um bot'),
    ('sobre_bot', 'isso e um chatbot'),
    ('sobre_bot', 'quem e voce'),
    ('sobre_bot', 'quem esta falando'),
    ('sobre_bot', 'voce e humano ou robo'),
    ('sobre_bot', 'voce e de verdade'),
    ('sobre_bot', 'voce e uma inteligencia artificial'),
    ('sobre_bot', 'e inteligencia artificial'),
    ('sobre_bot', 'como voce funciona'),
    ('sobre_bot', 'qual seu nome'),
    ('sobre_bot', 'voce tem nome'),
    ('sobre_bot', 'assistente virtual'),
    ('sobre_bot', 'voce e o chatgpt'),
    ('sobre_bot', 'e resposta automatica'),

    -- atendimento_humano (20)
    ('atendimento_humano', 'quero falar com atendente'),
    ('atendimento_humano', 'falar com um atendente'),
    ('atendimento_humano', 'quero falar com uma pessoa'),
    ('atendimento_humano', 'quero falar com humano'),
    ('atendimento_humano', 'me passa para um humano'),
    ('atendimento_humano', 'atendimento humano'),
    ('atendimento_humano', 'tem alguem ai'),
    ('atendimento_humano', 'falar com alguem da academia'),
    ('atendimento_humano', 'quero falar com o gerente'),
    ('atendimento_humano', 'chamar um atendente'),
    ('atendimento_humano', 'transferir para atendente'),
    ('atendimento_humano', 'quero atendimento de verdade'),
    ('atendimento_humano', 'falar com a recepcao'),
    ('atendimento_humano', 'preciso de ajuda de uma pessoa'),
    ('atendimento_humano', 'atendente por favor'),
    ('atendimento_humano', 'falar com o responsavel'),
    ('atendimento_humano', 'quero falar com o dono'),
    ('atendimento_humano', 'pessoa de verdade'),
    ('atendimento_humano', 'transfere para um atendente'),
    ('atendimento_humano', 'me transfere para alguem'),

    -- reclamacao_sugestao (18)
    ('reclamacao_sugestao', 'quero fazer uma reclamacao'),
    ('reclamacao_sugestao', 'tenho uma reclamacao'),
    ('reclamacao_sugestao', 'quero reclamar'),
    ('reclamacao_sugestao', 'quero dar uma sugestao'),
    ('reclamacao_sugestao', 'tenho uma sugestao'),
    ('reclamacao_sugestao', 'aparelho quebrado'),
    ('reclamacao_sugestao', 'a esteira esta quebrada'),
    ('reclamacao_sugestao', 'maquina estragada'),
    ('reclamacao_sugestao', 'o vestiario esta sujo'),
    ('reclamacao_sugestao', 'academia muito lotada'),
    ('reclamacao_sugestao', 'estou insatisfeito'),
    ('reclamacao_sugestao', 'pessimo atendimento'),
    ('reclamacao_sugestao', 'professor foi grosso'),
    ('reclamacao_sugestao', 'ar condicionado nao funciona'),
    ('reclamacao_sugestao', 'ouvidoria'),
    ('reclamacao_sugestao', 'problema na academia'),
    ('reclamacao_sugestao', 'fui mal atendido'),
    ('reclamacao_sugestao', 'musica muito alta'),

    -- horario_funcionamento (26)
    ('horario_funcionamento', 'qual o horario de funcionamento'),
    ('horario_funcionamento', 'horario de funcionamento'),
    ('horario_funcionamento', 'que horas abre'),
    ('horario_funcionamento', 'que horas a academia abre'),
    ('horario_funcionamento', 'que horas fecha'),
    ('horario_funcionamento', 'ate que horas fica aberta'),
    ('horario_funcionamento', 'abre que horas'),
    ('horario_funcionamento', 'fecha que horas'),
    ('horario_funcionamento', 'horario da academia'),
    ('horario_funcionamento', 'funciona domingo'),
    ('horario_funcionamento', 'abre no domingo'),
    ('horario_funcionamento', 'abre sabado'),
    ('horario_funcionamento', 'horario de sabado'),
    ('horario_funcionamento', 'funciona no feriado'),
    ('horario_funcionamento', 'abre feriado'),
    ('horario_funcionamento', 'abre cedo'),
    ('horario_funcionamento', 'abre de madrugada'),
    ('horario_funcionamento', 'funciona 24 horas'),
    ('horario_funcionamento', 'ate que horas posso treinar'),
    ('horario_funcionamento', 'horario de segunda a sexta'),
    ('horario_funcionamento', 'esta aberta agora'),
    ('horario_funcionamento', 'a academia ja abriu'),
    ('horario_funcionamento', 'fecha tarde'),
    ('horario_funcionamento', 'horario de domingo'),
    ('horario_funcionamento', 'funciona no natal'),
    ('horario_funcionamento', 'horario de atendimento'),

    -- endereco_localizacao (21)
    ('endereco_localizacao', 'onde fica a academia'),
    ('endereco_localizacao', 'qual o endereco'),
    ('endereco_localizacao', 'endereco da academia'),
    ('endereco_localizacao', 'onde voces ficam'),
    ('endereco_localizacao', 'localizacao'),
    ('endereco_localizacao', 'qual a localizacao'),
    ('endereco_localizacao', 'como chego ai'),
    ('endereco_localizacao', 'como chegar na academia'),
    ('endereco_localizacao', 'fica em qual bairro'),
    ('endereco_localizacao', 'fica em qual cidade'),
    ('endereco_localizacao', 'qual a rua'),
    ('endereco_localizacao', 'qual o cep'),
    ('endereco_localizacao', 'manda a localizacao'),
    ('endereco_localizacao', 'fica no centro'),
    ('endereco_localizacao', 'fica em palhoca'),
    ('endereco_localizacao', 'e perto da unisul'),
    ('endereco_localizacao', 'tem outra unidade'),
    ('endereco_localizacao', 'tem filial'),
    ('endereco_localizacao', 'endereco completo'),
    ('endereco_localizacao', 'ponto de referencia'),
    ('endereco_localizacao', 'localizacao no mapa'),

    -- contato (18)
    ('contato', 'qual o telefone'),
    ('contato', 'telefone da academia'),
    ('contato', 'numero de telefone'),
    ('contato', 'qual o whatsapp'),
    ('contato', 'tem whatsapp'),
    ('contato', 'numero do zap'),
    ('contato', 'me passa o zap'),
    ('contato', 'qual o email'),
    ('contato', 'email da academia'),
    ('contato', 'como entro em contato'),
    ('contato', 'contato da academia'),
    ('contato', 'posso ligar'),
    ('contato', 'numero para ligar'),
    ('contato', 'telefone para contato'),
    ('contato', 'whats da academia'),
    ('contato', 'manda o numero'),
    ('contato', 'tem instagram'),
    ('contato', 'redes sociais'),

    -- estacionamento (16)
    ('estacionamento', 'tem estacionamento'),
    ('estacionamento', 'onde estaciono'),
    ('estacionamento', 'estacionamento e gratis'),
    ('estacionamento', 'estacionamento pago'),
    ('estacionamento', 'posso estacionar o carro'),
    ('estacionamento', 'vaga para carro'),
    ('estacionamento', 'vaga para moto'),
    ('estacionamento', 'tem bicicletario'),
    ('estacionamento', 'onde deixo a bicicleta'),
    ('estacionamento', 'estacionar na academia'),
    ('estacionamento', 'tem vaga de estacionamento'),
    ('estacionamento', 'estacionamento para alunos'),
    ('estacionamento', 'tem garagem'),
    ('estacionamento', 'onde paro o carro'),
    ('estacionamento', 'onde deixo a bike'),
    ('estacionamento', 'lugar para bicicleta'),

    -- estrutura (27)
    ('estrutura', 'tem vestiario'),
    ('estrutura', 'tem chuveiro'),
    ('estrutura', 'posso tomar banho'),
    ('estrutura', 'tem chuveiro quente'),
    ('estrutura', 'tem armario'),
    ('estrutura', 'precisa levar cadeado'),
    ('estrutura', 'onde guardo minhas coisas'),
    ('estrutura', 'tem bebedouro'),
    ('estrutura', 'tem agua'),
    ('estrutura', 'tem wifi'),
    ('estrutura', 'senha do wifi'),
    ('estrutura', 'tem wi-fi'),
    ('estrutura', 'tem internet'),
    ('estrutura', 'tem ar condicionado'),
    ('estrutura', 'academia climatizada'),
    ('estrutura', 'equipamentos sao novos'),
    ('estrutura', 'quais aparelhos tem'),
    ('estrutura', 'tem esteira'),
    ('estrutura', 'tem bicicleta ergometrica'),
    ('estrutura', 'tem acessibilidade'),
    ('estrutura', 'acesso para cadeirante'),
    ('estrutura', 'banheiro adaptado'),
    ('estrutura', 'estrutura da academia'),
    ('estrutura', 'academia e grande'),
    ('estrutura', 'tem toalha'),
    ('estrutura', 'precisa levar toalha'),
    ('estrutura', 'tem secador'),

    -- acesso_academia (16)
    ('acesso_academia', 'como entro na academia'),
    ('acesso_academia', 'como funciona a catraca'),
    ('acesso_academia', 'catraca nao libera'),
    ('acesso_academia', 'a catraca travou'),
    ('acesso_academia', 'minha digital nao funciona'),
    ('acesso_academia', 'biometria nao funciona'),
    ('acesso_academia', 'cadastrar digital'),
    ('acesso_academia', 'precisa de carteirinha'),
    ('acesso_academia', 'esqueci a carteirinha'),
    ('acesso_academia', 'entrada por biometria'),
    ('acesso_academia', 'acesso por digital'),
    ('acesso_academia', 'nao consigo entrar'),
    ('acesso_academia', 'como libero minha entrada'),
    ('acesso_academia', 'acesso bloqueado'),
    ('acesso_academia', 'entrada na academia'),
    ('acesso_academia', 'como e a entrada'),

    -- idade_minima (14)
    ('idade_minima', 'qual a idade minima'),
    ('idade_minima', 'idade minima para treinar'),
    ('idade_minima', 'menor de idade pode treinar'),
    ('idade_minima', 'adolescente pode malhar'),
    ('idade_minima', 'com quantos anos posso treinar'),
    ('idade_minima', 'meu filho de 14 anos pode'),
    ('idade_minima', 'crianca pode treinar'),
    ('idade_minima', 'tenho 15 anos posso me matricular'),
    ('idade_minima', 'menor precisa de autorizacao'),
    ('idade_minima', 'idoso pode treinar'),
    ('idade_minima', 'tem limite de idade'),
    ('idade_minima', 'tem aula para criancas'),
    ('idade_minima', 'aceita menor'),
    ('idade_minima', 'tenho 13 anos'),

    -- planos_valores (26)
    ('planos_valores', 'quais sao os planos'),
    ('planos_valores', 'quais planos voces tem'),
    ('planos_valores', 'planos disponiveis'),
    ('planos_valores', 'quanto custa'),
    ('planos_valores', 'quanto custa a academia'),
    ('planos_valores', 'qual o valor da mensalidade'),
    ('planos_valores', 'valor da mensalidade'),
    ('planos_valores', 'preco da academia'),
    ('planos_valores', 'tabela de precos'),
    ('planos_valores', 'quanto e o plano mensal'),
    ('planos_valores', 'valor do plano trimestral'),
    ('planos_valores', 'quanto custa o plano anual'),
    ('planos_valores', 'qual o plano mais barato'),
    ('planos_valores', 'qual o melhor plano'),
    ('planos_valores', 'diferenca entre os planos'),
    ('planos_valores', 'o que inclui o plano'),
    ('planos_valores', 'plano sem fidelidade'),
    ('planos_valores', 'tem plano mensal'),
    ('planos_valores', 'valores dos planos'),
    ('planos_valores', 'mensalidade quanto e'),
    ('planos_valores', 'preco do anual'),
    ('planos_valores', 'quanto fica por mes'),
    ('planos_valores', 'o plano inclui aulas coletivas'),
    ('planos_valores', 'planos e precos'),
    ('planos_valores', 'plano mais em conta'),
    ('planos_valores', 'qual plano compensa mais'),

    -- matricula (21)
    ('matricula', 'como faco para me matricular'),
    ('matricula', 'quero me matricular'),
    ('matricula', 'como me inscrevo'),
    ('matricula', 'quero ser aluno'),
    ('matricula', 'quero entrar na academia'),
    ('matricula', 'como faco minha inscricao'),
    ('matricula', 'fazer matricula'),
    ('matricula', 'matricula online'),
    ('matricula', 'posso me matricular pelo whatsapp'),
    ('matricula', 'quais documentos preciso'),
    ('matricula', 'precisa de documento'),
    ('matricula', 'tem taxa de matricula'),
    ('matricula', 'quanto e a matricula'),
    ('matricula', 'valor da matricula'),
    ('matricula', 'precisa de atestado medico'),
    ('matricula', 'precisa de exame medico'),
    ('matricula', 'quero comecar a treinar'),
    ('matricula', 'como faco cadastro'),
    ('matricula', 'quero fechar um plano'),
    ('matricula', 'quero contratar'),
    ('matricula', 'matricula e gratis'),

    -- formas_pagamento (20)
    ('formas_pagamento', 'quais as formas de pagamento'),
    ('formas_pagamento', 'formas de pagamento'),
    ('formas_pagamento', 'como posso pagar'),
    ('formas_pagamento', 'aceita pix'),
    ('formas_pagamento', 'posso pagar no pix'),
    ('formas_pagamento', 'aceita cartao'),
    ('formas_pagamento', 'aceita cartao de credito'),
    ('formas_pagamento', 'aceita debito'),
    ('formas_pagamento', 'posso pagar em dinheiro'),
    ('formas_pagamento', 'aceita boleto'),
    ('formas_pagamento', 'da para parcelar'),
    ('formas_pagamento', 'parcela em quantas vezes'),
    ('formas_pagamento', 'parcelar o anual'),
    ('formas_pagamento', 'parcelamento sem juros'),
    ('formas_pagamento', 'pagamento recorrente'),
    ('formas_pagamento', 'debito automatico'),
    ('formas_pagamento', 'pagar no cartao'),
    ('formas_pagamento', 'chave pix'),
    ('formas_pagamento', 'pagamento a vista'),
    ('formas_pagamento', 'aceita vale alimentacao'),

    -- descontos_promocoes (18)
    ('descontos_promocoes', 'tem desconto'),
    ('descontos_promocoes', 'tem promocao'),
    ('descontos_promocoes', 'desconto para estudante'),
    ('descontos_promocoes', 'desconto universitario'),
    ('descontos_promocoes', 'desconto para familia'),
    ('descontos_promocoes', 'plano casal'),
    ('descontos_promocoes', 'plano familia'),
    ('descontos_promocoes', 'aceita gympass'),
    ('descontos_promocoes', 'aceita wellhub'),
    ('descontos_promocoes', 'aceita totalpass'),
    ('descontos_promocoes', 'tem convenio'),
    ('descontos_promocoes', 'desconto empresa'),
    ('descontos_promocoes', 'promocao de matricula'),
    ('descontos_promocoes', 'tem cupom'),
    ('descontos_promocoes', 'desconto a vista'),
    ('descontos_promocoes', 'posso levar um amigo'),
    ('descontos_promocoes', 'traga um amigo como funciona'),
    ('descontos_promocoes', 'black friday'),

    -- troca_plano (14)
    ('troca_plano', 'quero trocar de plano'),
    ('troca_plano', 'mudar de plano'),
    ('troca_plano', 'trocar o plano mensal pelo anual'),
    ('troca_plano', 'fazer upgrade do plano'),
    ('troca_plano', 'passar para o plano anual'),
    ('troca_plano', 'posso mudar meu plano'),
    ('troca_plano', 'como renovo meu plano'),
    ('troca_plano', 'renovar plano'),
    ('troca_plano', 'quero renovar'),
    ('troca_plano', 'trocar para trimestral'),
    ('troca_plano', 'diminuir meu plano'),
    ('troca_plano', 'mudar para um plano mais barato'),
    ('troca_plano', 'alterar plano'),
    ('troca_plano', 'meu plano vence quando'),

    -- pagamento_atrasado (17)
    ('pagamento_atrasado', 'mensalidade atrasada'),
    ('pagamento_atrasado', 'atrasei a mensalidade'),
    ('pagamento_atrasado', 'paguei atrasado'),
    ('pagamento_atrasado', 'estou devendo'),
    ('pagamento_atrasado', 'segunda via'),
    ('pagamento_atrasado', 'segunda via da mensalidade'),
    ('pagamento_atrasado', 'como pago mensalidade atrasada'),
    ('pagamento_atrasado', 'tem multa por atraso'),
    ('pagamento_atrasado', 'juros por atraso'),
    ('pagamento_atrasado', 'esqueci de pagar'),
    ('pagamento_atrasado', 'meu pagamento nao caiu'),
    ('pagamento_atrasado', 'fui bloqueado por falta de pagamento'),
    ('pagamento_atrasado', 'estou em debito com a academia'),
    ('pagamento_atrasado', 'regularizar pagamento'),
    ('pagamento_atrasado', 'quitar divida'),
    ('pagamento_atrasado', 'multa por atrasar'),
    ('pagamento_atrasado', 'atrasar a mensalidade'),

    -- cancelamento (17)
    ('cancelamento', 'quero cancelar'),
    ('cancelamento', 'quero cancelar minha matricula'),
    ('cancelamento', 'como cancelo o plano'),
    ('cancelamento', 'cancelar plano'),
    ('cancelamento', 'cancelamento'),
    ('cancelamento', 'quero sair da academia'),
    ('cancelamento', 'nao quero mais treinar'),
    ('cancelamento', 'quero desistir'),
    ('cancelamento', 'encerrar contrato'),
    ('cancelamento', 'tem multa para cancelar'),
    ('cancelamento', 'multa de cancelamento'),
    ('cancelamento', 'cancelar o anual'),
    ('cancelamento', 'cancelar pelo whatsapp'),
    ('cancelamento', 'quero dar baixa na matricula'),
    ('cancelamento', 'como faco o cancelamento'),
    ('cancelamento', 'rescindir contrato'),
    ('cancelamento', 'parar de pagar'),

    -- trancamento (18)
    ('trancamento', 'quero trancar'),
    ('trancamento', 'como tranco meu plano'),
    ('trancamento', 'trancar matricula'),
    ('trancamento', 'trancamento'),
    ('trancamento', 'quero pausar o plano'),
    ('trancamento', 'congelar plano'),
    ('trancamento', 'suspender o plano'),
    ('trancamento', 'vou viajar'),
    ('trancamento', 'vou viajar posso pausar'),
    ('trancamento', 'vou ficar um mes fora'),
    ('trancamento', 'ferias posso trancar'),
    ('trancamento', 'vou fazer cirurgia'),
    ('trancamento', 'estou lesionado'),
    ('trancamento', 'estou de atestado'),
    ('trancamento', 'licenca maternidade'),
    ('trancamento', 'pausar a academia'),
    ('trancamento', 'trancar por 30 dias'),
    ('trancamento', 'dias de trancamento'),

    -- personal_trainer (19)
    ('personal_trainer', 'tem personal'),
    ('personal_trainer', 'tem personal trainer'),
    ('personal_trainer', 'quero um personal'),
    ('personal_trainer', 'quero treinar com personal'),
    ('personal_trainer', 'quanto custa o personal'),
    ('personal_trainer', 'valor do personal'),
    ('personal_trainer', 'como contrato um personal'),
    ('personal_trainer', 'personal e incluso no plano'),
    ('personal_trainer', 'personal e separado da mensalidade'),
    ('personal_trainer', 'agendar personal'),
    ('personal_trainer', 'treino individual'),
    ('personal_trainer', 'professor particular'),
    ('personal_trainer', 'acompanhamento individual'),
    ('personal_trainer', 'treino personalizado'),
    ('personal_trainer', 'pacote de personal'),
    ('personal_trainer', 'personal para iniciante'),
    ('personal_trainer', 'posso trazer meu personal'),
    ('personal_trainer', 'levar personal de fora'),
    ('personal_trainer', 'personal externo'),

    -- avaliacao_fisica (14)
    ('avaliacao_fisica', 'tem avaliacao fisica'),
    ('avaliacao_fisica', 'como faco avaliacao fisica'),
    ('avaliacao_fisica', 'avaliacao fisica e gratis'),
    ('avaliacao_fisica', 'quanto custa a avaliacao'),
    ('avaliacao_fisica', 'agendar avaliacao'),
    ('avaliacao_fisica', 'quero fazer avaliacao'),
    ('avaliacao_fisica', 'reavaliacao fisica'),
    ('avaliacao_fisica', 'tem bioimpedancia'),
    ('avaliacao_fisica', 'medir percentual de gordura'),
    ('avaliacao_fisica', 'tirar medidas'),
    ('avaliacao_fisica', 'avaliacao postural'),
    ('avaliacao_fisica', 'avaliacao inicial'),
    ('avaliacao_fisica', 'quando posso me reavaliar'),
    ('avaliacao_fisica', 'fazer bioimpedancia'),

    -- aula_experimental (18)
    ('aula_experimental', 'tem aula experimental'),
    ('aula_experimental', 'aula gratis'),
    ('aula_experimental', 'primeira aula gratis'),
    ('aula_experimental', 'posso fazer uma aula teste'),
    ('aula_experimental', 'quero conhecer a academia'),
    ('aula_experimental', 'posso visitar a academia'),
    ('aula_experimental', 'quero testar antes'),
    ('aula_experimental', 'tem diaria'),
    ('aula_experimental', 'valor da diaria'),
    ('aula_experimental', 'treinar so um dia'),
    ('aula_experimental', 'day use'),
    ('aula_experimental', 'aula avulsa'),
    ('aula_experimental', 'experimentar a academia'),
    ('aula_experimental', 'fazer um treino teste'),
    ('aula_experimental', 'conhecer antes de fechar'),
    ('aula_experimental', 'preco da diaria'),
    ('aula_experimental', 'diaria quanto e'),
    ('aula_experimental', 'visita guiada'),

    -- aulas_modalidades (24)
    ('aulas_modalidades', 'quais modalidades voces tem'),
    ('aulas_modalidades', 'quais aulas tem'),
    ('aulas_modalidades', 'quais aulas coletivas'),
    ('aulas_modalidades', 'aulas coletivas'),
    ('aulas_modalidades', 'tem aula de spinning'),
    ('aulas_modalidades', 'tem spinning'),
    ('aulas_modalidades', 'tem yoga'),
    ('aulas_modalidades', 'tem aula de yoga'),
    ('aulas_modalidades', 'tem funcional'),
    ('aulas_modalidades', 'tem aula de danca'),
    ('aulas_modalidades', 'tem zumba'),
    ('aulas_modalidades', 'tem pilates'),
    ('aulas_modalidades', 'tem crossfit'),
    ('aulas_modalidades', 'tem luta'),
    ('aulas_modalidades', 'tem muay thai'),
    ('aulas_modalidades', 'tem natacao'),
    ('aulas_modalidades', 'tem piscina'),
    ('aulas_modalidades', 'tem musculacao'),
    ('aulas_modalidades', 'aula para iniciante'),
    ('aulas_modalidades', 'aulas estao inclusas no plano'),
    ('aulas_modalidades', 'aula coletiva e paga a parte'),
    ('aulas_modalidades', 'tem aula de bike'),
    ('aulas_modalidades', 'modalidades disponiveis'),
    ('aulas_modalidades', 'tem jiu jitsu'),

    -- horario_aulas (18)
    ('horario_aulas', 'horario das aulas'),
    ('horario_aulas', 'grade de aulas'),
    ('horario_aulas', 'grade de horarios das aulas'),
    ('horario_aulas', 'que horas tem spinning'),
    ('horario_aulas', 'horario do spinning'),
    ('horario_aulas', 'que dia tem yoga'),
    ('horario_aulas', 'horario da yoga'),
    ('horario_aulas', 'horario do funcional'),
    ('horario_aulas', 'que horas e o funcional'),
    ('horario_aulas', 'horario da aula de danca'),
    ('horario_aulas', 'aula de danca que dia'),
    ('horario_aulas', 'tem aula a noite'),
    ('horario_aulas', 'tem aula de manha'),
    ('horario_aulas', 'tem aula no sabado'),
    ('horario_aulas', 'aulas de sabado'),
    ('horario_aulas', 'precisa agendar aula coletiva'),
    ('horario_aulas', 'quantas vezes por semana tem spinning'),
    ('horario_aulas', 'dias das aulas')
) AS v(codigo, texto)
JOIN intents i ON i.codigo = v.codigo;

-- =========================================================
-- DADOS: CASOS DE TESTE
-- =========================================================

INSERT INTO test_cases (pergunta, intent_esperada, tipo) VALUES
    ('Olá, boa tarde!', 'saudacao', 'padrao'),
    ('Oi, tudo bem com você?', 'saudacao', 'padrao'),
    ('E aí, beleza?', 'saudacao', 'variacao'),
    ('Bom diaaa', 'saudacao', 'dificil'),
    ('Opa, boa noite', 'saudacao', 'variacao'),
    ('Tchau, até mais!', 'despedida', 'padrao'),
    ('Até amanhã', 'despedida', 'padrao'),
    ('Falou, até a próxima', 'despedida', 'variacao'),
    ('Era só isso, tchau', 'despedida', 'variacao'),
    ('Muito obrigado pela ajuda!', 'agradecimento', 'padrao'),
    ('Valeu demais', 'agradecimento', 'variacao'),
    ('Obrigada, ajudou bastante', 'agradecimento', 'padrao'),
    ('Show, valeu!', 'agradecimento', 'variacao'),
    ('Você é um robô?', 'sobre_bot', 'padrao'),
    ('Estou conversando com uma inteligência artificial?', 'sobre_bot', 'padrao'),
    ('Qual é o seu nome?', 'sobre_bot', 'padrao'),
    ('Isso aqui é resposta automática?', 'sobre_bot', 'variacao'),
    ('Quero falar com um atendente', 'atendimento_humano', 'padrao'),
    ('Me transfere pra uma pessoa de verdade', 'atendimento_humano', 'variacao'),
    ('Posso falar com o gerente?', 'atendimento_humano', 'padrao'),
    ('Preciso falar com alguém da recepção', 'atendimento_humano', 'variacao'),
    ('Quero registrar uma reclamação', 'reclamacao_sugestao', 'padrao'),
    ('A esteira 3 está quebrada faz uma semana', 'reclamacao_sugestao', 'variacao'),
    ('O vestiário masculino estava muito sujo hoje', 'reclamacao_sugestao', 'variacao'),
    ('Tenho uma sugestão para a academia', 'reclamacao_sugestao', 'padrao'),
    ('O ar-condicionado não está funcionando', 'reclamacao_sugestao', 'dificil'),
    ('Qual o horário de funcionamento?', 'horario_funcionamento', 'padrao'),
    ('Que horas vocês abrem?', 'horario_funcionamento', 'padrao'),
    ('Vocês abrem no domingo?', 'horario_funcionamento', 'padrao'),
    ('Até que horas posso treinar na sexta?', 'horario_funcionamento', 'variacao'),
    ('Funciona em feriado?', 'horario_funcionamento', 'padrao'),
    ('A academia está aberta agora?', 'horario_funcionamento', 'variacao'),
    ('Qual o orario de sabado', 'horario_funcionamento', 'dificil'),
    ('Onde fica a academia?', 'endereco_localizacao', 'padrao'),
    ('Qual é o endereço de vocês?', 'endereco_localizacao', 'padrao'),
    ('Como faço para chegar aí?', 'endereco_localizacao', 'variacao'),
    ('Vocês ficam em qual bairro?', 'endereco_localizacao', 'padrao'),
    ('Fica perto da Unisul Pedra Branca?', 'endereco_localizacao', 'variacao'),
    ('Me manda a localização', 'endereco_localizacao', 'padrao'),
    ('Qual o telefone da academia?', 'contato', 'padrao'),
    ('Vocês têm WhatsApp?', 'contato', 'padrao'),
    ('Me passa o número do zap', 'contato', 'variacao'),
    ('Qual o e-mail para contato?', 'contato', 'padrao'),
    ('Vocês tem Instagram?', 'contato', 'variacao'),
    ('Tem estacionamento?', 'estacionamento', 'padrao'),
    ('Onde eu deixo o carro?', 'estacionamento', 'variacao'),
    ('O estacionamento é pago?', 'estacionamento', 'padrao'),
    ('Tem lugar para deixar a bike?', 'estacionamento', 'dificil'),
    ('Tem chuveiro no vestiário?', 'estrutura', 'padrao'),
    ('Preciso levar cadeado para o armário?', 'estrutura', 'padrao'),
    ('A academia tem wi-fi?', 'estrutura', 'padrao'),
    ('Tem acesso para cadeirante?', 'estrutura', 'padrao'),
    ('Os aparelhos são novos?', 'estrutura', 'variacao'),
    ('Tem ar condicionado?', 'estrutura', 'dificil'),
    ('Como funciona a entrada na academia?', 'acesso_academia', 'padrao'),
    ('A catraca não liberou minha entrada', 'acesso_academia', 'padrao'),
    ('Minha digital não está passando', 'acesso_academia', 'variacao'),
    ('Esqueci minha carteirinha, consigo entrar?', 'acesso_academia', 'variacao'),
    ('Qual a idade mínima para treinar?', 'idade_minima', 'padrao'),
    ('Meu filho tem 15 anos, ele pode malhar?', 'idade_minima', 'variacao'),
    ('Menor de idade precisa de autorização?', 'idade_minima', 'padrao'),
    ('Idoso pode fazer academia aí?', 'idade_minima', 'variacao'),
    ('Quais são os planos?', 'planos_valores', 'padrao'),
    ('Quanto custa a mensalidade?', 'planos_valores', 'padrao'),
    ('Qual o valor do plano anual?', 'planos_valores', 'padrao'),
    ('Qual plano sai mais em conta?', 'planos_valores', 'variacao'),
    ('O plano mensal tem fidelidade?', 'planos_valores', 'variacao'),
    ('Quanto fica o trimestral por mês?', 'planos_valores', 'padrao'),
    ('qnto custa', 'planos_valores', 'dificil'),
    ('Como faço para me matricular?', 'matricula', 'padrao'),
    ('Quais documentos eu preciso levar?', 'matricula', 'padrao'),
    ('Tem taxa de matrícula?', 'matricula', 'padrao'),
    ('Precisa de atestado médico?', 'matricula', 'padrao'),
    ('Quero começar a treinar, o que faço?', 'matricula', 'variacao'),
    ('Dá pra fazer a matrícula pelo WhatsApp?', 'matricula', 'dificil'),
    ('Quais as formas de pagamento?', 'formas_pagamento', 'padrao'),
    ('Aceita Pix?', 'formas_pagamento', 'padrao'),
    ('Posso pagar no cartão de crédito?', 'formas_pagamento', 'padrao'),
    ('Dá pra parcelar o plano anual?', 'formas_pagamento', 'variacao'),
    ('Vocês aceitam boleto?', 'formas_pagamento', 'padrao'),
    ('Posso pagar em dinheiro na recepção?', 'formas_pagamento', 'variacao'),
    ('Tem desconto para estudante?', 'descontos_promocoes', 'padrao'),
    ('Vocês aceitam Gympass?', 'descontos_promocoes', 'padrao'),
    ('Tem alguma promoção agora?', 'descontos_promocoes', 'padrao'),
    ('Tem plano para casal?', 'descontos_promocoes', 'variacao'),
    ('Aceita TotalPass?', 'descontos_promocoes', 'padrao'),
    ('Quero trocar meu plano mensal pelo anual', 'troca_plano', 'padrao'),
    ('Como faço para renovar meu plano?', 'troca_plano', 'padrao'),
    ('Posso fazer upgrade do meu plano?', 'troca_plano', 'padrao'),
    ('Não quero renovar meu plano', 'cancelamento', 'dificil'),
    ('Minha mensalidade está atrasada, o que faço?', 'pagamento_atrasado', 'padrao'),
    ('Preciso da segunda via', 'pagamento_atrasado', 'padrao'),
    ('Tem multa se eu atrasar?', 'pagamento_atrasado', 'variacao'),
    ('Esqueci de pagar esse mês', 'pagamento_atrasado', 'padrao'),
    ('Quero cancelar meu plano', 'cancelamento', 'padrao'),
    ('Como faço o cancelamento?', 'cancelamento', 'padrao'),
    ('Tem multa para cancelar o anual?', 'cancelamento', 'variacao'),
    ('Não quero mais ser aluno', 'cancelamento', 'dificil'),
    ('Quero sair da academia', 'cancelamento', 'padrao'),
    ('Quero trancar minha matrícula', 'trancamento', 'padrao'),
    ('Vou viajar por um mês, posso pausar o plano?', 'trancamento', 'variacao'),
    ('Dá pra congelar o plano?', 'trancamento', 'padrao'),
    ('Vou fazer uma cirurgia, como fica meu plano?', 'trancamento', 'dificil'),
    ('Quantos dias posso trancar?', 'trancamento', 'padrao'),
    ('Vocês têm personal trainer?', 'personal_trainer', 'padrao'),
    ('Quanto custa o personal?', 'personal_trainer', 'padrao'),
    ('O personal está incluso na mensalidade?', 'personal_trainer', 'variacao'),
    ('Quero treino individual com um professor', 'personal_trainer', 'variacao'),
    ('Posso levar meu próprio personal?', 'personal_trainer', 'dificil'),
    ('Vocês fazem avaliação física?', 'avaliacao_fisica', 'padrao'),
    ('A avaliação física é paga?', 'avaliacao_fisica', 'padrao'),
    ('Quero fazer bioimpedância', 'avaliacao_fisica', 'padrao'),
    ('Quando posso fazer reavaliação?', 'avaliacao_fisica', 'variacao'),
    ('Tem aula experimental?', 'aula_experimental', 'padrao'),
    ('Posso fazer uma aula grátis antes?', 'aula_experimental', 'padrao'),
    ('Quanto custa a diária?', 'aula_experimental', 'padrao'),
    ('Quero conhecer a academia antes de fechar', 'aula_experimental', 'variacao'),
    ('Quais modalidades vocês têm?', 'aulas_modalidades', 'padrao'),
    ('Tem aula de yoga?', 'aulas_modalidades', 'padrao'),
    ('Vocês têm pilates?', 'aulas_modalidades', 'padrao'),
    ('Tem crossfit aí?', 'aulas_modalidades', 'variacao'),
    ('As aulas coletivas estão inclusas no plano?', 'aulas_modalidades', 'variacao'),
    ('Tem natação?', 'aulas_modalidades', 'padrao'),
    ('Qual o horário das aulas?', 'horario_aulas', 'padrao'),
    ('Que horas tem spinning?', 'horario_aulas', 'padrao'),
    ('Que dia tem aula de dança?', 'horario_aulas', 'padrao'),
    ('Tem aula de funcional à noite?', 'horario_aulas', 'dificil'),
    ('Qual a grade de aulas de sábado?', 'horario_aulas', 'variacao'),
    ('Qual a capital da França?', NULL, 'fora_escopo'),
    ('Quem ganhou o jogo ontem?', NULL, 'fora_escopo'),
    ('Me conta uma piada', NULL, 'fora_escopo'),
    ('Qual a previsão do tempo amanhã?', NULL, 'fora_escopo'),
    ('Quanto está o dólar hoje?', NULL, 'fora_escopo'),
    ('Me indica um filme', NULL, 'fora_escopo'),
    ('Qual a melhor dieta para emagrecer?', NULL, 'fora_escopo'),
    ('Vocês vendem whey protein?', NULL, 'fora_escopo'),
    ('Tem nutricionista?', NULL, 'fora_escopo'),
    ('asdfghjkl', NULL, 'fora_escopo'),
    ('Qual a raiz quadrada de 144?', NULL, 'fora_escopo'),
    ('Pode me ajudar com meu trabalho da faculdade?', NULL, 'fora_escopo'),
    ('Quero pedir uma pizza', NULL, 'fora_escopo'),
    ('Como faço para trocar o pneu do carro?', NULL, 'fora_escopo'),
    ('?', NULL, 'fora_escopo');

COMMIT;
