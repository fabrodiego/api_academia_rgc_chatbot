-- Banco do chatbot Academia RGC Training
-- Uso: psql -d academia_rgc_chatbot -v ON_ERROR_STOP=1 -f sql/banco.sql
-- Cria as tabelas se não existirem e SUBSTITUI todos os dados (as tabelas e
-- as permissões continuam). Roda em uma transação: se der erro, nada é gravado.
-- ATENÇÃO: o TRUNCATE abaixo também apaga as conversas. Em produção, prefira
-- scripts incrementais (só INSERT/UPDATE).
-- Base: 43 intents, 85 respostas, 1273 frases de treino, 143 casos de teste.

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
    ('horario_aulas', 'servicos', 'Grade de horários das aulas coletivas'),
    ('comparar_planos', 'comercial', 'Comparação entre planos: diferenças, qual compensa mais, economia'),
    ('documentos_matricula', 'comercial', 'Documentos necessários para se matricular'),
    ('plano_mensal', 'comercial', 'Pergunta específica sobre o plano Mensal (valor, fidelidade, o que inclui)'),
    ('plano_anual', 'comercial', 'Pergunta específica sobre o plano Anual (menor valor mensal, matrícula grátis)'),
    ('taxa_matricula', 'comercial', 'Taxa/valor da matrícula e isenção no plano Anual'),
    ('plano_trimestral', 'comercial', 'Pergunta específica sobre o plano Trimestral (valor, benefícios, traga um amigo)'),
    ('fora_escopo', 'suporte', 'Assuntos sem relação com a academia (clima, futebol, piadas, contas, comida etc.). Redireciona para os temas da RGC'),
    ('aula_kids', 'operacional', 'Aula RGC Kids (crianças): objetivo e duração; faixa etária e turmas via recepção'),
    ('aula_danca', 'operacional', 'Aula FitDance (dança): objetivo, duração e benefícios'),
    ('aula_yoga', 'operacional', 'Aula de Yoga: objetivo, duração e benefícios'),
    ('aula_muay_thai', 'operacional', 'Aula de Muay Thai: objetivo, duração e benefícios'),
    ('aula_boxe', 'operacional', 'Aula de Boxe: objetivo, duração e benefícios'),
    ('aula_lutas', 'operacional', 'Pergunta genérica sobre aulas de luta/artes marciais/defesa pessoal (Boxe e Muay Thai)'),
    ('modalidades_nao_oferecidas', 'operacional', 'Modalidades que a RGC não oferece (pilates, crossfit, natação)'),
    ('aula_bike', 'operacional', 'Aula RGC Bike (bike/spinning): objetivo, duração e benefícios'),
    ('equipamentos', 'operacional', 'Equipamentos e aparelhos: renovação, manutenção e fila em horário de pico'),
    ('horario_fim_semana_feriado', 'operacional', 'Horário aos sábados, domingos e feriados');

-- =========================================================
-- DADOS: RESPOSTAS DO BOT (ligadas pelo código da intent)
-- =========================================================

INSERT INTO bot_responses (intent_id, texto)
SELECT i.id, v.texto
FROM (VALUES

    -- saudacao (3)
    (1, 'saudacao', 'Olá, tudo bem? Aqui é o assistente da RGC Training. Pode perguntar sobre planos, horários, modalidades, pagamento ou matrícula.'),
    (2, 'saudacao', 'Oi! Que bom ter você aqui na RGC Training. Me conta: o que você quer saber? Horários, planos, aulas, endereço…'),
    (3, 'saudacao', 'Olá! Sou o assistente virtual da Academia RGC Training. Posso ajudar com horários, planos, pagamento, aulas, personal, matrícula e muito mais. Como posso ajudar?'),

    -- despedida (3)
    (4, 'despedida', 'Até logo! Qualquer dúvida, estamos por aqui.'),
    (5, 'despedida', 'Tchau! Se precisar de algo, é só chamar aqui no chat.'),
    (6, 'despedida', 'Até mais! Bom treino e conte com a RGC Training. 💪'),

    -- agradecimento (3)
    (7, 'agradecimento', 'Imagina! Qualquer coisa, é só chamar.'),
    (8, 'agradecimento', 'Disponha! Estamos aqui para ajudar no que precisar.'),
    (9, 'agradecimento', 'Por nada! Fico feliz em ajudar. Se tiver mais alguma dúvida, é só perguntar.'),

    -- sobre_bot (2)
    (10, 'sobre_bot', 'Eu sou um chatbot, um assistente automático da RGC Training. Respondo dúvidas sobre a academia a qualquer hora. Para casos mais específicos, chamo a equipe humana.'),
    (11, 'sobre_bot', 'Sou o assistente virtual da RGC Training. Eu entendo a sua pergunta comparando com exemplos que aprendi (PLN com TF-IDF). Se eu não souber responder, encaminho para um atendente humano.'),

    -- atendimento_humano (1)
    (12, 'atendimento_humano', 'Claro! Para falar com uma pessoa da equipe, chame no WhatsApp (48) 4002-8922, ligue no mesmo número ou passe na recepção. Atendemos no horário de funcionamento da academia.'),

    -- reclamacao_sugestao (2)
    (13, 'reclamacao_sugestao', 'Obrigado por avisar. Registre sua reclamação ou sugestão pelo e-mail contato@rgctraining.com ou na recepção, para a gerência analisar. Respondemos em até 2 dias úteis.'),
    (14, 'reclamacao_sugestao', 'Sentimos muito pelo problema. Sua opinião é importante: envie a reclamação ou sugestão para contato@rgctraining.com ou fale com a recepção. A equipe responde em até 2 dias úteis.'),

    -- horario_funcionamento (1)
    (15, 'horario_funcionamento', 'A Academia RGC Training funciona de segunda a sexta das 6h às 22h e aos sábados das 8h às 14h. Domingos e feriados a academia fica fechada.'),

    -- endereco_localizacao (1)
    (16, 'endereco_localizacao', 'Estamos na Av. Pedra Branca, 25 - Cidade Universitária, Palhoça - SC, CEP 88137-270. No site tem o mapa com a localização.'),

    -- contato (1)
    (17, 'contato', 'Você pode falar com a gente pelo telefone/WhatsApp (48) 4002-8922 ou pelo e-mail contato@rgctraining.com.'),

    -- estacionamento (1)
    (18, 'estacionamento', 'Temos estacionamento próprio gratuito para alunos, com 30 vagas para carro, vagas para moto e bicicletário.'),

    -- estrutura (1)
    (19, 'estrutura', 'A RGC tem vestiários masculino e feminino com chuveiro quente, armários de uso diário (traga seu cadeado), bebedouros, wi-fi gratuito e ar-condicionado. Os equipamentos são novos, com manutenção semanal, e temos rampa e banheiro adaptado.'),

    -- acesso_academia (1)
    (20, 'acesso_academia', 'A entrada é feita por biometria (digital) na catraca. O cadastro da digital é feito na recepção no dia da matrícula. Se a catraca não liberar, procure a recepção.'),

    -- idade_minima (1)
    (21, 'idade_minima', 'Na musculação aceitamos alunos a partir de 14 anos. Menores de 18 precisam de autorização assinada pelo responsável na matrícula. A aula RGC Kids é voltada ao público infantil: pergunte na recepção sobre a faixa etária. Não há idade máxima: idosos são muito bem-vindos.'),

    -- planos_valores (1)
    (22, 'planos_valores', 'Temos 3 planos, todos com musculação e aulas coletivas:
• Mensal: R$ 129/mês, sem fidelidade.
• Trimestral: R$ 109/mês, com 1 reavaliação física e "traga um amigo" 2x por mês.
• Anual: R$ 89/mês, com tudo do Trimestral e matrícula grátis.
Matrícula: R$ 59 nos planos Mensal e Trimestral.'),

    -- matricula (1)
    (23, 'matricula', 'Para se matricular, venha à recepção com documento com foto e CPF, ou comece pelo WhatsApp (48) 4002-8922. A taxa de matrícula é R$ 59 nos planos Mensal e Trimestral e grátis no Anual. Atestado médico não é obrigatório, mas recomendamos.'),

    -- formas_pagamento (1)
    (24, 'formas_pagamento', 'Aceitamos Pix, cartão de crédito, cartão de débito e dinheiro na recepção. O plano Mensal pode ser cobrado no cartão de crédito recorrente. Trimestral e Anual podem ser parcelados no cartão de crédito sem juros (até 3x e 12x). Não trabalhamos com boleto.'),

    -- descontos_promocoes (1)
    (25, 'descontos_promocoes', 'No momento não temos desconto para estudante, família ou convênio, e não aceitamos Wellhub (Gympass) nem TotalPass. O melhor custo é o plano Anual (R$ 89/mês, matrícula grátis). No Trimestral você pode trazer um amigo 2x por mês.'),

    -- troca_plano (1)
    (26, 'troca_plano', 'Você pode trocar para um plano maior (upgrade) a qualquer momento na recepção, pagando só a diferença proporcional. A troca para um plano menor é feita na renovação.'),

    -- pagamento_atrasado (1)
    (27, 'pagamento_atrasado', 'Se a mensalidade estiver atrasada, o acesso na catraca fica bloqueado até o pagamento. Você pode quitar na recepção ou pedir o Pix pelo WhatsApp (48) 4002-8922. Atraso tem multa de 2% mais juros de 1% ao mês.'),

    -- cancelamento (1)
    (28, 'cancelamento', 'Para cancelar, faça o pedido na recepção com documento ou pelo e-mail contato@rgctraining.com. No plano Mensal não há multa. No Trimestral e no Anual a multa é de 10% sobre as mensalidades restantes.'),

    -- trancamento (1)
    (29, 'trancamento', 'O trancamento é um benefício do plano Anual: até 30 dias por ano, pedido na recepção com 7 dias de antecedência. Em qualquer plano, com atestado médico, o plano pode ser congelado pelo período do atestado.'),

    -- personal_trainer (1)
    (30, 'personal_trainer', 'Temos personal trainers credenciados, com atendimento sob agendamento. O valor é combinado direto com o profissional e é separado da mensalidade. Agende na recepção ou pelo WhatsApp (48) 4002-8922.'),

    -- avaliacao_fisica (1)
    (31, 'avaliacao_fisica', 'A avaliação física inicial é gratuita em todos os planos e inclui bioimpedância, medidas e teste postural. O plano Trimestral inclui 1 reavaliação. Avaliação avulsa custa R$ 40. Agende na recepção.'),

    -- aula_experimental (1)
    (32, 'aula_experimental', 'A primeira aula é grátis! Agende pelo WhatsApp (48) 4002-8922 ou na recepção e traga um documento com foto. Se quiser treinar só um dia, a diária avulsa custa R$ 30.'),

    -- aulas_modalidades (1)
    (33, 'aulas_modalidades', 'Oferecemos musculação livre e seis aulas coletivas: RGC Bike, FitDance, RGC Kids, Boxe, Muay Thai e Yoga, com turmas pequenas e para todos os níveis. Todas estão incluídas em qualquer plano. No momento não temos pilates, crossfit nem natação.'),

    -- horario_aulas (1)
    (34, 'horario_aulas', 'Os horários das turmas (RGC Bike, FitDance, RGC Kids, Boxe, Muay Thai e Yoga) ficam na recepção. Para saber a grade atual, passe por lá ou chame no WhatsApp (48) 4002-8922. As vagas são por ordem de chegada.'),

    -- comparar_planos (3)
    (35, 'comparar_planos', 'Quanto maior o plano, menos você paga por mês: do Mensal para o Trimestral são R$ 20 a menos por mês, e do Mensal para o Anual, R$ 40 a menos, além da matrícula grátis. Quer ajuda para escolher? Chame no WhatsApp (48) 4002-8922.'),
    (36, 'comparar_planos', 'Diferenças entre os planos:
• Mensal (R$ 129): musculação, aulas coletivas e avaliação física inicial, sem fidelidade
• Trimestral (R$ 109): tudo do Mensal + 1 reavaliação física + traga um amigo 2x por mês
• Anual (R$ 89): tudo do Trimestral + matrícula grátis
A matrícula é R$ 59 no Mensal e no Trimestral.'),
    (37, 'comparar_planos', 'Resumo dos planos (valores por mês):
• Mensal: R$ 129, sem fidelidade
• Trimestral: R$ 109, o mais escolhido
• Anual: R$ 89, menor valor mensal e matrícula grátis
Todos incluem musculação e aulas coletivas. Quanto maior o plano, menor a mensalidade.'),

    -- documentos_matricula (3)
    (38, 'documentos_matricula', 'Pronto para começar? Basta levar um documento com foto à recepção e escolher o seu plano: Mensal (R$ 129), Trimestral (R$ 109) ou Anual (R$ 89) por mês. Tire dúvidas antes pelo WhatsApp (48) 4002-8922.'),
    (39, 'documentos_matricula', 'Para a matrícula:
• Leve um documento com foto
• Vá até a recepção: Av. Pedra Branca, 25 - Cidade Universitária, Palhoça - SC
• Funcionamos de segunda a sexta das 6h às 22h e aos sábados das 8h às 14h
Dúvidas? Chame no WhatsApp (48) 4002-8922.'),
    (40, 'documentos_matricula', 'Para se matricular, vá até a recepção com um documento com foto. Se preferir, fale antes com um consultor pelo WhatsApp (48) 4002-8922. Estamos na Av. Pedra Branca, 25 - Cidade Universitária, Palhoça - SC.'),

    -- plano_mensal (3)
    (41, 'plano_mensal', 'O Mensal é ideal para começar sem compromisso: R$ 129/mês, sem fidelidade, com musculação, aulas coletivas e avaliação física. Quer se matricular? Passe na recepção ou chame no WhatsApp (48) 4002-8922.'),
    (42, 'plano_mensal', 'Plano Mensal da RGC:
• R$ 129 por mês, sem fidelidade
• Musculação livre
• Aulas coletivas (Bike, FitDance, Kids, Boxe, Muay Thai e Yoga)
• Avaliação física inicial
A matrícula nesse plano é de R$ 59.'),
    (43, 'plano_mensal', 'O plano Mensal custa R$ 129 por mês e é sem fidelidade: você treina sem se prender a um contrato longo. Inclui musculação livre, aulas coletivas e avaliação física inicial.'),

    -- plano_anual (3)
    (44, 'plano_anual', 'Quer economizar? No Anual você paga R$ 89 por mês e não paga matrícula. É o melhor custo-benefício da RGC. Para fechar, passe na recepção ou chame no WhatsApp (48) 4002-8922.'),
    (45, 'plano_anual', 'Plano Anual da RGC:
• R$ 89 por mês (o menor valor mensal)
• Matrícula grátis
• Tudo do plano Trimestral: musculação livre, aulas coletivas, avaliação e reavaliação física e traga um amigo 2x por mês'),
    (46, 'plano_anual', 'O plano Anual tem o menor preço por mês: R$ 89/mês. Inclui tudo do plano Trimestral e a matrícula é grátis. É o melhor custo-benefício da RGC.'),

    -- taxa_matricula (3)
    (47, 'taxa_matricula', 'Quer não pagar matrícula? No plano Anual ela é grátis (R$ 89/mês). Nos planos Mensal e Trimestral a taxa é de R$ 59. Para se matricular, passe na recepção ou chame no WhatsApp (48) 4002-8922.'),
    (48, 'taxa_matricula', 'Taxa de matrícula na RGC:
• Plano Mensal: R$ 59
• Plano Trimestral: R$ 59
• Plano Anual: grátis
O valor da matrícula é à parte da mensalidade: Mensal R$ 129, Trimestral R$ 109 e Anual R$ 89 por mês.'),
    (49, 'taxa_matricula', 'A taxa de matrícula é de R$ 59 nos planos Mensal e Trimestral. No plano Anual a matrícula é grátis, então vale comparar qual plano combina mais com você.'),

    -- plano_trimestral (3)
    (50, 'plano_trimestral', 'O Trimestral é o plano mais escolhido: R$ 109/mês, com reavaliação física e 2 visitas de amigo por mês. Quer fechar o seu? Passe na recepção ou chame no WhatsApp (48) 4002-8922.'),
    (51, 'plano_trimestral', 'Plano Trimestral da RGC:
• R$ 109 por mês
• Tudo do plano Mensal (musculação livre, aulas coletivas e avaliação física inicial)
• 1 reavaliação física
• Traga um amigo 2x por mês
A matrícula nesse plano é de R$ 59.'),
    (52, 'plano_trimestral', 'O plano Trimestral custa R$ 109 por mês e é o mais escolhido. Inclui tudo do plano Mensal, mais 1 reavaliação física e o benefício de trazer um amigo 2 vezes por mês.'),

    -- fora_escopo (3)
    (53, 'fora_escopo', 'Não consigo ajudar com isso por aqui, mas se quiser saber dos nossos planos, horários, aulas ou matrícula, é comigo mesmo. Se preferir falar com a equipe, chame no WhatsApp (48) 4002-8922.'),
    (54, 'fora_escopo', 'Esse assunto foge do que eu sei responder. Posso te ajudar com informações da academia, como horário de funcionamento, valores dos planos, aulas e modalidades ou como se matricular. É só perguntar!'),
    (55, 'fora_escopo', 'Sou o assistente virtual da RGC Training e só consigo ajudar com assuntos da academia: horários, planos, matrícula, aulas, personal trainer e cancelamento. O que você gostaria de saber?'),

    -- aula_kids (3)
    (56, 'aula_kids', 'Quer que seu filho aprenda a gostar de se mexer? A RGC Kids tem 40 minutos de atividade com foco em postura, equilíbrio e socialização. Para detalhes de idade e turmas, passe na recepção ou chame no WhatsApp (48) 4002-8922.'),
    (57, 'aula_kids', 'RGC Kids (40 min):
• Objetivo: fortalecimento muscular e hábito de movimento
• Fortalece músculos e ossos
• Desenvolve postura e equilíbrio
• Estimula disciplina e socialização
Sobre idade e horários, fale com a recepção ou chame no WhatsApp (48) 4002-8922.'),
    (58, 'aula_kids', 'A RGC Kids é uma aula de 40 minutos para fortalecer músculos e ossos, desenvolver postura e equilíbrio e estimular disciplina e socialização. Para faixa etária e horários das turmas, fale com a recepção.'),

    -- aula_danca (3)
    (59, 'aula_danca', 'Quer treinar se divertindo? A FitDance tem 50 minutos de dança, gasto de calorias e muito bom humor, e está incluída no plano. Os horários das turmas ficam na recepção, é só passar por lá.'),
    (60, 'aula_danca', 'FitDance (50 min):
• Objetivo: emagrecimento com diversão
• Trabalha o corpo todo ao ritmo da música
• Melhora a coordenação motora
• Ajuda a aliviar o estresse
Os horários das turmas ficam na recepção.'),
    (61, 'aula_danca', 'A FitDance é uma aula de dança de 50 minutos pensada para emagrecer com diversão. Trabalha o corpo todo ao ritmo da música, melhora a coordenação motora e ajuda a aliviar o estresse. Está incluída no plano.'),

    -- aula_yoga (3)
    (62, 'aula_yoga', 'Precisa desacelerar? A aula de Yoga tem 60 minutos para ganhar flexibilidade, melhorar a postura e dormir melhor, e está incluída no plano. Os horários das turmas ficam na recepção, é só passar por lá.'),
    (63, 'aula_yoga', 'Yoga na RGC (60 min):
• Objetivo: flexibilidade, equilíbrio e relaxamento
• Aumenta a flexibilidade e a mobilidade
• Melhora a postura e a respiração
• Reduz o estresse e melhora o sono
Os horários das turmas ficam na recepção.'),
    (64, 'aula_yoga', 'A aula de Yoga dura 60 minutos e trabalha flexibilidade, equilíbrio e relaxamento. Aumenta a mobilidade, melhora a postura e a respiração, reduz o estresse e ajuda a dormir melhor. Está incluída no plano.'),

    -- aula_muay_thai (3)
    (65, 'aula_muay_thai', 'Quer ganhar força e confiança? O Muay Thai tem 60 minutos de treino com autodefesa e alto gasto calórico, e a aula está incluída no plano. Os horários das turmas ficam na recepção, é só passar por lá.'),
    (66, 'aula_muay_thai', 'Muay Thai na RGC (60 min):
• Objetivo: força, potência e autodefesa
• Fortalece pernas e core
• Aumenta o gasto calórico
• Desenvolve disciplina e confiança
Os horários das turmas ficam na recepção.'),
    (67, 'aula_muay_thai', 'A aula de Muay Thai dura 60 minutos e trabalha força, potência e autodefesa. Fortalece pernas e core, aumenta o gasto calórico e desenvolve disciplina e confiança. Está incluída no plano.'),

    -- aula_boxe (3)
    (68, 'aula_boxe', 'Com raiva do trânsito ou do chefe? Venha descarregar no Boxe: 60 minutos de treino para ganhar resistência, agilidade e definição muscular, com a aula incluída no plano. Os horários das turmas ficam na recepção.'),
    (69, 'aula_boxe', 'Boxe na RGC (60 min):
• Objetivo: condicionamento físico e definição muscular
• Melhora a resistência e a agilidade
• Tonifica braços, ombros e abdômen
• Descarrega a tensão do dia
Os horários das turmas ficam na recepção.'),
    (70, 'aula_boxe', 'A aula de Boxe dura 60 minutos e trabalha condicionamento físico e definição muscular. Melhora a resistência e a agilidade, tonifica braços, ombros e abdômen e ajuda a descarregar a tensão do dia. Está incluída no plano.'),

    -- aula_lutas (3)
    (71, 'aula_lutas', 'Quer aprender uma luta? Escolha entre Boxe e Muay Thai, ambas de 60 minutos e incluídas no plano. Os horários das turmas ficam na recepção, ou chame no WhatsApp (48) 4002-8922.'),
    (72, 'aula_lutas', 'Aulas de luta na RGC:
• Boxe (60 min): condicionamento físico, resistência e agilidade
• Muay Thai (60 min): força, potência e autodefesa
Os horários das turmas ficam na recepção.'),
    (73, 'aula_lutas', 'Temos duas aulas de luta: Boxe (60 min), para condicionamento e definição muscular, e Muay Thai (60 min), para força, potência e autodefesa. As duas estão incluídas no plano.'),

    -- modalidades_nao_oferecidas (3)
    (74, 'modalidades_nao_oferecidas', 'Essa modalidade não faz parte da RGC, mas temos seis aulas coletivas: Bike, FitDance, Kids, Boxe, Muay Thai e Yoga, além da musculação livre. Quer saber de alguma delas? Pergunte aqui ou chame no WhatsApp (48) 4002-8922.'),
    (75, 'modalidades_nao_oferecidas', 'Não temos pilates, crossfit nem natação. O que oferecemos:
• Musculação livre
• RGC Bike
• FitDance
• RGC Kids
• Boxe
• Muay Thai
• Yoga
Todas as aulas estão incluídas no plano.'),
    (76, 'modalidades_nao_oferecidas', 'Pilates, CrossFit e natação não fazem parte das nossas modalidades. Hoje temos musculação livre e as aulas RGC Bike, FitDance, RGC Kids, Boxe, Muay Thai e Yoga, todas incluídas no plano.'),

    -- aula_bike (3)
    (77, 'aula_bike', 'Quer queimar calorias sem judiar das articulações? Venha para a RGC Bike, aula de 45 minutos incluída no plano. Os horários das turmas ficam na recepção, é só passar por lá e escolher o seu.'),
    (78, 'aula_bike', 'RGC Bike (45 min):
• Objetivo: condicionamento cardiovascular e queima calórica
• Melhora o fôlego e a resistência
• Alto gasto de calorias
• Baixo impacto nas articulações
Os horários das turmas ficam na recepção.'),
    (79, 'aula_bike', 'A RGC Bike é uma aula de 45 minutos focada em condicionamento cardiovascular e queima calórica. Melhora o fôlego e a resistência, tem alto gasto de calorias e baixo impacto nas articulações. Está incluída no plano.'),

    -- equipamentos (3)
    (80, 'equipamentos', 'Máquinas renovadas, manutenção toda semana e sem fila no horário de pico: é isso que você encontra na RGC Training. Quer conhecer? Passe na recepção (Av. Pedra Branca, 25 - Cidade Universitária, Palhoça - SC) ou chame no WhatsApp (48) 4002-8922.'),
    (81, 'equipamentos', 'Sobre os equipamentos da RGC:
• Máquinas renovadas
• Manutenção semanal
• Sem fila nos horários de pico
A musculação é livre e está incluída em todos os planos.'),
    (82, 'equipamentos', 'Nossos equipamentos são novos: as máquinas foram renovadas e passam por manutenção semanal. Além disso, não há fila nos horários de pico, então você treina sem esperar para usar os aparelhos.'),

    -- horario_fim_semana_feriado (3)
    (83, 'horario_fim_semana_feriado', 'Quer treinar no fim de semana? Aos sábados abrimos das 8h às 14h. Domingos e feriados estamos fechados, mas de segunda a sexta você treina das 6h às 22h.'),
    (84, 'horario_fim_semana_feriado', 'Horário de fim de semana e feriados:
• Sábado: 8h às 14h
• Domingo: fechado
• Feriados: fechado
De segunda a sexta o horário é das 6h às 22h.'),
    (85, 'horario_fim_semana_feriado', 'No sábado funcionamos das 8h às 14h. Aos domingos e feriados a academia fica fechada. De segunda a sexta abrimos das 6h às 22h, então dá para treinar antes ou depois do trabalho.')
) AS v(ord, codigo, texto)
JOIN intents i ON i.codigo = v.codigo
ORDER BY v.ord;

-- =========================================================
-- DADOS: FRASES DE TREINO (ligadas pelo código da intent)
-- A ordem importa: em empate, o classificador escolhe a frase mais antiga.
-- =========================================================

INSERT INTO training_phrases (intent_id, texto, origem)
SELECT i.id, v.texto, v.origem
FROM (VALUES

    -- saudacao (30)
    (1, 'saudacao', 'oi', 'seed'),
    (2, 'saudacao', 'ola', 'seed'),
    (3, 'saudacao', 'oi tudo bem', 'seed'),
    (4, 'saudacao', 'ola tudo bem', 'seed'),
    (5, 'saudacao', 'bom dia', 'seed'),
    (6, 'saudacao', 'boa tarde', 'seed'),
    (7, 'saudacao', 'boa noite', 'seed'),
    (8, 'saudacao', 'eai', 'seed'),
    (9, 'saudacao', 'e ai', 'seed'),
    (10, 'saudacao', 'opa', 'seed'),
    (11, 'saudacao', 'opa tudo certo', 'seed'),
    (12, 'saudacao', 'salve', 'seed'),
    (13, 'saudacao', 'hey', 'seed'),
    (14, 'saudacao', 'hello', 'seed'),
    (15, 'saudacao', 'oii', 'seed'),
    (16, 'saudacao', 'oiii', 'seed'),
    (17, 'saudacao', 'oi boa tarde', 'seed'),
    (18, 'saudacao', 'ola bom dia', 'seed'),
    (19, 'saudacao', 'tudo bem', 'seed'),
    (20, 'saudacao', 'tudo bom', 'seed'),
    (21, 'saudacao', 'beleza', 'seed'),
    (22, 'saudacao', 'fala ai', 'seed'),
    (23, 'saudacao', 'oi pessoal', 'seed'),
    (24, 'saudacao', 'ola academia', 'seed'),
    (25, 'saudacao', 'oi gostaria de informacoes', 'seed'),
    (26, 'saudacao', 'bom dia tudo bem', 'seed'),
    (27, 'saudacao', 'boa noite tudo bem', 'seed'),
    (28, 'saudacao', 'oie', 'seed'),
    (29, 'saudacao', 'alo', 'seed'),
    (30, 'saudacao', 'oi alguem ai', 'seed'),

    -- despedida (22)
    (31, 'despedida', 'tchau', 'seed'),
    (32, 'despedida', 'tchau tchau', 'seed'),
    (33, 'despedida', 'xau', 'seed'),
    (34, 'despedida', 'ate logo', 'seed'),
    (35, 'despedida', 'ate mais', 'seed'),
    (36, 'despedida', 'ate amanha', 'seed'),
    (37, 'despedida', 'ate a proxima', 'seed'),
    (38, 'despedida', 'falou', 'seed'),
    (39, 'despedida', 'flw', 'seed'),
    (40, 'despedida', 'adeus', 'seed'),
    (41, 'despedida', 'fui', 'seed'),
    (42, 'despedida', 'ate breve', 'seed'),
    (43, 'despedida', 'era so isso', 'seed'),
    (44, 'despedida', 'so isso mesmo', 'seed'),
    (45, 'despedida', 'por hoje e so', 'seed'),
    (46, 'despedida', 'encerrar conversa', 'seed'),
    (47, 'despedida', 'vou nessa', 'seed'),
    (48, 'despedida', 'ate depois', 'seed'),
    (49, 'despedida', 'tenha um bom dia', 'seed'),
    (50, 'despedida', 'boa semana', 'seed'),
    (51, 'despedida', 'bom final de semana', 'seed'),
    (52, 'despedida', 'ate outro dia', 'seed'),

    -- agradecimento (25)
    (53, 'agradecimento', 'obrigado', 'seed'),
    (54, 'agradecimento', 'obrigada', 'seed'),
    (55, 'agradecimento', 'muito obrigado', 'seed'),
    (56, 'agradecimento', 'muito obrigada', 'seed'),
    (57, 'agradecimento', 'obg', 'seed'),
    (58, 'agradecimento', 'brigado', 'seed'),
    (59, 'agradecimento', 'brigadao', 'seed'),
    (60, 'agradecimento', 'valeu', 'seed'),
    (61, 'agradecimento', 'vlw', 'seed'),
    (62, 'agradecimento', 'valeu mesmo', 'seed'),
    (63, 'agradecimento', 'agradeco', 'seed'),
    (64, 'agradecimento', 'agradeco a ajuda', 'seed'),
    (65, 'agradecimento', 'obrigado pela ajuda', 'seed'),
    (66, 'agradecimento', 'obrigado pela informacao', 'seed'),
    (67, 'agradecimento', 'ajudou muito', 'seed'),
    (68, 'agradecimento', 'show', 'seed'),
    (69, 'agradecimento', 'show de bola', 'seed'),
    (70, 'agradecimento', 'perfeito', 'seed'),
    (71, 'agradecimento', 'otimo', 'seed'),
    (72, 'agradecimento', 'entendi obrigado', 'seed'),
    (73, 'agradecimento', 'top', 'seed'),
    (74, 'agradecimento', 'massa valeu', 'seed'),
    (75, 'agradecimento', 'gratidao', 'seed'),
    (76, 'agradecimento', 'excelente atendimento', 'seed'),
    (77, 'agradecimento', 'voce ajudou bastante', 'seed'),

    -- sobre_bot (17)
    (78, 'sobre_bot', 'voce e um robo', 'seed'),
    (79, 'sobre_bot', 'e um robo', 'seed'),
    (80, 'sobre_bot', 'estou falando com um robo', 'seed'),
    (81, 'sobre_bot', 'voce e um bot', 'seed'),
    (82, 'sobre_bot', 'isso e um chatbot', 'seed'),
    (83, 'sobre_bot', 'quem e voce', 'seed'),
    (84, 'sobre_bot', 'quem esta falando', 'seed'),
    (85, 'sobre_bot', 'voce e humano ou robo', 'seed'),
    (86, 'sobre_bot', 'voce e de verdade', 'seed'),
    (87, 'sobre_bot', 'voce e uma inteligencia artificial', 'seed'),
    (88, 'sobre_bot', 'e inteligencia artificial', 'seed'),
    (89, 'sobre_bot', 'como voce funciona', 'seed'),
    (90, 'sobre_bot', 'qual seu nome', 'seed'),
    (91, 'sobre_bot', 'voce tem nome', 'seed'),
    (92, 'sobre_bot', 'assistente virtual', 'seed'),
    (93, 'sobre_bot', 'voce e o chatgpt', 'seed'),
    (94, 'sobre_bot', 'e resposta automatica', 'seed'),

    -- atendimento_humano (20)
    (95, 'atendimento_humano', 'quero falar com atendente', 'seed'),
    (96, 'atendimento_humano', 'falar com um atendente', 'seed'),
    (97, 'atendimento_humano', 'quero falar com uma pessoa', 'seed'),
    (98, 'atendimento_humano', 'quero falar com humano', 'seed'),
    (99, 'atendimento_humano', 'me passa para um humano', 'seed'),
    (100, 'atendimento_humano', 'atendimento humano', 'seed'),
    (101, 'atendimento_humano', 'tem alguem ai', 'seed'),
    (102, 'atendimento_humano', 'falar com alguem da academia', 'seed'),
    (103, 'atendimento_humano', 'quero falar com o gerente', 'seed'),
    (104, 'atendimento_humano', 'chamar um atendente', 'seed'),
    (105, 'atendimento_humano', 'transferir para atendente', 'seed'),
    (106, 'atendimento_humano', 'quero atendimento de verdade', 'seed'),
    (107, 'atendimento_humano', 'falar com a recepcao', 'seed'),
    (108, 'atendimento_humano', 'preciso de ajuda de uma pessoa', 'seed'),
    (109, 'atendimento_humano', 'atendente por favor', 'seed'),
    (110, 'atendimento_humano', 'falar com o responsavel', 'seed'),
    (111, 'atendimento_humano', 'quero falar com o dono', 'seed'),
    (112, 'atendimento_humano', 'pessoa de verdade', 'seed'),
    (113, 'atendimento_humano', 'transfere para um atendente', 'seed'),
    (114, 'atendimento_humano', 'me transfere para alguem', 'seed'),

    -- reclamacao_sugestao (18)
    (115, 'reclamacao_sugestao', 'quero fazer uma reclamacao', 'seed'),
    (116, 'reclamacao_sugestao', 'tenho uma reclamacao', 'seed'),
    (117, 'reclamacao_sugestao', 'quero reclamar', 'seed'),
    (118, 'reclamacao_sugestao', 'quero dar uma sugestao', 'seed'),
    (119, 'reclamacao_sugestao', 'tenho uma sugestao', 'seed'),
    (120, 'reclamacao_sugestao', 'aparelho quebrado', 'seed'),
    (121, 'reclamacao_sugestao', 'a esteira esta quebrada', 'seed'),
    (122, 'reclamacao_sugestao', 'maquina estragada', 'seed'),
    (123, 'reclamacao_sugestao', 'o vestiario esta sujo', 'seed'),
    (124, 'reclamacao_sugestao', 'academia muito lotada', 'seed'),
    (125, 'reclamacao_sugestao', 'estou insatisfeito', 'seed'),
    (126, 'reclamacao_sugestao', 'pessimo atendimento', 'seed'),
    (127, 'reclamacao_sugestao', 'professor foi grosso', 'seed'),
    (128, 'reclamacao_sugestao', 'ar condicionado nao funciona', 'seed'),
    (129, 'reclamacao_sugestao', 'ouvidoria', 'seed'),
    (130, 'reclamacao_sugestao', 'problema na academia', 'seed'),
    (131, 'reclamacao_sugestao', 'fui mal atendido', 'seed'),
    (132, 'reclamacao_sugestao', 'musica muito alta', 'seed'),

    -- horario_funcionamento (26)
    (133, 'horario_funcionamento', 'qual o horario de funcionamento', 'seed'),
    (134, 'horario_funcionamento', 'horario de funcionamento', 'seed'),
    (135, 'horario_funcionamento', 'que horas abre', 'seed'),
    (136, 'horario_funcionamento', 'que horas a academia abre', 'seed'),
    (137, 'horario_funcionamento', 'que horas fecha', 'seed'),
    (138, 'horario_funcionamento', 'ate que horas fica aberta', 'seed'),
    (139, 'horario_funcionamento', 'abre que horas', 'seed'),
    (140, 'horario_funcionamento', 'fecha que horas', 'seed'),
    (141, 'horario_funcionamento', 'horario da academia', 'seed'),
    (142, 'horario_funcionamento', 'funciona domingo', 'seed'),
    (143, 'horario_funcionamento', 'abre no domingo', 'seed'),
    (144, 'horario_funcionamento', 'abre sabado', 'seed'),
    (145, 'horario_funcionamento', 'horario de sabado', 'seed'),
    (146, 'horario_funcionamento', 'funciona no feriado', 'seed'),
    (147, 'horario_funcionamento', 'abre feriado', 'seed'),
    (148, 'horario_funcionamento', 'abre cedo', 'seed'),
    (149, 'horario_funcionamento', 'abre de madrugada', 'seed'),
    (150, 'horario_funcionamento', 'funciona 24 horas', 'seed'),
    (151, 'horario_funcionamento', 'ate que horas posso treinar', 'seed'),
    (152, 'horario_funcionamento', 'horario de segunda a sexta', 'seed'),
    (153, 'horario_funcionamento', 'esta aberta agora', 'seed'),
    (154, 'horario_funcionamento', 'a academia ja abriu', 'seed'),
    (155, 'horario_funcionamento', 'fecha tarde', 'seed'),
    (156, 'horario_funcionamento', 'horario de domingo', 'seed'),
    (157, 'horario_funcionamento', 'funciona no natal', 'seed'),
    (158, 'horario_funcionamento', 'horario de atendimento', 'seed'),

    -- endereco_localizacao (21)
    (159, 'endereco_localizacao', 'onde fica a academia', 'seed'),
    (160, 'endereco_localizacao', 'qual o endereco', 'seed'),
    (161, 'endereco_localizacao', 'endereco da academia', 'seed'),
    (162, 'endereco_localizacao', 'onde voces ficam', 'seed'),
    (163, 'endereco_localizacao', 'localizacao', 'seed'),
    (164, 'endereco_localizacao', 'qual a localizacao', 'seed'),
    (165, 'endereco_localizacao', 'como chego ai', 'seed'),
    (166, 'endereco_localizacao', 'como chegar na academia', 'seed'),
    (167, 'endereco_localizacao', 'fica em qual bairro', 'seed'),
    (168, 'endereco_localizacao', 'fica em qual cidade', 'seed'),
    (169, 'endereco_localizacao', 'qual a rua', 'seed'),
    (170, 'endereco_localizacao', 'qual o cep', 'seed'),
    (171, 'endereco_localizacao', 'manda a localizacao', 'seed'),
    (172, 'endereco_localizacao', 'fica no centro', 'seed'),
    (173, 'endereco_localizacao', 'fica em palhoca', 'seed'),
    (174, 'endereco_localizacao', 'e perto da unisul', 'seed'),
    (175, 'endereco_localizacao', 'tem outra unidade', 'seed'),
    (176, 'endereco_localizacao', 'tem filial', 'seed'),
    (177, 'endereco_localizacao', 'endereco completo', 'seed'),
    (178, 'endereco_localizacao', 'ponto de referencia', 'seed'),
    (179, 'endereco_localizacao', 'localizacao no mapa', 'seed'),

    -- contato (18)
    (180, 'contato', 'qual o telefone', 'seed'),
    (181, 'contato', 'telefone da academia', 'seed'),
    (182, 'contato', 'numero de telefone', 'seed'),
    (183, 'contato', 'qual o whatsapp', 'seed'),
    (184, 'contato', 'tem whatsapp', 'seed'),
    (185, 'contato', 'numero do zap', 'seed'),
    (186, 'contato', 'me passa o zap', 'seed'),
    (187, 'contato', 'qual o email', 'seed'),
    (188, 'contato', 'email da academia', 'seed'),
    (189, 'contato', 'como entro em contato', 'seed'),
    (190, 'contato', 'contato da academia', 'seed'),
    (191, 'contato', 'posso ligar', 'seed'),
    (192, 'contato', 'numero para ligar', 'seed'),
    (193, 'contato', 'telefone para contato', 'seed'),
    (194, 'contato', 'whats da academia', 'seed'),
    (195, 'contato', 'manda o numero', 'seed'),
    (196, 'contato', 'tem instagram', 'seed'),
    (197, 'contato', 'redes sociais', 'seed'),

    -- estacionamento (16)
    (198, 'estacionamento', 'tem estacionamento', 'seed'),
    (199, 'estacionamento', 'onde estaciono', 'seed'),
    (200, 'estacionamento', 'estacionamento e gratis', 'seed'),
    (201, 'estacionamento', 'estacionamento pago', 'seed'),
    (202, 'estacionamento', 'posso estacionar o carro', 'seed'),
    (203, 'estacionamento', 'vaga para carro', 'seed'),
    (204, 'estacionamento', 'vaga para moto', 'seed'),
    (205, 'estacionamento', 'tem bicicletario', 'seed'),
    (206, 'estacionamento', 'onde deixo a bicicleta', 'seed'),
    (207, 'estacionamento', 'estacionar na academia', 'seed'),
    (208, 'estacionamento', 'tem vaga de estacionamento', 'seed'),
    (209, 'estacionamento', 'estacionamento para alunos', 'seed'),
    (210, 'estacionamento', 'tem garagem', 'seed'),
    (211, 'estacionamento', 'onde paro o carro', 'seed'),
    (212, 'estacionamento', 'onde deixo a bike', 'seed'),
    (213, 'estacionamento', 'lugar para bicicleta', 'seed'),

    -- estrutura (27)
    (214, 'estrutura', 'tem vestiario', 'seed'),
    (215, 'estrutura', 'tem chuveiro', 'seed'),
    (216, 'estrutura', 'posso tomar banho', 'seed'),
    (217, 'estrutura', 'tem chuveiro quente', 'seed'),
    (218, 'estrutura', 'tem armario', 'seed'),
    (219, 'estrutura', 'precisa levar cadeado', 'seed'),
    (220, 'estrutura', 'onde guardo minhas coisas', 'seed'),
    (221, 'estrutura', 'tem bebedouro', 'seed'),
    (222, 'estrutura', 'tem agua', 'seed'),
    (223, 'estrutura', 'tem wifi', 'seed'),
    (224, 'estrutura', 'senha do wifi', 'seed'),
    (225, 'estrutura', 'tem wi-fi', 'seed'),
    (226, 'estrutura', 'tem internet', 'seed'),
    (227, 'estrutura', 'tem ar condicionado', 'seed'),
    (228, 'estrutura', 'academia climatizada', 'seed'),
    (229, 'estrutura', 'equipamentos sao novos', 'seed'),
    (230, 'estrutura', 'quais aparelhos tem', 'seed'),
    (231, 'estrutura', 'tem esteira', 'seed'),
    (232, 'estrutura', 'tem bicicleta ergometrica', 'seed'),
    (233, 'estrutura', 'tem acessibilidade', 'seed'),
    (234, 'estrutura', 'acesso para cadeirante', 'seed'),
    (235, 'estrutura', 'banheiro adaptado', 'seed'),
    (236, 'estrutura', 'estrutura da academia', 'seed'),
    (237, 'estrutura', 'academia e grande', 'seed'),
    (238, 'estrutura', 'tem toalha', 'seed'),
    (239, 'estrutura', 'precisa levar toalha', 'seed'),
    (240, 'estrutura', 'tem secador', 'seed'),

    -- acesso_academia (16)
    (241, 'acesso_academia', 'como entro na academia', 'seed'),
    (242, 'acesso_academia', 'como funciona a catraca', 'seed'),
    (243, 'acesso_academia', 'catraca nao libera', 'seed'),
    (244, 'acesso_academia', 'a catraca travou', 'seed'),
    (245, 'acesso_academia', 'minha digital nao funciona', 'seed'),
    (246, 'acesso_academia', 'biometria nao funciona', 'seed'),
    (247, 'acesso_academia', 'cadastrar digital', 'seed'),
    (248, 'acesso_academia', 'precisa de carteirinha', 'seed'),
    (249, 'acesso_academia', 'esqueci a carteirinha', 'seed'),
    (250, 'acesso_academia', 'entrada por biometria', 'seed'),
    (251, 'acesso_academia', 'acesso por digital', 'seed'),
    (252, 'acesso_academia', 'nao consigo entrar', 'seed'),
    (253, 'acesso_academia', 'como libero minha entrada', 'seed'),
    (254, 'acesso_academia', 'acesso bloqueado', 'seed'),
    (255, 'acesso_academia', 'entrada na academia', 'seed'),
    (256, 'acesso_academia', 'como e a entrada', 'seed'),

    -- idade_minima (14)
    (257, 'idade_minima', 'qual a idade minima', 'seed'),
    (258, 'idade_minima', 'idade minima para treinar', 'seed'),
    (259, 'idade_minima', 'menor de idade pode treinar', 'seed'),
    (260, 'idade_minima', 'adolescente pode malhar', 'seed'),
    (261, 'idade_minima', 'com quantos anos posso treinar', 'seed'),
    (262, 'idade_minima', 'meu filho de 14 anos pode', 'seed'),
    (263, 'idade_minima', 'crianca pode treinar', 'seed'),
    (264, 'idade_minima', 'tenho 15 anos posso me matricular', 'seed'),
    (265, 'idade_minima', 'menor precisa de autorizacao', 'seed'),
    (266, 'idade_minima', 'idoso pode treinar', 'seed'),
    (267, 'idade_minima', 'tem limite de idade', 'seed'),
    (268, 'idade_minima', 'tem aula para criancas', 'seed'),
    (269, 'idade_minima', 'aceita menor', 'seed'),
    (270, 'idade_minima', 'tenho 13 anos', 'seed'),

    -- planos_valores (9)
    (271, 'planos_valores', 'quais sao os planos', 'seed'),
    (272, 'planos_valores', 'quais planos voces tem', 'seed'),
    (273, 'planos_valores', 'planos disponiveis', 'seed'),
    (274, 'planos_valores', 'quanto custa', 'seed'),
    (275, 'planos_valores', 'quanto custa a academia', 'seed'),
    (276, 'planos_valores', 'qual o valor da mensalidade', 'seed'),
    (277, 'planos_valores', 'valor da mensalidade', 'seed'),
    (278, 'planos_valores', 'preco da academia', 'seed'),
    (279, 'planos_valores', 'tabela de precos', 'seed'),

    -- plano_mensal (1)
    (280, 'plano_mensal', 'quanto e o plano mensal', 'seed'),

    -- plano_trimestral (1)
    (281, 'plano_trimestral', 'valor do plano trimestral', 'seed'),

    -- plano_anual (1)
    (282, 'plano_anual', 'quanto custa o plano anual', 'seed'),

    -- planos_valores (5)
    (283, 'planos_valores', 'qual o plano mais barato', 'seed'),
    (284, 'planos_valores', 'qual o melhor plano', 'seed'),
    (285, 'planos_valores', 'diferenca entre os planos', 'seed'),
    (286, 'planos_valores', 'o que inclui o plano', 'seed'),
    (287, 'planos_valores', 'plano sem fidelidade', 'seed'),

    -- plano_mensal (1)
    (288, 'plano_mensal', 'tem plano mensal', 'seed'),

    -- planos_valores (2)
    (289, 'planos_valores', 'valores dos planos', 'seed'),
    (290, 'planos_valores', 'mensalidade quanto e', 'seed'),

    -- plano_anual (1)
    (291, 'plano_anual', 'preco do anual', 'seed'),

    -- planos_valores (5)
    (292, 'planos_valores', 'quanto fica por mes', 'seed'),
    (293, 'planos_valores', 'o plano inclui aulas coletivas', 'seed'),
    (294, 'planos_valores', 'planos e precos', 'seed'),
    (295, 'planos_valores', 'plano mais em conta', 'seed'),
    (296, 'planos_valores', 'qual plano compensa mais', 'seed'),

    -- matricula (21)
    (297, 'matricula', 'como faco para me matricular', 'seed'),
    (298, 'matricula', 'quero me matricular', 'seed'),
    (299, 'matricula', 'como me inscrevo', 'seed'),
    (300, 'matricula', 'quero ser aluno', 'seed'),
    (301, 'matricula', 'quero entrar na academia', 'seed'),
    (302, 'matricula', 'como faco minha inscricao', 'seed'),
    (303, 'matricula', 'fazer matricula', 'seed'),
    (304, 'matricula', 'matricula online', 'seed'),
    (305, 'matricula', 'posso me matricular pelo whatsapp', 'seed'),
    (306, 'matricula', 'quais documentos preciso', 'seed'),
    (307, 'matricula', 'precisa de documento', 'seed'),
    (308, 'matricula', 'tem taxa de matricula', 'seed'),
    (309, 'matricula', 'quanto e a matricula', 'seed'),
    (310, 'matricula', 'valor da matricula', 'seed'),
    (311, 'matricula', 'precisa de atestado medico', 'seed'),
    (312, 'matricula', 'precisa de exame medico', 'seed'),
    (313, 'matricula', 'quero comecar a treinar', 'seed'),
    (314, 'matricula', 'como faco cadastro', 'seed'),
    (315, 'matricula', 'quero fechar um plano', 'seed'),
    (316, 'matricula', 'quero contratar', 'seed'),
    (317, 'matricula', 'matricula e gratis', 'seed'),

    -- formas_pagamento (20)
    (318, 'formas_pagamento', 'quais as formas de pagamento', 'seed'),
    (319, 'formas_pagamento', 'formas de pagamento', 'seed'),
    (320, 'formas_pagamento', 'como posso pagar', 'seed'),
    (321, 'formas_pagamento', 'aceita pix', 'seed'),
    (322, 'formas_pagamento', 'posso pagar no pix', 'seed'),
    (323, 'formas_pagamento', 'aceita cartao', 'seed'),
    (324, 'formas_pagamento', 'aceita cartao de credito', 'seed'),
    (325, 'formas_pagamento', 'aceita debito', 'seed'),
    (326, 'formas_pagamento', 'posso pagar em dinheiro', 'seed'),
    (327, 'formas_pagamento', 'aceita boleto', 'seed'),
    (328, 'formas_pagamento', 'da para parcelar', 'seed'),
    (329, 'formas_pagamento', 'parcela em quantas vezes', 'seed'),
    (330, 'formas_pagamento', 'parcelar o anual', 'seed'),
    (331, 'formas_pagamento', 'parcelamento sem juros', 'seed'),
    (332, 'formas_pagamento', 'pagamento recorrente', 'seed'),
    (333, 'formas_pagamento', 'debito automatico', 'seed'),
    (334, 'formas_pagamento', 'pagar no cartao', 'seed'),
    (335, 'formas_pagamento', 'chave pix', 'seed'),
    (336, 'formas_pagamento', 'pagamento a vista', 'seed'),
    (337, 'formas_pagamento', 'aceita vale alimentacao', 'seed'),

    -- descontos_promocoes (18)
    (338, 'descontos_promocoes', 'tem desconto', 'seed'),
    (339, 'descontos_promocoes', 'tem promocao', 'seed'),
    (340, 'descontos_promocoes', 'desconto para estudante', 'seed'),
    (341, 'descontos_promocoes', 'desconto universitario', 'seed'),
    (342, 'descontos_promocoes', 'desconto para familia', 'seed'),
    (343, 'descontos_promocoes', 'plano casal', 'seed'),
    (344, 'descontos_promocoes', 'plano familia', 'seed'),
    (345, 'descontos_promocoes', 'aceita gympass', 'seed'),
    (346, 'descontos_promocoes', 'aceita wellhub', 'seed'),
    (347, 'descontos_promocoes', 'aceita totalpass', 'seed'),
    (348, 'descontos_promocoes', 'tem convenio', 'seed'),
    (349, 'descontos_promocoes', 'desconto empresa', 'seed'),
    (350, 'descontos_promocoes', 'promocao de matricula', 'seed'),
    (351, 'descontos_promocoes', 'tem cupom', 'seed'),
    (352, 'descontos_promocoes', 'desconto a vista', 'seed'),
    (353, 'descontos_promocoes', 'posso levar um amigo', 'seed'),
    (354, 'descontos_promocoes', 'traga um amigo como funciona', 'seed'),
    (355, 'descontos_promocoes', 'black friday', 'seed'),

    -- troca_plano (14)
    (356, 'troca_plano', 'quero trocar de plano', 'seed'),
    (357, 'troca_plano', 'mudar de plano', 'seed'),
    (358, 'troca_plano', 'trocar o plano mensal pelo anual', 'seed'),
    (359, 'troca_plano', 'fazer upgrade do plano', 'seed'),
    (360, 'troca_plano', 'passar para o plano anual', 'seed'),
    (361, 'troca_plano', 'posso mudar meu plano', 'seed'),
    (362, 'troca_plano', 'como renovo meu plano', 'seed'),
    (363, 'troca_plano', 'renovar plano', 'seed'),
    (364, 'troca_plano', 'quero renovar', 'seed'),
    (365, 'troca_plano', 'trocar para trimestral', 'seed'),
    (366, 'troca_plano', 'diminuir meu plano', 'seed'),
    (367, 'troca_plano', 'mudar para um plano mais barato', 'seed'),
    (368, 'troca_plano', 'alterar plano', 'seed'),
    (369, 'troca_plano', 'meu plano vence quando', 'seed'),

    -- pagamento_atrasado (17)
    (370, 'pagamento_atrasado', 'mensalidade atrasada', 'seed'),
    (371, 'pagamento_atrasado', 'atrasei a mensalidade', 'seed'),
    (372, 'pagamento_atrasado', 'paguei atrasado', 'seed'),
    (373, 'pagamento_atrasado', 'estou devendo', 'seed'),
    (374, 'pagamento_atrasado', 'segunda via', 'seed'),
    (375, 'pagamento_atrasado', 'segunda via da mensalidade', 'seed'),
    (376, 'pagamento_atrasado', 'como pago mensalidade atrasada', 'seed'),
    (377, 'pagamento_atrasado', 'tem multa por atraso', 'seed'),
    (378, 'pagamento_atrasado', 'juros por atraso', 'seed'),
    (379, 'pagamento_atrasado', 'esqueci de pagar', 'seed'),
    (380, 'pagamento_atrasado', 'meu pagamento nao caiu', 'seed'),
    (381, 'pagamento_atrasado', 'fui bloqueado por falta de pagamento', 'seed'),
    (382, 'pagamento_atrasado', 'estou em debito com a academia', 'seed'),
    (383, 'pagamento_atrasado', 'regularizar pagamento', 'seed'),
    (384, 'pagamento_atrasado', 'quitar divida', 'seed'),
    (385, 'pagamento_atrasado', 'multa por atrasar', 'seed'),
    (386, 'pagamento_atrasado', 'atrasar a mensalidade', 'seed'),

    -- cancelamento (17)
    (387, 'cancelamento', 'quero cancelar', 'seed'),
    (388, 'cancelamento', 'quero cancelar minha matricula', 'seed'),
    (389, 'cancelamento', 'como cancelo o plano', 'seed'),
    (390, 'cancelamento', 'cancelar plano', 'seed'),
    (391, 'cancelamento', 'cancelamento', 'seed'),
    (392, 'cancelamento', 'quero sair da academia', 'seed'),
    (393, 'cancelamento', 'nao quero mais treinar', 'seed'),
    (394, 'cancelamento', 'quero desistir', 'seed'),
    (395, 'cancelamento', 'encerrar contrato', 'seed'),
    (396, 'cancelamento', 'tem multa para cancelar', 'seed'),
    (397, 'cancelamento', 'multa de cancelamento', 'seed'),
    (398, 'cancelamento', 'cancelar o anual', 'seed'),
    (399, 'cancelamento', 'cancelar pelo whatsapp', 'seed'),
    (400, 'cancelamento', 'quero dar baixa na matricula', 'seed'),
    (401, 'cancelamento', 'como faco o cancelamento', 'seed'),
    (402, 'cancelamento', 'rescindir contrato', 'seed'),
    (403, 'cancelamento', 'parar de pagar', 'seed'),

    -- trancamento (18)
    (404, 'trancamento', 'quero trancar', 'seed'),
    (405, 'trancamento', 'como tranco meu plano', 'seed'),
    (406, 'trancamento', 'trancar matricula', 'seed'),
    (407, 'trancamento', 'trancamento', 'seed'),
    (408, 'trancamento', 'quero pausar o plano', 'seed'),
    (409, 'trancamento', 'congelar plano', 'seed'),
    (410, 'trancamento', 'suspender o plano', 'seed'),
    (411, 'trancamento', 'vou viajar', 'seed'),
    (412, 'trancamento', 'vou viajar posso pausar', 'seed'),
    (413, 'trancamento', 'vou ficar um mes fora', 'seed'),
    (414, 'trancamento', 'ferias posso trancar', 'seed'),
    (415, 'trancamento', 'vou fazer cirurgia', 'seed'),
    (416, 'trancamento', 'estou lesionado', 'seed'),
    (417, 'trancamento', 'estou de atestado', 'seed'),
    (418, 'trancamento', 'licenca maternidade', 'seed'),
    (419, 'trancamento', 'pausar a academia', 'seed'),
    (420, 'trancamento', 'trancar por 30 dias', 'seed'),
    (421, 'trancamento', 'dias de trancamento', 'seed'),

    -- personal_trainer (19)
    (422, 'personal_trainer', 'tem personal', 'seed'),
    (423, 'personal_trainer', 'tem personal trainer', 'seed'),
    (424, 'personal_trainer', 'quero um personal', 'seed'),
    (425, 'personal_trainer', 'quero treinar com personal', 'seed'),
    (426, 'personal_trainer', 'quanto custa o personal', 'seed'),
    (427, 'personal_trainer', 'valor do personal', 'seed'),
    (428, 'personal_trainer', 'como contrato um personal', 'seed'),
    (429, 'personal_trainer', 'personal e incluso no plano', 'seed'),
    (430, 'personal_trainer', 'personal e separado da mensalidade', 'seed'),
    (431, 'personal_trainer', 'agendar personal', 'seed'),
    (432, 'personal_trainer', 'treino individual', 'seed'),
    (433, 'personal_trainer', 'professor particular', 'seed'),
    (434, 'personal_trainer', 'acompanhamento individual', 'seed'),
    (435, 'personal_trainer', 'treino personalizado', 'seed'),
    (436, 'personal_trainer', 'pacote de personal', 'seed'),
    (437, 'personal_trainer', 'personal para iniciante', 'seed'),
    (438, 'personal_trainer', 'posso trazer meu personal', 'seed'),
    (439, 'personal_trainer', 'levar personal de fora', 'seed'),
    (440, 'personal_trainer', 'personal externo', 'seed'),

    -- avaliacao_fisica (14)
    (441, 'avaliacao_fisica', 'tem avaliacao fisica', 'seed'),
    (442, 'avaliacao_fisica', 'como faco avaliacao fisica', 'seed'),
    (443, 'avaliacao_fisica', 'avaliacao fisica e gratis', 'seed'),
    (444, 'avaliacao_fisica', 'quanto custa a avaliacao', 'seed'),
    (445, 'avaliacao_fisica', 'agendar avaliacao', 'seed'),
    (446, 'avaliacao_fisica', 'quero fazer avaliacao', 'seed'),
    (447, 'avaliacao_fisica', 'reavaliacao fisica', 'seed'),
    (448, 'avaliacao_fisica', 'tem bioimpedancia', 'seed'),
    (449, 'avaliacao_fisica', 'medir percentual de gordura', 'seed'),
    (450, 'avaliacao_fisica', 'tirar medidas', 'seed'),
    (451, 'avaliacao_fisica', 'avaliacao postural', 'seed'),
    (452, 'avaliacao_fisica', 'avaliacao inicial', 'seed'),
    (453, 'avaliacao_fisica', 'quando posso me reavaliar', 'seed'),
    (454, 'avaliacao_fisica', 'fazer bioimpedancia', 'seed'),

    -- aula_experimental (18)
    (455, 'aula_experimental', 'tem aula experimental', 'seed'),
    (456, 'aula_experimental', 'aula gratis', 'seed'),
    (457, 'aula_experimental', 'primeira aula gratis', 'seed'),
    (458, 'aula_experimental', 'posso fazer uma aula teste', 'seed'),
    (459, 'aula_experimental', 'quero conhecer a academia', 'seed'),
    (460, 'aula_experimental', 'posso visitar a academia', 'seed'),
    (461, 'aula_experimental', 'quero testar antes', 'seed'),
    (462, 'aula_experimental', 'tem diaria', 'seed'),
    (463, 'aula_experimental', 'valor da diaria', 'seed'),
    (464, 'aula_experimental', 'treinar so um dia', 'seed'),
    (465, 'aula_experimental', 'day use', 'seed'),
    (466, 'aula_experimental', 'aula avulsa', 'seed'),
    (467, 'aula_experimental', 'experimentar a academia', 'seed'),
    (468, 'aula_experimental', 'fazer um treino teste', 'seed'),
    (469, 'aula_experimental', 'conhecer antes de fechar', 'seed'),
    (470, 'aula_experimental', 'preco da diaria', 'seed'),
    (471, 'aula_experimental', 'diaria quanto e', 'seed'),
    (472, 'aula_experimental', 'visita guiada', 'seed'),

    -- aulas_modalidades (24)
    (473, 'aulas_modalidades', 'quais modalidades voces tem', 'seed'),
    (474, 'aulas_modalidades', 'quais aulas tem', 'seed'),
    (475, 'aulas_modalidades', 'quais aulas coletivas', 'seed'),
    (476, 'aulas_modalidades', 'aulas coletivas', 'seed'),
    (477, 'aulas_modalidades', 'tem aula de spinning', 'seed'),
    (478, 'aulas_modalidades', 'tem spinning', 'seed'),
    (479, 'aulas_modalidades', 'tem yoga', 'seed'),
    (480, 'aulas_modalidades', 'tem aula de yoga', 'seed'),
    (481, 'aulas_modalidades', 'tem funcional', 'seed'),
    (482, 'aulas_modalidades', 'tem aula de danca', 'seed'),
    (483, 'aulas_modalidades', 'tem zumba', 'seed'),
    (484, 'aulas_modalidades', 'tem pilates', 'seed'),
    (485, 'aulas_modalidades', 'tem crossfit', 'seed'),
    (486, 'aulas_modalidades', 'tem luta', 'seed'),
    (487, 'aulas_modalidades', 'tem muay thai', 'seed'),
    (488, 'aulas_modalidades', 'tem natacao', 'seed'),
    (489, 'aulas_modalidades', 'tem piscina', 'seed'),
    (490, 'aulas_modalidades', 'tem musculacao', 'seed'),
    (491, 'aulas_modalidades', 'aula para iniciante', 'seed'),
    (492, 'aulas_modalidades', 'aulas estao inclusas no plano', 'seed'),
    (493, 'aulas_modalidades', 'aula coletiva e paga a parte', 'seed'),
    (494, 'aulas_modalidades', 'tem aula de bike', 'seed'),
    (495, 'aulas_modalidades', 'modalidades disponiveis', 'seed'),
    (496, 'aulas_modalidades', 'tem jiu jitsu', 'seed'),

    -- horario_aulas (18)
    (497, 'horario_aulas', 'horario das aulas', 'seed'),
    (498, 'horario_aulas', 'grade de aulas', 'seed'),
    (499, 'horario_aulas', 'grade de horarios das aulas', 'seed'),
    (500, 'horario_aulas', 'que horas tem spinning', 'seed'),
    (501, 'horario_aulas', 'horario do spinning', 'seed'),
    (502, 'horario_aulas', 'que dia tem yoga', 'seed'),
    (503, 'horario_aulas', 'horario da yoga', 'seed'),
    (504, 'horario_aulas', 'horario do funcional', 'seed'),
    (505, 'horario_aulas', 'que horas e o funcional', 'seed'),
    (506, 'horario_aulas', 'horario da aula de danca', 'seed'),
    (507, 'horario_aulas', 'aula de danca que dia', 'seed'),
    (508, 'horario_aulas', 'tem aula a noite', 'seed'),
    (509, 'horario_aulas', 'tem aula de manha', 'seed'),
    (510, 'horario_aulas', 'tem aula no sabado', 'seed'),
    (511, 'horario_aulas', 'aulas de sabado', 'seed'),
    (512, 'horario_aulas', 'precisa agendar aula coletiva', 'seed'),
    (513, 'horario_aulas', 'quantas vezes por semana tem spinning', 'seed'),
    (514, 'horario_aulas', 'dias das aulas', 'seed'),

    -- horario_funcionamento (9)
    (515, 'horario_funcionamento', 'funciona', 'seed'),
    (516, 'horario_funcionamento', 'aberto', 'seed'),
    (517, 'horario_funcionamento', 'abre', 'seed'),
    (518, 'horario_funcionamento', 'horarios', 'seed'),
    (519, 'horario_funcionamento', 'horario', 'seed'),
    (520, 'horario_funcionamento', 'funcionamento', 'seed'),
    (521, 'horario_funcionamento', 'fecha', 'seed'),
    (522, 'horario_funcionamento', 'abertura', 'seed'),
    (523, 'horario_funcionamento', 'aberta', 'seed'),

    -- horario_aulas (4)
    (524, 'horario_aulas', 'grade de horarios', 'seed'),
    (525, 'horario_aulas', 'horario das turmas', 'seed'),
    (526, 'horario_aulas', 'horarios das aulas', 'seed'),
    (527, 'horario_aulas', 'horarios das turmas', 'seed'),

    -- aulas_modalidades (6)
    (528, 'aulas_modalidades', 'modalidades', 'seed'),
    (529, 'aulas_modalidades', 'turmas', 'seed'),
    (530, 'aulas_modalidades', 'aulas', 'seed'),
    (531, 'aulas_modalidades', 'turma', 'seed'),
    (532, 'aulas_modalidades', 'modalidade', 'seed'),
    (533, 'aulas_modalidades', 'aula', 'seed'),

    -- planos_valores (12)
    (534, 'planos_valores', 'mensalidade', 'seed'),
    (535, 'planos_valores', 'plano', 'seed'),
    (536, 'planos_valores', 'mensalidades', 'seed'),
    (537, 'planos_valores', 'valor', 'seed'),
    (538, 'planos_valores', 'qual o preco', 'seed'),
    (539, 'planos_valores', 'quanto', 'seed'),
    (540, 'planos_valores', 'planos', 'seed'),
    (541, 'planos_valores', 'valores', 'seed'),
    (542, 'planos_valores', 'precos', 'seed'),
    (543, 'planos_valores', 'quanto e', 'seed'),
    (544, 'planos_valores', 'qual o valor', 'seed'),
    (545, 'planos_valores', 'preco', 'seed'),

    -- matricula (3)
    (546, 'matricula', 'matricular', 'seed'),
    (547, 'matricula', 'matriculas', 'seed'),
    (548, 'matricula', 'matricula', 'seed'),

    -- plano_anual (1)
    (549, 'plano_anual', 'plano anual inclui aulas coletivas', 'seed'),

    -- plano_mensal (1)
    (550, 'plano_mensal', 'so o mensal', 'seed'),

    -- plano_trimestral (1)
    (551, 'plano_trimestral', 'quantas vezes posso trazer um amigo', 'seed'),

    -- taxa_matricula (1)
    (552, 'taxa_matricula', 'matricula gratis', 'seed'),

    -- plano_anual (1)
    (553, 'plano_anual', 'plano anual por mes', 'seed'),

    -- plano_mensal (1)
    (554, 'plano_mensal', 'plano mensal tem avaliacao fisica', 'seed'),

    -- plano_trimestral (1)
    (555, 'plano_trimestral', 'me fala do plano trimestral', 'seed'),

    -- taxa_matricula (1)
    (556, 'taxa_matricula', 'preco da matricula', 'seed'),

    -- plano_trimestral (1)
    (557, 'plano_trimestral', 'quero o plano trimestral', 'seed'),

    -- taxa_matricula (1)
    (558, 'taxa_matricula', 'quanto pago pra me matricular', 'seed'),

    -- plano_anual (2)
    (559, 'plano_anual', 'o que tem no plano anual', 'seed'),
    (560, 'plano_anual', 'qnto e o anual', 'seed'),

    -- taxa_matricula (1)
    (561, 'taxa_matricula', 'quanto pago na primeira vez', 'seed'),

    -- plano_mensal (1)
    (562, 'plano_mensal', 'plano mensall', 'seed'),

    -- documentos_matricula (1)
    (563, 'documentos_matricula', 'quero me matricular quais documentos', 'seed'),

    -- plano_trimestral (2)
    (564, 'plano_trimestral', 'trimestral tem traga um amigo', 'seed'),
    (565, 'plano_trimestral', 'como funciona o traga um amigo', 'seed'),

    -- taxa_matricula (2)
    (566, 'taxa_matricula', 'tem taxa de adesao', 'seed'),
    (567, 'taxa_matricula', 'matricula mais mensalidade quanto fica', 'seed'),

    -- comparar_planos (1)
    (568, 'comparar_planos', 'mensal ou trimestral', 'seed'),

    -- documentos_matricula (3)
    (569, 'documentos_matricula', 'documentoss para matricula', 'seed'),
    (570, 'documentos_matricula', 'preciso de algum documento', 'seed'),
    (571, 'documentos_matricula', 'o que levar na matricula', 'seed'),

    -- plano_trimestral (1)
    (572, 'plano_trimestral', 'plano trimestral por mes', 'seed'),

    -- plano_mensal (1)
    (573, 'plano_mensal', 'preco do plano mensal', 'seed'),

    -- plano_trimestral (1)
    (574, 'plano_trimestral', 'quanto e o trimestral', 'seed'),

    -- taxa_matricula (1)
    (575, 'taxa_matricula', 'taxa para matricular', 'seed'),

    -- plano_mensal (1)
    (576, 'plano_mensal', 'o que inclui o plano mensal', 'seed'),

    -- documentos_matricula (1)
    (577, 'documentos_matricula', 'posso usar a cnh pra me matricular', 'seed'),

    -- plano_mensal (2)
    (578, 'plano_mensal', 'valor do plano mensal', 'seed'),
    (579, 'plano_mensal', 'custo do plano mensal', 'seed'),

    -- taxa_matricula (2)
    (580, 'taxa_matricula', 'cobra taxa pra se matricular', 'seed'),
    (581, 'taxa_matricula', 'quanto custa a matricula', 'seed'),

    -- plano_anual (1)
    (582, 'plano_anual', 'quero o plano anual', 'seed'),

    -- plano_mensal (1)
    (583, 'plano_mensal', 'quero contratar o plano mensal', 'seed'),

    -- comparar_planos (1)
    (584, 'comparar_planos', 'qual a diferenca entre os planos', 'seed'),

    -- plano_mensal (1)
    (585, 'plano_mensal', 'plano sem contrato longo', 'seed'),

    -- plano_anual (2)
    (586, 'plano_anual', 'anual sai quanto por mes', 'seed'),
    (587, 'plano_anual', 'o anual inclui o que', 'seed'),

    -- documentos_matricula (1)
    (588, 'documentos_matricula', 'vou fazer matricula amanha o que levar', 'seed'),

    -- taxa_matricula (1)
    (589, 'taxa_matricula', 'tem matricula gratis', 'seed'),

    -- plano_mensal (1)
    (590, 'plano_mensal', 'o mensal prende num contrato longo', 'seed'),

    -- plano_anual (1)
    (591, 'plano_anual', 'o plano anual inclui avaliacao fisica', 'seed'),

    -- plano_trimestral (3)
    (592, 'plano_trimestral', 'qual plano tem reavaliacao', 'seed'),
    (593, 'plano_trimestral', 'qual plano o pessoal mais escolhe', 'seed'),
    (594, 'plano_trimestral', 'qual o plano mais escolhido', 'seed'),

    -- comparar_planos (1)
    (595, 'comparar_planos', 'trimestral x anual', 'seed'),

    -- taxa_matricula (1)
    (596, 'taxa_matricula', 'vcs cobram taxa de matricula', 'seed'),

    -- documentos_matricula (1)
    (597, 'documentos_matricula', 'o que precisa pra fazer a matricula', 'seed'),

    -- plano_anual (1)
    (598, 'plano_anual', 'custo do plano anual', 'seed'),

    -- documentos_matricula (1)
    (599, 'documentos_matricula', 'que documento levar na academia', 'seed'),

    -- plano_anual (1)
    (600, 'plano_anual', 'quero fechar um ano de plano', 'seed'),

    -- plano_mensal (1)
    (601, 'plano_mensal', 'posso fazer so um mes', 'seed'),

    -- comparar_planos (1)
    (602, 'comparar_planos', 'nao sei qual plano escolher', 'seed'),

    -- documentos_matricula (1)
    (603, 'documentos_matricula', 'quais documentos sao necessarios', 'seed'),

    -- plano_anual (1)
    (604, 'plano_anual', 'plano anal', 'seed'),

    -- comparar_planos (2)
    (605, 'comparar_planos', 'diferenca entre mensal trimestral e anual', 'seed'),
    (606, 'comparar_planos', 'comparar os planos', 'seed'),

    -- plano_anual (1)
    (607, 'plano_anual', 'anual 89', 'seed'),

    -- taxa_matricula (1)
    (608, 'taxa_matricula', 'taxa de adesao', 'seed'),

    -- comparar_planos (1)
    (609, 'comparar_planos', 'quero comparar os planos', 'seed'),

    -- plano_mensal (1)
    (610, 'plano_mensal', 'plano mensal tem contrato', 'seed'),

    -- comparar_planos (1)
    (611, 'comparar_planos', 'qual plano escolher', 'seed'),

    -- plano_trimestral (1)
    (612, 'plano_trimestral', 'preco do plano trimestral', 'seed'),

    -- taxa_matricula (1)
    (613, 'taxa_matricula', 'matricula de graca', 'seed'),

    -- plano_trimestral (1)
    (614, 'plano_trimestral', 'custo do plano trimestral', 'seed'),

    -- plano_anual (1)
    (615, 'plano_anual', 'quanto custa o plano anual', 'seed'),

    -- plano_mensal (1)
    (616, 'plano_mensal', 'o que tem no plano mensal', 'seed'),

    -- comparar_planos (1)
    (617, 'comparar_planos', 'quanto eu economizo no plano maior', 'seed'),

    -- plano_trimestral (2)
    (618, 'plano_trimestral', 'qnto e o trimestral', 'seed'),
    (619, 'plano_trimestral', 'qnto custa o plano trimestral', 'seed'),

    -- documentos_matricula (1)
    (620, 'documentos_matricula', 'o que levar no dia da matricula', 'seed'),

    -- plano_mensal (1)
    (621, 'plano_mensal', 'plano mensal e por mes', 'seed'),

    -- comparar_planos (1)
    (622, 'comparar_planos', 'qual plano tem o melhor custo beneficio', 'seed'),

    -- plano_anual (2)
    (623, 'plano_anual', 'plano de 1 ano', 'seed'),
    (624, 'plano_anual', 'quanto fica o anual por mes', 'seed'),

    -- plano_trimestral (1)
    (625, 'plano_trimestral', 'posso trazer um amigo na academia', 'seed'),

    -- plano_anual (1)
    (626, 'plano_anual', 'plano anuall', 'seed'),

    -- comparar_planos (1)
    (627, 'comparar_planos', 'mensal ou anual', 'seed'),

    -- taxa_matricula (1)
    (628, 'taxa_matricula', 'matricula 59', 'seed'),

    -- comparar_planos (1)
    (629, 'comparar_planos', 'diferenca entre o mensal e o trimestral', 'seed'),

    -- plano_mensal (1)
    (630, 'plano_mensal', 'tem plano sem fidelidade', 'seed'),

    -- plano_trimestral (1)
    (631, 'plano_trimestral', 'quero pagar tres meses de academia', 'seed'),

    -- taxa_matricula (1)
    (632, 'taxa_matricula', 'taxa de matricola', 'seed'),

    -- plano_trimestral (2)
    (633, 'plano_trimestral', 'me explica o plano trimestral', 'seed'),
    (634, 'plano_trimestral', 'o plano trimestral inclui avaliacao fisica', 'seed'),

    -- comparar_planos (1)
    (635, 'comparar_planos', 'qual a diferenca de valor entre os planos', 'seed'),

    -- plano_trimestral (1)
    (636, 'plano_trimestral', 'plano mais vendido', 'seed'),

    -- taxa_matricula (1)
    (637, 'taxa_matricula', 'valor da taxa de matricula', 'seed'),

    -- plano_trimestral (2)
    (638, 'plano_trimestral', 'como funciona o plano trimestral', 'seed'),
    (639, 'plano_trimestral', 'o que tem no plano trimestral', 'seed'),

    -- plano_anual (1)
    (640, 'plano_anual', 'qnto custa o plano anual', 'seed'),

    -- plano_trimestral (1)
    (641, 'plano_trimestral', 'o que e a reavaliacao fisica do plano', 'seed'),

    -- documentos_matricula (1)
    (642, 'documentos_matricula', 'quais documentos preciso pra me matricular', 'seed'),

    -- plano_mensal (1)
    (643, 'plano_mensal', 'quero pagar so um mes de academia', 'seed'),

    -- documentos_matricula (1)
    (644, 'documentos_matricula', 'documentacao da matricula', 'seed'),

    -- comparar_planos (1)
    (645, 'comparar_planos', 'vale a pena pagar mais meses de uma vez', 'seed'),

    -- plano_mensal (1)
    (646, 'plano_mensal', 'me explica o plano mensal', 'seed'),

    -- comparar_planos (1)
    (647, 'comparar_planos', 'me ajuda a escolher um plano', 'seed'),

    -- taxa_matricula (1)
    (648, 'taxa_matricula', 'matricula custa quanto', 'seed'),

    -- plano_anual (2)
    (649, 'plano_anual', 'plno anual', 'seed'),
    (650, 'plano_anual', 'me explica o plano anual', 'seed'),

    -- documentos_matricula (3)
    (651, 'documentos_matricula', 'quais documentos preciso levar', 'seed'),
    (652, 'documentos_matricula', 'precisa de rg e cpf', 'seed'),
    (653, 'documentos_matricula', 'precisa de documento com foto', 'seed'),

    -- comparar_planos (1)
    (654, 'comparar_planos', 'mensal x anual', 'seed'),

    -- plano_mensal (1)
    (655, 'plano_mensal', 'fala sobre o plano mensal', 'seed'),

    -- plano_trimestral (1)
    (656, 'plano_trimestral', 'tem plano que posso levar um amigo', 'seed'),

    -- documentos_matricula (1)
    (657, 'documentos_matricula', 'documentos necessarios para matricular', 'seed'),

    -- comparar_planos (1)
    (658, 'comparar_planos', 'trimestral ou anual', 'seed'),

    -- plano_trimestral (1)
    (659, 'plano_trimestral', 'qual o plano mais popular', 'seed'),

    -- plano_mensal (1)
    (660, 'plano_mensal', 'plano sem fidelidade quanto custa', 'seed'),

    -- taxa_matricula (1)
    (661, 'taxa_matricula', 'quanto e a taxa de adesao', 'seed'),

    -- plano_mensal (1)
    (662, 'plano_mensal', 'plno mensal', 'seed'),

    -- comparar_planos (1)
    (663, 'comparar_planos', 'qual a diferenca do trimestral pro anual', 'seed'),

    -- plano_trimestral (1)
    (664, 'plano_trimestral', 'informacoes do plano trimestral', 'seed'),

    -- taxa_matricula (1)
    (665, 'taxa_matricula', 'paga taxa pra se matricular', 'seed'),

    -- plano_trimestral (1)
    (666, 'plano_trimestral', 'posso levar amigo pra treinar', 'seed'),

    -- comparar_planos (1)
    (667, 'comparar_planos', 'diferenca de preco entre os planos', 'seed'),

    -- plano_mensal (1)
    (668, 'plano_mensal', 'qnto e o mensal', 'seed'),

    -- taxa_matricula (1)
    (669, 'taxa_matricula', 'quanto e a matricula', 'seed'),

    -- plano_mensal (1)
    (670, 'plano_mensal', 'o mensal inclui o que', 'seed'),

    -- plano_anual (1)
    (671, 'plano_anual', 'plano de um ano', 'seed'),

    -- comparar_planos (1)
    (672, 'comparar_planos', 'dif entre os planos', 'seed'),

    -- documentos_matricula (1)
    (673, 'documentos_matricula', 'preciso levar documento', 'seed'),

    -- plano_mensal (1)
    (674, 'plano_mensal', 'vcs tem plano mensal', 'seed'),

    -- comparar_planos (2)
    (675, 'comparar_planos', 'qual plano compensa mais', 'seed'),
    (676, 'comparar_planos', 'qual a diferenca do mensal pro anual', 'seed'),

    -- plano_mensal (2)
    (677, 'plano_mensal', 'plano mensal quanto e', 'seed'),
    (678, 'plano_mensal', 'quero um plano sem fidelidade', 'seed'),

    -- documentos_matricula (1)
    (679, 'documentos_matricula', 'documentacao para matricula', 'seed'),

    -- plano_trimestral (1)
    (680, 'plano_trimestral', 'trimestral 109', 'seed'),

    -- plano_anual (1)
    (681, 'plano_anual', 'quero contratar o plano anual', 'seed'),

    -- plano_trimestral (1)
    (682, 'plano_trimestral', 'plano que da direito a levar amigo', 'seed'),

    -- plano_mensal (1)
    (683, 'plano_mensal', 'plano mensal serve pra quem esta comecando', 'seed'),

    -- plano_trimestral (1)
    (684, 'plano_trimestral', 'quero contratar o plano trimestral', 'seed'),

    -- plano_mensal (2)
    (685, 'plano_mensal', 'mensal quanto custa', 'seed'),
    (686, 'plano_mensal', 'mensal valor', 'seed'),

    -- plano_anual (1)
    (687, 'plano_anual', 'valor do plano anual', 'seed'),

    -- documentos_matricula (1)
    (688, 'documentos_matricula', 'vou me matricular o que preciso levar', 'seed'),

    -- taxa_matricula (1)
    (689, 'taxa_matricula', 'valor de entrada da academia', 'seed'),

    -- comparar_planos (1)
    (690, 'comparar_planos', 'qual plano voces indicam', 'seed'),

    -- taxa_matricula (1)
    (691, 'taxa_matricula', 'taxa pra entrar na academia', 'seed'),

    -- plano_mensal (1)
    (692, 'plano_mensal', 'me fala do plano mensal', 'seed'),

    -- taxa_matricula (1)
    (693, 'taxa_matricula', 'a matricula e paga', 'seed'),

    -- comparar_planos (1)
    (694, 'comparar_planos', 'qual plano tem mais beneficios', 'seed'),

    -- plano_mensal (2)
    (695, 'plano_mensal', 'plano mensal vale a pena', 'seed'),
    (696, 'plano_mensal', 'mensal 129', 'seed'),

    -- plano_anual (1)
    (697, 'plano_anual', 'informacoes do plano anual', 'seed'),

    -- taxa_matricula (2)
    (698, 'taxa_matricula', 'qnto custa a matricula', 'seed'),
    (699, 'taxa_matricula', 'quero isencao da taxa de matricula', 'seed'),

    -- plano_anual (1)
    (700, 'plano_anual', 'matricula gratis no anual', 'seed'),

    -- taxa_matricula (1)
    (701, 'taxa_matricula', 'taxa de matricula do plano anual', 'seed'),

    -- plano_anual (1)
    (702, 'plano_anual', 'fala sobre o plano anual', 'seed'),

    -- plano_trimestral (1)
    (703, 'plano_trimestral', 'trimestral quanto custa', 'seed'),

    -- comparar_planos (1)
    (704, 'comparar_planos', 'melhor custo beneficio', 'seed'),

    -- plano_trimestral (1)
    (705, 'plano_trimestral', 'quanto custa o plano de 3 meses', 'seed'),

    -- taxa_matricula (1)
    (706, 'taxa_matricula', 'taxa de matricula do plano trimestral', 'seed'),

    -- plano_trimestral (1)
    (707, 'plano_trimestral', 'trimestral valor', 'seed'),

    -- taxa_matricula (3)
    (708, 'taxa_matricula', 'qnto e a taxa de matricula', 'seed'),
    (709, 'taxa_matricula', 'tem isencao de matricula', 'seed'),
    (710, 'taxa_matricula', 'quanto pago no primeiro mes', 'seed'),

    -- plano_trimestral (1)
    (711, 'plano_trimestral', 'plano com reavaliacao fisica', 'seed'),

    -- plano_anual (1)
    (712, 'plano_anual', 'quero pagar um ano de academia', 'seed'),

    -- plano_trimestral (2)
    (713, 'plano_trimestral', 'plano trimestral', 'seed'),
    (714, 'plano_trimestral', 'quanto custa o plano trimestral', 'seed'),

    -- documentos_matricula (1)
    (715, 'documentos_matricula', 'meu rg serve pra matricular', 'seed'),

    -- taxa_matricula (1)
    (716, 'taxa_matricula', 'quanto de matricula', 'seed'),

    -- plano_trimestral (1)
    (717, 'plano_trimestral', 'plano trimestrall', 'seed'),

    -- comparar_planos (1)
    (718, 'comparar_planos', 'qual plano e mais vantajoso', 'seed'),

    -- plano_trimestral (1)
    (719, 'plano_trimestral', 'plano trimetral', 'seed'),

    -- documentos_matricula (1)
    (720, 'documentos_matricula', 'quais docs preciso', 'seed'),

    -- plano_trimestral (1)
    (721, 'plano_trimestral', 'vcs tem plano trimestral', 'seed'),

    -- plano_mensal (1)
    (722, 'plano_mensal', 'como funciona o plano mensal', 'seed'),

    -- documentos_matricula (1)
    (723, 'documentos_matricula', 'documentos para matricula', 'seed'),

    -- plano_anual (1)
    (724, 'plano_anual', 'me fala do plano anual', 'seed'),

    -- documentos_matricula (1)
    (725, 'documentos_matricula', 'preciso de cpf pra matricular', 'seed'),

    -- comparar_planos (1)
    (726, 'comparar_planos', 'comparacao dos planos', 'seed'),

    -- taxa_matricula (1)
    (727, 'taxa_matricula', 'matricula do trimestral', 'seed'),

    -- plano_anual (1)
    (728, 'plano_anual', 'preco do plano anual', 'seed'),

    -- plano_trimestral (1)
    (729, 'plano_trimestral', 'valor do plano trimestral', 'seed'),

    -- comparar_planos (1)
    (730, 'comparar_planos', 'compensa pagar o plano maior', 'seed'),

    -- plano_anual (1)
    (731, 'plano_anual', 'plano de 12 meses', 'seed'),

    -- taxa_matricula (1)
    (732, 'taxa_matricula', 'taxa de inscricao', 'seed'),

    -- plano_anual (1)
    (733, 'plano_anual', 'tem plano anual', 'seed'),

    -- comparar_planos (1)
    (734, 'comparar_planos', 'qual plano e melhor', 'seed'),

    -- plano_anual (1)
    (735, 'plano_anual', 'plano anaul', 'seed'),

    -- taxa_matricula (1)
    (736, 'taxa_matricula', 'no anual tem matricula', 'seed'),

    -- plano_mensal (2)
    (737, 'plano_mensal', 'informacoes do plano mensal', 'seed'),
    (738, 'plano_mensal', 'plano mensal da direito a musculacao', 'seed'),

    -- plano_anual (1)
    (739, 'plano_anual', 'como funciona o plano anual', 'seed'),

    -- documentos_matricula (1)
    (740, 'documentos_matricula', 'quais docs levar pra academia', 'seed'),

    -- taxa_matricula (1)
    (741, 'taxa_matricula', 'quanto e a taxa de matricula', 'seed'),

    -- plano_mensal (1)
    (742, 'plano_mensal', 'plano mensal inclui aulas coletivas', 'seed'),

    -- plano_anual (1)
    (743, 'plano_anual', 'no anual nao paga matricula', 'seed'),

    -- plano_trimestral (1)
    (744, 'plano_trimestral', 'qual o plano mais escolhido pelos alunos', 'seed'),

    -- plano_anual (1)
    (745, 'plano_anual', 'anual quanto custa', 'seed'),

    -- documentos_matricula (2)
    (746, 'documentos_matricula', 'documentos matricula', 'seed'),
    (747, 'documentos_matricula', 'docs pra matricula', 'seed'),

    -- taxa_matricula (1)
    (748, 'taxa_matricula', 'matricula de 59 reais', 'seed'),

    -- plano_trimestral (1)
    (749, 'plano_trimestral', 'plano trimestral inclui aulas coletivas', 'seed'),

    -- plano_anual (2)
    (750, 'plano_anual', 'qual o menor valor mensal', 'seed'),
    (751, 'plano_anual', 'o que inclui o plano anual', 'seed'),

    -- plano_trimestral (1)
    (752, 'plano_trimestral', 'qual plano os alunos mais escolhem', 'seed'),

    -- plano_anual (1)
    (753, 'plano_anual', 'plano anual', 'seed'),

    -- plano_trimestral (1)
    (754, 'plano_trimestral', 'quanto fica o trimestral por mes', 'seed'),

    -- documentos_matricula (1)
    (755, 'documentos_matricula', 'o que preciso levar pra me matricular', 'seed'),

    -- taxa_matricula (1)
    (756, 'taxa_matricula', 'matricula sem custo', 'seed'),

    -- plano_anual (1)
    (757, 'plano_anual', 'anual valor', 'seed'),

    -- documentos_matricula (2)
    (758, 'documentos_matricula', 'preciso do rg', 'seed'),
    (759, 'documentos_matricula', 'documento pra se matricular', 'seed'),

    -- comparar_planos (1)
    (760, 'comparar_planos', 'qual plano vale mais a pena', 'seed'),

    -- taxa_matricula (1)
    (761, 'taxa_matricula', 'taxa de matricla', 'seed'),

    -- plano_trimestral (2)
    (762, 'plano_trimestral', 'plano traga um amigo', 'seed'),
    (763, 'plano_trimestral', 'plano de 3 meses', 'seed'),

    -- documentos_matricula (2)
    (764, 'documentos_matricula', 'documentacao necesaria', 'seed'),
    (765, 'documentos_matricula', 'precisa de cpf', 'seed'),

    -- taxa_matricula (1)
    (766, 'taxa_matricula', 'taxa de matricula do plano mensal', 'seed'),

    -- plano_mensal (1)
    (767, 'plano_mensal', 'quanto e o mensal', 'seed'),

    -- taxa_matricula (1)
    (768, 'taxa_matricula', 'tem que pagar matricula', 'seed'),

    -- plano_anual (2)
    (769, 'plano_anual', 'plano anual tem matricula gratis', 'seed'),
    (770, 'plano_anual', 'quanto e o anual', 'seed'),

    -- plano_trimestral (1)
    (771, 'plano_trimestral', 'plano de tres meses', 'seed'),

    -- taxa_matricula (1)
    (772, 'taxa_matricula', 'matricula e gratis', 'seed'),

    -- plano_mensal (2)
    (773, 'plano_mensal', 'o plano mensal inclui avaliacao fisica', 'seed'),
    (774, 'plano_mensal', 'qnto custa o plano mensal', 'seed'),

    -- plano_anual (1)
    (775, 'plano_anual', 'qual plano e mais barato por mes', 'seed'),

    -- comparar_planos (1)
    (776, 'comparar_planos', 'qual plano e o mais completo', 'seed'),

    -- plano_trimestral (1)
    (777, 'plano_trimestral', 'plano trimestral inclui musculacao', 'seed'),

    -- plano_mensal (1)
    (778, 'plano_mensal', 'quanto custa o plano mensal', 'seed'),

    -- taxa_matricula (1)
    (779, 'taxa_matricula', 'quanto pago de matricula', 'seed'),

    -- plano_anual (1)
    (780, 'plano_anual', 'vcs tem plano anual', 'seed'),

    -- comparar_planos (1)
    (781, 'comparar_planos', 'compensa mais o mensal ou o anual', 'seed'),

    -- plano_trimestral (2)
    (782, 'plano_trimestral', 'fala sobre o plano trimestral', 'seed'),
    (783, 'plano_trimestral', 'plano trimestal', 'seed'),

    -- documentos_matricula (1)
    (784, 'documentos_matricula', 'documento com foto', 'seed'),

    -- plano_mensal (1)
    (785, 'plano_mensal', 'plano mensal inclui musculacao', 'seed'),

    -- taxa_matricula (1)
    (786, 'taxa_matricula', 'matricula sai de graca', 'seed'),

    -- comparar_planos (1)
    (787, 'comparar_planos', 'o que muda de um plano pro outro', 'seed'),

    -- plano_trimestral (2)
    (788, 'plano_trimestral', 'o trimestral inclui o que', 'seed'),
    (789, 'plano_trimestral', 'plano de 109 reais', 'seed'),

    -- documentos_matricula (1)
    (790, 'documentos_matricula', 'documentos pra matricula', 'seed'),

    -- comparar_planos (1)
    (791, 'comparar_planos', 'mensal x trimestral', 'seed'),

    -- plano_mensal (1)
    (792, 'plano_mensal', 'plano mensl', 'seed'),

    -- taxa_matricula (1)
    (793, 'taxa_matricula', 'cobram matricula', 'seed'),

    -- plano_anual (1)
    (794, 'plano_anual', 'plano anual da direito a amigo', 'seed'),

    -- plano_mensal (2)
    (795, 'plano_mensal', 'tem plano mensal', 'seed'),
    (796, 'plano_mensal', 'plano mensal tem fidelidade', 'seed'),

    -- taxa_matricula (2)
    (797, 'taxa_matricula', 'como nao pagar a matricula', 'seed'),
    (798, 'taxa_matricula', 'matricula do mensal', 'seed'),

    -- plano_mensal (1)
    (799, 'plano_mensal', 'mensal obriga a ficar quanto tempo', 'seed'),

    -- comparar_planos (1)
    (800, 'comparar_planos', 'qual o melhor plano', 'seed'),

    -- plano_anual (1)
    (801, 'plano_anual', 'plano de 89 reais', 'seed'),

    -- plano_mensal (1)
    (802, 'plano_mensal', 'quero o plano mensal', 'seed'),

    -- comparar_planos (1)
    (803, 'comparar_planos', 'o que muda entre os planos', 'seed'),

    -- plano_mensal (1)
    (804, 'plano_mensal', 'plano mensal e sem fidelidade', 'seed'),

    -- comparar_planos (1)
    (805, 'comparar_planos', 'qual plano devo escolher', 'seed'),

    -- documentos_matricula (1)
    (806, 'documentos_matricula', 'o que preciso apresentar na matricula', 'seed'),

    -- comparar_planos (1)
    (807, 'comparar_planos', 'qual e o melhor plano pra mim', 'seed'),

    -- documentos_matricula (1)
    (808, 'documentos_matricula', 'que papel preciso levar', 'seed'),

    -- plano_trimestral (1)
    (809, 'plano_trimestral', 'o que inclui o plano trimestral', 'seed'),

    -- taxa_matricula (2)
    (810, 'taxa_matricula', 'sem taxa de matricula', 'seed'),
    (811, 'taxa_matricula', 'valor da matricula', 'seed'),

    -- plano_anual (1)
    (812, 'plano_anual', 'plano anual inclui musculacao', 'seed'),

    -- plano_mensal (1)
    (813, 'plano_mensal', 'plano mensal', 'seed'),

    -- documentos_matricula (1)
    (814, 'documentos_matricula', 'precisa de documento pra entrar', 'seed'),

    -- comparar_planos (1)
    (815, 'comparar_planos', 'quanto economizo mudando de plano', 'seed'),

    -- plano_mensal (1)
    (816, 'plano_mensal', 'plano de 129 reais', 'seed'),

    -- fora_escopo (96)
    (817, 'fora_escopo', 'qual a capital da franca', 'seed'),
    (818, 'fora_escopo', 'qual o sentido da vida', 'seed'),
    (819, 'fora_escopo', 'quanto custa uma pizza grande', 'seed'),
    (820, 'fora_escopo', 'me ajuda com meu trabalho da faculdade', 'seed'),
    (821, 'fora_escopo', 'qual o valor da gasolina hoje', 'seed'),
    (822, 'fora_escopo', 'quem ganhou o jogo ontem', 'seed'),
    (823, 'fora_escopo', 'tem delivery de hamburguer', 'seed'),
    (824, 'fora_escopo', 'como fazer um site', 'seed'),
    (825, 'fora_escopo', 'qual o melhor time do brasil', 'seed'),
    (826, 'fora_escopo', 'quando joga o flamengo', 'seed'),
    (827, 'fora_escopo', 'escreve um poema', 'seed'),
    (828, 'fora_escopo', 'vai fazer sol no domingo', 'seed'),
    (829, 'fora_escopo', 'corrige meu tcc', 'seed'),
    (830, 'fora_escopo', 'como fazer cafe passado', 'seed'),
    (831, 'fora_escopo', 'qual o melhor celular pra comprar', 'seed'),
    (832, 'fora_escopo', 'onde fica o aeroporto', 'seed'),
    (833, 'fora_escopo', 'quanto e a raiz quadrada de 144', 'seed'),
    (834, 'fora_escopo', 'como fazer panqueca', 'seed'),
    (835, 'fora_escopo', 'quero pedir uma pizza', 'seed'),
    (836, 'fora_escopo', 'qual o melhor lugar pra viajar nas ferias', 'seed'),
    (837, 'fora_escopo', 'como fazer macarrao carbonara', 'seed'),
    (838, 'fora_escopo', 'como fazer uma planilha no excel', 'seed'),
    (839, 'fora_escopo', 'como fazer pao caseiro', 'seed'),
    (840, 'fora_escopo', 'qual o preco do pao', 'seed'),
    (841, 'fora_escopo', 'tem padaria aqui perto', 'seed'),
    (842, 'fora_escopo', 'quem e o dono do facebook', 'seed'),
    (843, 'fora_escopo', 'tem farmacia aberta agora', 'seed'),
    (844, 'fora_escopo', 'como faco um bolo de milho', 'seed'),
    (845, 'fora_escopo', 'qual o preco do dolar hoje', 'seed'),
    (846, 'fora_escopo', 'resolve essa conta de matematica pra mim', 'seed'),
    (847, 'fora_escopo', 'qual o melhor restaurante da cidade', 'seed'),
    (848, 'fora_escopo', 'me escreve um discurso', 'seed'),
    (849, 'fora_escopo', 'escreve uma redacao sobre meio ambiente', 'seed'),
    (850, 'fora_escopo', 'sabe alguma piada engracada', 'seed'),
    (851, 'fora_escopo', 'quem e o melhor jogador do mundo', 'seed'),
    (852, 'fora_escopo', 'quem descobriu o brasil', 'seed'),
    (853, 'fora_escopo', 'fala uma piada de portugues', 'seed'),
    (854, 'fora_escopo', 'quanto e 15 vezes 23', 'seed'),
    (855, 'fora_escopo', 'qual a cotacao do dolar', 'seed'),
    (856, 'fora_escopo', 'pode me emprestar dinheiro', 'seed'),
    (857, 'fora_escopo', 'qual o horario do filme no cinema', 'seed'),
    (858, 'fora_escopo', 'me ensina a programar em python', 'seed'),
    (859, 'fora_escopo', 'qual a previsao do tempo para amanha', 'seed'),
    (860, 'fora_escopo', 'qual a melhor receita de bolo de chocolate', 'seed'),
    (861, 'fora_escopo', 'escreve uma musica pra mim', 'seed'),
    (862, 'fora_escopo', 'vai chover hoje', 'seed'),
    (863, 'fora_escopo', 'onde fica o shopping', 'seed'),
    (864, 'fora_escopo', 'quem e o melhor jogador de todos os tempos', 'seed'),
    (865, 'fora_escopo', 'me recomenda um filme', 'seed'),
    (866, 'fora_escopo', 'faz uma poesia pra mim', 'seed'),
    (867, 'fora_escopo', 'qual o melhor carro popular', 'seed'),
    (868, 'fora_escopo', 'qual o melhor filme de todos os tempos', 'seed'),
    (869, 'fora_escopo', 'escreve um texto pra mim', 'seed'),
    (870, 'fora_escopo', 'quanto custa um iphone', 'seed'),
    (871, 'fora_escopo', 'que horas o mercado fecha', 'seed'),
    (872, 'fora_escopo', 'como fazer um bolo de cenoura', 'seed'),
    (873, 'fora_escopo', 'quanto e 2 mais 2', 'seed'),
    (874, 'fora_escopo', 'como consertar a pia da cozinha', 'seed'),
    (875, 'fora_escopo', 'quem inventou a lampada', 'seed'),
    (876, 'fora_escopo', 'vai fazer frio no fim de semana', 'seed'),
    (877, 'fora_escopo', 'toca uma musica pra mim', 'seed'),
    (878, 'fora_escopo', 'como faco arroz soltinho', 'seed'),
    (879, 'fora_escopo', 'traduz essa frase para o ingles', 'seed'),
    (880, 'fora_escopo', 'quem ganhou a copa do mundo', 'seed'),
    (881, 'fora_escopo', 'quero ver um filme hoje', 'seed'),
    (882, 'fora_escopo', 'quanto e 100 dividido por 4', 'seed'),
    (883, 'fora_escopo', 'faz o resumo desse texto pra mim', 'seed'),
    (884, 'fora_escopo', 'qual o maior rio do mundo', 'seed'),
    (885, 'fora_escopo', 'qual a melhor serie da netflix', 'seed'),
    (886, 'fora_escopo', 'me conta uma historia', 'seed'),
    (887, 'fora_escopo', 'voce gosta de gatos ou cachorros', 'seed'),
    (888, 'fora_escopo', 'quem e o artilheiro do campeonato', 'seed'),
    (889, 'fora_escopo', 'quando comeca a novela', 'seed'),
    (890, 'fora_escopo', 'me conta uma piada', 'seed'),
    (891, 'fora_escopo', 'qual a sua cor favorita', 'seed'),
    (892, 'fora_escopo', 'faz um poema pra mim', 'seed'),
    (893, 'fora_escopo', 'como investir em bitcoin', 'seed'),
    (894, 'fora_escopo', 'me indica uma serie', 'seed'),
    (895, 'fora_escopo', 'quero comprar um tenis novo', 'seed'),
    (896, 'fora_escopo', 'qual a melhor marca de celular', 'seed'),
    (897, 'fora_escopo', 'como formatar o computador', 'seed'),
    (898, 'fora_escopo', 'qual o melhor sabor de sorvete', 'seed'),
    (899, 'fora_escopo', 'como faco suco de laranja', 'seed'),
    (900, 'fora_escopo', 'qual o resultado do campeonato brasileiro', 'seed'),
    (901, 'fora_escopo', 'me fala meu horoscopo', 'seed'),
    (902, 'fora_escopo', 'quem escreveu dom casmurro', 'seed'),
    (903, 'fora_escopo', 'qual o preco da passagem de onibus', 'seed'),
    (904, 'fora_escopo', 'quanto custa um carro novo', 'seed'),
    (905, 'fora_escopo', 'como declarar imposto de renda', 'seed'),
    (906, 'fora_escopo', 'como faco brigadeiro', 'seed'),
    (907, 'fora_escopo', 'a que horas passa o onibus', 'seed'),
    (908, 'fora_escopo', 'vai ter show de sertanejo na cidade', 'seed'),
    (909, 'fora_escopo', 'como esta o transito agora', 'seed'),
    (910, 'fora_escopo', 'qual a temperatura em florianopolis', 'seed'),
    (911, 'fora_escopo', 'quem e o presidente do brasil', 'seed'),
    (912, 'fora_escopo', 'quanto custa uma passagem de aviao', 'seed'),

    -- aula_yoga (2)
    (913, 'aula_yoga', 'yoga melhora o sono', 'seed'),
    (914, 'aula_yoga', 'aula de yooga', 'seed'),

    -- aula_lutas (1)
    (915, 'aula_lutas', 'aula para aprender a se defender', 'seed'),

    -- aula_bike (1)
    (916, 'aula_bike', 'quantas calorias gasta na aula de bike', 'seed'),

    -- aula_lutas (1)
    (917, 'aula_lutas', 'aula de luta para iniciante', 'seed'),

    -- modalidades_nao_oferecidas (1)
    (918, 'modalidades_nao_oferecidas', 'pilatis', 'seed'),

    -- aula_lutas (1)
    (919, 'aula_lutas', 'quero aprender autodefesa', 'seed'),

    -- modalidades_nao_oferecidas (1)
    (920, 'modalidades_nao_oferecidas', 'crosfit', 'seed'),

    -- aula_lutas (1)
    (921, 'aula_lutas', 'boxe ou muay thai', 'seed'),

    -- aula_boxe (1)
    (922, 'aula_boxe', 'boxe mulher pode fazer', 'seed'),

    -- aula_lutas (1)
    (923, 'aula_lutas', 'que tipo de luta tem', 'seed'),

    -- modalidades_nao_oferecidas (1)
    (924, 'modalidades_nao_oferecidas', 'quero fazer pilates', 'seed'),

    -- aula_danca (1)
    (925, 'aula_danca', 'tem fit dance', 'seed'),

    -- aula_kids (1)
    (926, 'aula_kids', 'aula pra criansa', 'seed'),

    -- aula_boxe (1)
    (927, 'aula_boxe', 'boxe para emagrecer', 'seed'),

    -- aula_muay_thai (1)
    (928, 'aula_muay_thai', 'muay thai para iniciante', 'seed'),

    -- aula_yoga (2)
    (929, 'aula_yoga', 'nunca fiz yoga posso ir', 'seed'),
    (930, 'aula_yoga', 'aula de ioga', 'seed'),

    -- aula_boxe (1)
    (931, 'aula_boxe', 'preciso de luva pra aula de boxe', 'seed'),

    -- aula_danca (1)
    (932, 'aula_danca', 'quanto tempo dura a aula de danca', 'seed'),

    -- aula_muay_thai (2)
    (933, 'aula_muay_thai', 'tem muai tai', 'seed'),
    (934, 'aula_muay_thai', 'muay thai ajuda a emagrecer', 'seed'),

    -- aula_danca (1)
    (935, 'aula_danca', 'tem zumba', 'seed'),

    -- aula_boxe (1)
    (936, 'aula_boxe', 'boxe alivia a tensao', 'seed'),

    -- aula_danca (1)
    (937, 'aula_danca', 'danca alivia o estresse', 'seed'),

    -- aula_muay_thai (1)
    (938, 'aula_muay_thai', 'muay thai e pesado', 'seed'),

    -- aula_bike (1)
    (939, 'aula_bike', 'horario da rgc bike', 'seed'),

    -- aula_yoga (1)
    (940, 'aula_yoga', 'aula de yoga para iniciante', 'seed'),

    -- aula_danca (1)
    (941, 'aula_danca', 'aula de danca', 'seed'),

    -- aula_lutas (2)
    (942, 'aula_lutas', 'luta para ganhar forca', 'seed'),
    (943, 'aula_lutas', 'tem aula de lutas', 'seed'),

    -- aula_kids (1)
    (944, 'aula_kids', 'quero matricular meu filho', 'seed'),

    -- aula_lutas (1)
    (945, 'aula_lutas', 'luta e arte marcial', 'seed'),

    -- aula_yoga (1)
    (946, 'aula_yoga', 'horario da yoga', 'seed'),

    -- aula_muay_thai (1)
    (947, 'aula_muay_thai', 'muay thai fortalece as pernas', 'seed'),

    -- aula_boxe (1)
    (948, 'aula_boxe', 'o que e o boxe', 'seed'),

    -- aula_bike (1)
    (949, 'aula_bike', 'quanto tempo dura o spinning', 'seed'),

    -- aula_lutas (1)
    (950, 'aula_lutas', 'defesa pessoal', 'seed'),

    -- aula_bike (1)
    (951, 'aula_bike', 'o que e a rgc bike', 'seed'),

    -- aula_yoga (1)
    (952, 'aula_yoga', 'yoga para ganhar flexibilidade', 'seed'),

    -- modalidades_nao_oferecidas (1)
    (953, 'modalidades_nao_oferecidas', 'vcs tem pilates ou natacao', 'seed'),

    -- aula_boxe (1)
    (954, 'aula_boxe', 'aula de boxe tem contato', 'seed'),

    -- aula_lutas (1)
    (955, 'aula_lutas', 'que lutas tem', 'seed'),

    -- aula_muay_thai (1)
    (956, 'aula_muay_thai', 'muay thai para ganhar forca', 'seed'),

    -- aula_yoga (1)
    (957, 'aula_yoga', 'yoga ajuda a dormir', 'seed'),

    -- aula_lutas (1)
    (958, 'aula_lutas', 'tem autodefesa', 'seed'),

    -- aula_muay_thai (1)
    (959, 'aula_muay_thai', 'muay thai tem contato', 'seed'),

    -- aula_yoga (1)
    (960, 'aula_yoga', 'tem aula de yoga', 'seed'),

    -- aula_bike (3)
    (961, 'aula_bike', 'aula de bike e cardio', 'seed'),
    (962, 'aula_bike', 'tem bike na academia', 'seed'),
    (963, 'aula_bike', 'aula de bike para iniciante', 'seed'),

    -- aula_danca (1)
    (964, 'aula_danca', 'horario do fit dance', 'seed'),

    -- aula_muay_thai (1)
    (965, 'aula_muay_thai', 'horario da aula de muay thai', 'seed'),

    -- aula_yoga (2)
    (966, 'aula_yoga', 'ioga', 'seed'),
    (967, 'aula_yoga', 'tem yoja', 'seed'),

    -- modalidades_nao_oferecidas (1)
    (968, 'modalidades_nao_oferecidas', 'tem pilates na academia', 'seed'),

    -- aula_boxe (2)
    (969, 'aula_boxe', 'quanto tempo dura o boxe', 'seed'),
    (970, 'aula_boxe', 'nunca fiz boxe posso ir', 'seed'),

    -- aula_danca (1)
    (971, 'aula_danca', 'tem fitdance', 'seed'),

    -- aula_bike (1)
    (972, 'aula_bike', 'aula de spining', 'seed'),

    -- aula_danca (1)
    (973, 'aula_danca', 'aula de danssa', 'seed'),

    -- aula_lutas (1)
    (974, 'aula_lutas', 'tem alguma luta', 'seed'),

    -- aula_danca (1)
    (975, 'aula_danca', 'aula de dancar', 'seed'),

    -- aula_boxe (1)
    (976, 'aula_boxe', 'aula de boxe tem soco', 'seed'),

    -- aula_kids (1)
    (977, 'aula_kids', 'tem kids', 'seed'),

    -- aula_boxe (1)
    (978, 'aula_boxe', 'horario da aula de boxe', 'seed'),

    -- modalidades_nao_oferecidas (1)
    (979, 'modalidades_nao_oferecidas', 'tem crosfit', 'seed'),

    -- aula_bike (2)
    (980, 'aula_bike', 'quantos minutos tem a aula de bike', 'seed'),
    (981, 'aula_bike', 'aula de bicicleta', 'seed'),

    -- aula_danca (1)
    (982, 'aula_danca', 'tem aula de danca', 'seed'),

    -- aula_bike (1)
    (983, 'aula_bike', 'horario do spinning', 'seed'),

    -- aula_lutas (1)
    (984, 'aula_lutas', 'quais lutas tem na rgc', 'seed'),

    -- aula_muay_thai (1)
    (985, 'aula_muay_thai', 'aula de muay thai para autodefesa', 'seed'),

    -- aula_danca (1)
    (986, 'aula_danca', 'aula de danca para iniciante', 'seed'),

    -- aula_kids (1)
    (987, 'aula_kids', 'atividade em familia', 'seed'),

    -- aula_muay_thai (1)
    (988, 'aula_muay_thai', 'muay thai desenvolve disciplina', 'seed'),

    -- aula_lutas (2)
    (989, 'aula_lutas', 'quero fazer uma luta', 'seed'),
    (990, 'aula_lutas', 'horario das lutas', 'seed'),

    -- aula_kids (2)
    (991, 'aula_kids', 'tem aula pra crianca', 'seed'),
    (992, 'aula_kids', 'aula infantil', 'seed'),

    -- aula_bike (3)
    (993, 'aula_bike', 'tem aula de bicicleta', 'seed'),
    (994, 'aula_bike', 'aula de bike machuca as articulacoes', 'seed'),
    (995, 'aula_bike', 'horario da aula de bike', 'seed'),

    -- aula_danca (1)
    (996, 'aula_danca', 'nao sei dancar posso fazer a aula', 'seed'),

    -- modalidades_nao_oferecidas (1)
    (997, 'modalidades_nao_oferecidas', 'quanto custa a natacao', 'seed'),

    -- aula_lutas (1)
    (998, 'aula_lutas', 'aula de autodefesa', 'seed'),

    -- modalidades_nao_oferecidas (1)
    (999, 'modalidades_nao_oferecidas', 'tem natasao', 'seed'),

    -- aula_muay_thai (1)
    (1000, 'aula_muay_thai', 'muaythai', 'seed'),

    -- aula_kids (1)
    (1001, 'aula_kids', 'horario da rgc kids', 'seed'),

    -- modalidades_nao_oferecidas (2)
    (1002, 'modalidades_nao_oferecidas', 'natasao', 'seed'),
    (1003, 'modalidades_nao_oferecidas', 'tem aula de natacao', 'seed'),

    -- aula_lutas (1)
    (1004, 'aula_lutas', 'quais lutas tem na academia', 'seed'),

    -- aula_bike (1)
    (1005, 'aula_bike', 'como e a aula de bike', 'seed'),

    -- aula_muay_thai (1)
    (1006, 'aula_muay_thai', 'como e a aula de muay thai', 'seed'),

    -- modalidades_nao_oferecidas (2)
    (1007, 'modalidades_nao_oferecidas', 'quero fazer crossfit', 'seed'),
    (1008, 'modalidades_nao_oferecidas', 'tem box de crossfit', 'seed'),

    -- aula_bike (1)
    (1009, 'aula_bike', 'aula de bkie', 'seed'),

    -- aula_danca (1)
    (1010, 'aula_danca', 'quanto tempo dura a fitdance', 'seed'),

    -- aula_boxe (2)
    (1011, 'aula_boxe', 'boxe melhora a agilidade', 'seed'),
    (1012, 'aula_boxe', 'aula de boxe', 'seed'),

    -- aula_danca (1)
    (1013, 'aula_danca', 'como e a aula de fitdance', 'seed'),

    -- aula_bike (1)
    (1014, 'aula_bike', 'bike ajuda a emagrecer', 'seed'),

    -- aula_kids (1)
    (1015, 'aula_kids', 'tem aula pra minha filha', 'seed'),

    -- modalidades_nao_oferecidas (1)
    (1016, 'modalidades_nao_oferecidas', 'crossfit esta incluido no plano', 'seed'),

    -- aula_muay_thai (1)
    (1017, 'aula_muay_thai', 'muay thai e so pra homem', 'seed'),

    -- aula_lutas (1)
    (1018, 'aula_lutas', 'luta para emagrecer', 'seed'),

    -- aula_yoga (1)
    (1019, 'aula_yoga', 'tem yoga', 'seed'),

    -- aula_kids (1)
    (1020, 'aula_kids', 'tem aula infantil', 'seed'),

    -- aula_yoga (1)
    (1021, 'aula_yoga', 'horario da aula de yoga', 'seed'),

    -- aula_boxe (1)
    (1022, 'aula_boxe', 'como e a aula de boxe', 'seed'),

    -- modalidades_nao_oferecidas (1)
    (1023, 'modalidades_nao_oferecidas', 'horario da aula de crossfit', 'seed'),

    -- aula_kids (1)
    (1024, 'aula_kids', 'crianca pode fazer academia', 'seed'),

    -- modalidades_nao_oferecidas (2)
    (1025, 'modalidades_nao_oferecidas', 'horario do crossfit', 'seed'),
    (1026, 'modalidades_nao_oferecidas', 'horario da natacao', 'seed'),

    -- aula_boxe (1)
    (1027, 'aula_boxe', 'boxe e so pra homem', 'seed'),

    -- aula_lutas (1)
    (1028, 'aula_lutas', 'tem luta na academia', 'seed'),

    -- aula_muay_thai (1)
    (1029, 'aula_muay_thai', 'tailandes', 'seed'),

    -- aula_boxe (1)
    (1030, 'aula_boxe', 'quero lutar boxe', 'seed'),

    -- aula_yoga (1)
    (1031, 'aula_yoga', 'beneficios da yoga', 'seed'),

    -- aula_muay_thai (1)
    (1032, 'aula_muay_thai', 'muay thai na academia', 'seed'),

    -- aula_lutas (1)
    (1033, 'aula_lutas', 'luta para descarregar o estresse', 'seed'),

    -- aula_kids (1)
    (1034, 'aula_kids', 'o que e a rgc kids', 'seed'),

    -- aula_bike (1)
    (1035, 'aula_bike', 'aula de bike', 'seed'),

    -- aula_danca (1)
    (1036, 'aula_danca', 'aula de danca emagrece', 'seed'),

    -- modalidades_nao_oferecidas (1)
    (1037, 'modalidades_nao_oferecidas', 'tem crossfit na academia', 'seed'),

    -- aula_bike (1)
    (1038, 'aula_bike', 'spinning', 'seed'),

    -- aula_danca (1)
    (1039, 'aula_danca', 'quero emagrecer dancando', 'seed'),

    -- modalidades_nao_oferecidas (1)
    (1040, 'modalidades_nao_oferecidas', 'horario da aula de natacao', 'seed'),

    -- aula_kids (1)
    (1041, 'aula_kids', 'rgc kidz', 'seed'),

    -- aula_lutas (1)
    (1042, 'aula_lutas', 'quais lutas voces tem', 'seed'),

    -- aula_danca (1)
    (1043, 'aula_danca', 'o que e fitdance', 'seed'),

    -- aula_kids (1)
    (1044, 'aula_kids', 'quero colocar meu filho na aula', 'seed'),

    -- aula_yoga (1)
    (1045, 'aula_yoga', 'yoga para aliviar o estresse', 'seed'),

    -- modalidades_nao_oferecidas (2)
    (1046, 'modalidades_nao_oferecidas', 'tem natacao', 'seed'),
    (1047, 'modalidades_nao_oferecidas', 'horario da aula de pilates', 'seed'),

    -- aula_lutas (1)
    (1048, 'aula_lutas', 'tem aula de defesa pessoal', 'seed'),

    -- aula_yoga (1)
    (1049, 'aula_yoga', 'yoga e so pra mulher', 'seed'),

    -- aula_kids (2)
    (1050, 'aula_kids', 'tem treino para criancas', 'seed'),
    (1051, 'aula_kids', 'academia em familia', 'seed'),

    -- modalidades_nao_oferecidas (1)
    (1052, 'modalidades_nao_oferecidas', 'aula de pilates', 'seed'),

    -- aula_bike (1)
    (1053, 'aula_bike', 'aula de bike emagrece', 'seed'),

    -- modalidades_nao_oferecidas (1)
    (1054, 'modalidades_nao_oferecidas', 'quero fazer natacao', 'seed'),

    -- aula_danca (1)
    (1055, 'aula_danca', 'aula de danca coordenacao motora', 'seed'),

    -- aula_kids (2)
    (1056, 'aula_kids', 'como e a aula kids', 'seed'),
    (1057, 'aula_kids', 'quero matricular minha filha', 'seed'),

    -- aula_lutas (1)
    (1058, 'aula_lutas', 'aula de artes marciais', 'seed'),

    -- aula_danca (1)
    (1059, 'aula_danca', 'fitdance', 'seed'),

    -- aula_yoga (1)
    (1060, 'aula_yoga', 'yoga melhora a postura', 'seed'),

    -- aula_boxe (1)
    (1061, 'aula_boxe', 'quero aprender boxe', 'seed'),

    -- aula_lutas (1)
    (1062, 'aula_lutas', 'tem aula de luta', 'seed'),

    -- aula_bike (1)
    (1063, 'aula_bike', 'nunca fiz bike posso ir', 'seed'),

    -- aula_kids (2)
    (1064, 'aula_kids', 'qual a faixa etaria da aula kids', 'seed'),
    (1065, 'aula_kids', 'rgc kids', 'seed'),

    -- aula_boxe (1)
    (1066, 'aula_boxe', 'tem aula de boxe', 'seed'),

    -- aula_kids (1)
    (1067, 'aula_kids', 'tem atividade pra crianca', 'seed'),

    -- aula_bike (1)
    (1068, 'aula_bike', 'aula da rgc bike', 'seed'),

    -- aula_yoga (1)
    (1069, 'aula_yoga', 'tem yoga na academia', 'seed'),

    -- aula_kids (2)
    (1070, 'aula_kids', 'tem academia infantil', 'seed'),
    (1071, 'aula_kids', 'aula de kids', 'seed'),

    -- aula_muay_thai (1)
    (1072, 'aula_muay_thai', 'luta tailandesa', 'seed'),

    -- aula_boxe (1)
    (1073, 'aula_boxe', 'boxe tonifica', 'seed'),

    -- aula_muay_thai (1)
    (1074, 'aula_muay_thai', 'muay thai aumenta a confianca', 'seed'),

    -- aula_boxe (1)
    (1075, 'aula_boxe', 'aula de boxe pra definicao muscular', 'seed'),

    -- aula_kids (1)
    (1076, 'aula_kids', 'tem aula pra criansas', 'seed'),

    -- aula_yoga (1)
    (1077, 'aula_yoga', 'yoga serve pra que', 'seed'),

    -- aula_muay_thai (2)
    (1078, 'aula_muay_thai', 'muay thai para emagrecer', 'seed'),
    (1079, 'aula_muay_thai', 'horario do muay thai', 'seed'),

    -- aula_boxe (1)
    (1080, 'aula_boxe', 'tem boxi', 'seed'),

    -- aula_lutas (1)
    (1081, 'aula_lutas', 'tem aula pra aprender a brigar', 'seed'),

    -- aula_bike (1)
    (1082, 'aula_bike', 'como funciona o spinning', 'seed'),

    -- aula_yoga (1)
    (1083, 'aula_yoga', 'yoga para relaxar', 'seed'),

    -- aula_kids (1)
    (1084, 'aula_kids', 'tem aula para criancas', 'seed'),

    -- aula_danca (1)
    (1085, 'aula_danca', 'horario da fitdance', 'seed'),

    -- modalidades_nao_oferecidas (1)
    (1086, 'modalidades_nao_oferecidas', 'tem pilates', 'seed'),

    -- aula_lutas (1)
    (1087, 'aula_lutas', 'tem artes marciais', 'seed'),

    -- aula_yoga (1)
    (1088, 'aula_yoga', 'yoga pra mobilidade', 'seed'),

    -- aula_kids (1)
    (1089, 'aula_kids', 'a partir de que idade pode fazer a aula kids', 'seed'),

    -- aula_lutas (2)
    (1090, 'aula_lutas', 'quanto tempo duram as lutas', 'seed'),
    (1091, 'aula_lutas', 'tem alguma arte marcial', 'seed'),

    -- aula_yoga (1)
    (1092, 'aula_yoga', 'como e a aula de yoga', 'seed'),

    -- aula_lutas (1)
    (1093, 'aula_lutas', 'tem luta', 'seed'),

    -- aula_bike (1)
    (1094, 'aula_bike', 'tem spinning', 'seed'),

    -- aula_kids (1)
    (1095, 'aula_kids', 'tem aula pro meu filho', 'seed'),

    -- modalidades_nao_oferecidas (1)
    (1096, 'modalidades_nao_oferecidas', 'tem natacao na academia', 'seed'),

    -- aula_boxe (1)
    (1097, 'aula_boxe', 'tem boxe', 'seed'),

    -- aula_muay_thai (1)
    (1098, 'aula_muay_thai', 'quanto tempo dura o muay thai', 'seed'),

    -- aula_danca (1)
    (1099, 'aula_danca', 'precisa saber dancar', 'seed'),

    -- modalidades_nao_oferecidas (1)
    (1100, 'modalidades_nao_oferecidas', 'tem pilatis', 'seed'),

    -- aula_bike (1)
    (1101, 'aula_bike', 'aula de bike melhora o folego', 'seed'),

    -- aula_yoga (1)
    (1102, 'aula_yoga', 'yoga para flexibilidade', 'seed'),

    -- aula_kids (1)
    (1103, 'aula_kids', 'horario da aula kids', 'seed'),

    -- aula_yoga (1)
    (1104, 'aula_yoga', 'yga', 'seed'),

    -- aula_kids (1)
    (1105, 'aula_kids', 'levar meu filho na academia', 'seed'),

    -- aula_lutas (1)
    (1106, 'aula_lutas', 'tem algum tipo de luta', 'seed'),

    -- aula_kids (2)
    (1107, 'aula_kids', 'qual a idade minima da aula kids', 'seed'),
    (1108, 'aula_kids', 'quanto tempo dura a aula kids', 'seed'),

    -- modalidades_nao_oferecidas (1)
    (1109, 'modalidades_nao_oferecidas', 'pilates esta incluido no plano', 'seed'),

    -- aula_muay_thai (1)
    (1110, 'aula_muay_thai', 'tem muay thai', 'seed'),

    -- aula_danca (1)
    (1111, 'aula_danca', 'horario da aula de danca', 'seed'),

    -- aula_yoga (1)
    (1112, 'aula_yoga', 'yoga', 'seed'),

    -- aula_kids (1)
    (1113, 'aula_kids', 'tem aula kids', 'seed'),

    -- aula_muay_thai (1)
    (1114, 'aula_muay_thai', 'muai thai', 'seed'),

    -- aula_yoga (1)
    (1115, 'aula_yoga', 'preciso ser flexivel pra fazer yoga', 'seed'),

    -- aula_lutas (1)
    (1116, 'aula_lutas', 'aula de luta mulher pode fazer', 'seed'),

    -- aula_bike (1)
    (1117, 'aula_bike', 'tem aula de bike', 'seed'),

    -- aula_danca (2)
    (1118, 'aula_danca', 'fit danse', 'seed'),
    (1119, 'aula_danca', 'tem aula de dansa', 'seed'),

    -- aula_muay_thai (1)
    (1120, 'aula_muay_thai', 'tem muay tai', 'seed'),

    -- aula_yoga (1)
    (1121, 'aula_yoga', 'yoga ajuda na respiracao', 'seed'),

    -- aula_lutas (1)
    (1122, 'aula_lutas', 'quero aprender a lutar', 'seed'),

    -- aula_kids (1)
    (1123, 'aula_kids', 'que idade pode a rgc kids', 'seed'),

    -- modalidades_nao_oferecidas (1)
    (1124, 'modalidades_nao_oferecidas', 'quanto custa o crossfit', 'seed'),

    -- aula_bike (1)
    (1125, 'aula_bike', 'a aula de bike queima caloria', 'seed'),

    -- aula_muay_thai (1)
    (1126, 'aula_muay_thai', 'muay thai tem chute', 'seed'),

    -- aula_danca (1)
    (1127, 'aula_danca', 'aula com musica', 'seed'),

    -- aula_bike (1)
    (1128, 'aula_bike', 'rgc bik', 'seed'),

    -- modalidades_nao_oferecidas (1)
    (1129, 'modalidades_nao_oferecidas', 'tem aula de pilates', 'seed'),

    -- aula_muay_thai (1)
    (1130, 'aula_muay_thai', 'quero aprender muay thai', 'seed'),

    -- aula_bike (1)
    (1131, 'aula_bike', 'horario de spinning', 'seed'),

    -- aula_boxe (1)
    (1132, 'aula_boxe', 'boxe para tonificar bracos', 'seed'),

    -- modalidades_nao_oferecidas (2)
    (1133, 'modalidades_nao_oferecidas', 'horario do pilates', 'seed'),
    (1134, 'modalidades_nao_oferecidas', 'crossfit', 'seed'),

    -- aula_boxe (1)
    (1135, 'aula_boxe', 'boxe para iniciante', 'seed'),

    -- aula_bike (1)
    (1136, 'aula_bike', 'tem bike', 'seed'),

    -- modalidades_nao_oferecidas (1)
    (1137, 'modalidades_nao_oferecidas', 'natacao esta incluida no plano', 'seed'),

    -- aula_danca (1)
    (1138, 'aula_danca', 'tem danca na academia', 'seed'),

    -- aula_yoga (1)
    (1139, 'aula_yoga', 'o que e yoga', 'seed'),

    -- modalidades_nao_oferecidas (2)
    (1140, 'modalidades_nao_oferecidas', 'quanto custa o pilates', 'seed'),
    (1141, 'modalidades_nao_oferecidas', 'tem aula de crossfit', 'seed'),

    -- aula_muay_thai (1)
    (1142, 'aula_muay_thai', 'muay tai', 'seed'),

    -- aula_boxe (1)
    (1143, 'aula_boxe', 'boxe para definir o corpo', 'seed'),

    -- aula_yoga (1)
    (1144, 'aula_yoga', 'yoga reduz o estresse', 'seed'),

    -- aula_kids (1)
    (1145, 'aula_kids', 'aula kids', 'seed'),

    -- aula_bike (1)
    (1146, 'aula_bike', 'bike cardiovascular', 'seed'),

    -- aula_danca (3)
    (1147, 'aula_danca', 'fitdence', 'seed'),
    (1148, 'aula_danca', 'como e a aula de danca', 'seed'),
    (1149, 'aula_danca', 'aula de fitdance', 'seed'),

    -- aula_yoga (1)
    (1150, 'aula_yoga', 'yoga e puxado', 'seed'),

    -- aula_boxe (1)
    (1151, 'aula_boxe', 'aula de boxe e pesada', 'seed'),

    -- aula_bike (1)
    (1152, 'aula_bike', 'aula de pedal', 'seed'),

    -- aula_boxe (1)
    (1153, 'aula_boxe', 'horario do boxe', 'seed'),

    -- aula_lutas (1)
    (1154, 'aula_lutas', 'tem arte marcial', 'seed'),

    -- aula_boxe (1)
    (1155, 'aula_boxe', 'quanto tempo dura a aula de boxe', 'seed'),

    -- aula_yoga (1)
    (1156, 'aula_yoga', 'quero uma aula pra relaxar', 'seed'),

    -- aula_danca (1)
    (1157, 'aula_danca', 'aula de danca para emagrecer', 'seed'),

    -- modalidades_nao_oferecidas (1)
    (1158, 'modalidades_nao_oferecidas', 'voces tem crossfit ou pilates', 'seed'),

    -- aula_danca (1)
    (1159, 'aula_danca', 'fitdanse', 'seed'),

    -- aula_boxe (1)
    (1160, 'aula_boxe', 'boxe', 'seed'),

    -- aula_kids (1)
    (1161, 'aula_kids', 'aula da rgc kids', 'seed'),

    -- aula_lutas (1)
    (1162, 'aula_lutas', 'quais artes marciais voces tem', 'seed'),

    -- aula_boxe (1)
    (1163, 'aula_boxe', 'boxe para descarregar o estresse', 'seed'),

    -- aula_yoga (1)
    (1164, 'aula_yoga', 'aula de yoga', 'seed'),

    -- aula_lutas (1)
    (1165, 'aula_lutas', 'tem luta pra mulher', 'seed'),

    -- aula_yoga (1)
    (1166, 'aula_yoga', 'horario da ioga', 'seed'),

    -- aula_muay_thai (1)
    (1167, 'aula_muay_thai', 'muay thai emagrece', 'seed'),

    -- aula_danca (1)
    (1168, 'aula_danca', 'danca ajuda a emagrecer', 'seed'),

    -- aula_boxe (1)
    (1169, 'aula_boxe', 'aula de boxi', 'seed'),

    -- aula_kids (1)
    (1170, 'aula_kids', 'meu filho pode treinar', 'seed'),

    -- aula_muay_thai (1)
    (1171, 'aula_muay_thai', 'muay thai mulher pode fazer', 'seed'),

    -- aula_bike (1)
    (1172, 'aula_bike', 'rgc bike', 'seed'),

    -- aula_kids (1)
    (1173, 'aula_kids', 'tem algo pra crianca', 'seed'),

    -- aula_bike (1)
    (1174, 'aula_bike', 'quanto tempo dura a aula de bike', 'seed'),

    -- aula_muay_thai (1)
    (1175, 'aula_muay_thai', 'muay thai', 'seed'),

    -- aula_kids (1)
    (1176, 'aula_kids', 'tem aula para adolescentes', 'seed'),

    -- aula_yoga (1)
    (1177, 'aula_yoga', 'quanto tempo dura a yoga', 'seed'),

    -- aula_kids (1)
    (1178, 'aula_kids', 'criancas podem treinar', 'seed'),

    -- aula_yoga (1)
    (1179, 'aula_yoga', 'tem ioga', 'seed'),

    -- aula_danca (1)
    (1180, 'aula_danca', 'fit dance', 'seed'),

    -- aula_bike (1)
    (1181, 'aula_bike', 'bike faz mal pro joelho', 'seed'),

    -- aula_danca (1)
    (1182, 'aula_danca', 'aula de danca divertida', 'seed'),

    -- aula_muay_thai (1)
    (1183, 'aula_muay_thai', 'nunca fiz muay thai posso ir', 'seed'),

    -- aula_boxe (1)
    (1184, 'aula_boxe', 'tem boxe na academia', 'seed'),

    -- aula_muay_thai (2)
    (1185, 'aula_muay_thai', 'quanto tempo dura a aula de muay thai', 'seed'),
    (1186, 'aula_muay_thai', 'o que e muay thai', 'seed'),

    -- modalidades_nao_oferecidas (1)
    (1187, 'modalidades_nao_oferecidas', 'natacao para bebes', 'seed'),

    -- aula_yoga (1)
    (1188, 'aula_yoga', 'tem aula pra relaxar', 'seed'),

    -- aula_kids (1)
    (1189, 'aula_kids', 'meu filho pode fazer aula', 'seed'),

    -- modalidades_nao_oferecidas (1)
    (1190, 'modalidades_nao_oferecidas', 'natacao para criancas', 'seed'),

    -- aula_kids (1)
    (1191, 'aula_kids', 'atividade para filho pequeno', 'seed'),

    -- aula_muay_thai (1)
    (1192, 'aula_muay_thai', 'tem muaythai', 'seed'),

    -- aula_yoga (1)
    (1193, 'aula_yoga', 'quanto tempo dura a aula de yoga', 'seed'),

    -- aula_boxe (1)
    (1194, 'aula_boxe', 'boxe ajuda a emagrecer', 'seed'),

    -- aula_bike (1)
    (1195, 'aula_bike', 'aula de bike e pesada', 'seed'),

    -- aula_boxe (1)
    (1196, 'aula_boxe', 'boxe emagrece', 'seed'),

    -- aula_bike (1)
    (1197, 'aula_bike', 'bike indoor', 'seed'),

    -- equipamentos (1)
    (1198, 'equipamentos', 'com que frequencia fazem manutencao', 'seed'),

    -- horario_fim_semana_feriado (4)
    (1199, 'horario_fim_semana_feriado', 'horario de feriado', 'seed'),
    (1200, 'horario_fim_semana_feriado', 'horario em feriados', 'seed'),
    (1201, 'horario_fim_semana_feriado', 'horario do sabado', 'seed'),
    (1202, 'horario_fim_semana_feriado', 'que horas fecha no sabado', 'seed'),

    -- equipamentos (1)
    (1203, 'equipamentos', 'as maquinas sao boas', 'seed'),

    -- horario_fim_semana_feriado (1)
    (1204, 'horario_fim_semana_feriado', 'domingo a academia funciona', 'seed'),

    -- equipamentos (3)
    (1205, 'equipamentos', 'como sao os equipamentos', 'seed'),
    (1206, 'equipamentos', 'tem aparelhos novos', 'seed'),
    (1207, 'equipamentos', 'equipamentos novos', 'seed'),

    -- horario_fim_semana_feriado (3)
    (1208, 'horario_fim_semana_feriado', 'abre em feriado', 'seed'),
    (1209, 'horario_fim_semana_feriado', 'abre sabado', 'seed'),
    (1210, 'horario_fim_semana_feriado', 'sabado funciona ate que horas', 'seed'),

    -- equipamentos (2)
    (1211, 'equipamentos', 'os aparelhos sao novos', 'seed'),
    (1212, 'equipamentos', 'equipamentos da muscuculacao', 'seed'),

    -- horario_fim_semana_feriado (1)
    (1213, 'horario_fim_semana_feriado', 'voces abrem no sabado', 'seed'),

    -- equipamentos (3)
    (1214, 'equipamentos', 'manutencao dos aparelhos', 'seed'),
    (1215, 'equipamentos', 'aparelhos da academia', 'seed'),
    (1216, 'equipamentos', 'tem fila no horario de pico', 'seed'),

    -- horario_fim_semana_feriado (3)
    (1217, 'horario_fim_semana_feriado', 'horario de fim de semana', 'seed'),
    (1218, 'horario_fim_semana_feriado', 'horario do final de semana', 'seed'),
    (1219, 'horario_fim_semana_feriado', 'funciona no feriado', 'seed'),

    -- equipamentos (1)
    (1220, 'equipamentos', 'manutencao dos equipamentos', 'seed'),

    -- horario_fim_semana_feriado (1)
    (1221, 'horario_fim_semana_feriado', 'final de semana abre', 'seed'),

    -- equipamentos (2)
    (1222, 'equipamentos', 'tem equipamento quebrado', 'seed'),
    (1223, 'equipamentos', 'aparelhos modernos', 'seed'),

    -- horario_fim_semana_feriado (1)
    (1224, 'horario_fim_semana_feriado', 'funciona no ano novo', 'seed'),

    -- equipamentos (2)
    (1225, 'equipamentos', 'tem fila nos aparelhos', 'seed'),
    (1226, 'equipamentos', 'aparelhos quebrados', 'seed'),

    -- horario_fim_semana_feriado (2)
    (1227, 'horario_fim_semana_feriado', 'horario de domingo', 'seed'),
    (1228, 'horario_fim_semana_feriado', 'feriado nacional funciona', 'seed'),

    -- equipamentos (2)
    (1229, 'equipamentos', 'manutencao das maquinas', 'seed'),
    (1230, 'equipamentos', 'horario de pico', 'seed'),

    -- horario_fim_semana_feriado (1)
    (1231, 'horario_fim_semana_feriado', 'tem academia no final de semana', 'seed'),

    -- equipamentos (1)
    (1232, 'equipamentos', 'como sao os equipamentos da academia', 'seed'),

    -- horario_fim_semana_feriado (1)
    (1233, 'horario_fim_semana_feriado', 'horario de sabado', 'seed'),

    -- equipamentos (2)
    (1234, 'equipamentos', 'equipamentos ruins', 'seed'),
    (1235, 'equipamentos', 'maquinas renovadas', 'seed'),

    -- horario_fim_semana_feriado (1)
    (1236, 'horario_fim_semana_feriado', 'sabado a academia funciona', 'seed'),

    -- equipamentos (2)
    (1237, 'equipamentos', 'fica muito cheia no horario de pico', 'seed'),
    (1238, 'equipamentos', 'horario de pico tem fila', 'seed'),

    -- horario_fim_semana_feriado (2)
    (1239, 'horario_fim_semana_feriado', 'abre no fim de semana', 'seed'),
    (1240, 'horario_fim_semana_feriado', 'que horas abre no sabado', 'seed'),

    -- equipamentos (5)
    (1241, 'equipamentos', 'tem maquinas novas', 'seed'),
    (1242, 'equipamentos', 'aparelhos de musculacao', 'seed'),
    (1243, 'equipamentos', 'os equipamentos sao novos', 'seed'),
    (1244, 'equipamentos', 'equipamentus', 'seed'),
    (1245, 'equipamentos', 'equipamentos modernos', 'seed'),

    -- horario_fim_semana_feriado (3)
    (1246, 'horario_fim_semana_feriado', 'abre no natal', 'seed'),
    (1247, 'horario_fim_semana_feriado', 'sabado tem academia', 'seed'),
    (1248, 'horario_fim_semana_feriado', 'horario do domingo', 'seed'),

    -- equipamentos (1)
    (1249, 'equipamentos', 'aparelhos novos', 'seed'),

    -- horario_fim_semana_feriado (1)
    (1250, 'horario_fim_semana_feriado', 'sabado domingo e feriado', 'seed'),

    -- equipamentos (1)
    (1251, 'equipamentos', 'a academia fica lotada', 'seed'),

    -- horario_fim_semana_feriado (3)
    (1252, 'horario_fim_semana_feriado', 'horario do fim de semana', 'seed'),
    (1253, 'horario_fim_semana_feriado', 'voces abrem no domingo', 'seed'),
    (1254, 'horario_fim_semana_feriado', 'domingo tem academia', 'seed'),

    -- equipamentos (1)
    (1255, 'equipamentos', 'maquinas da academia', 'seed'),

    -- horario_fim_semana_feriado (2)
    (1256, 'horario_fim_semana_feriado', 'feriado tem academia', 'seed'),
    (1257, 'horario_fim_semana_feriado', 'abre na sexta feira santa', 'seed'),

    -- equipamentos (2)
    (1258, 'equipamentos', 'tem aparelho quebrado', 'seed'),
    (1259, 'equipamentos', 'fazem manutencao nos aparelhos', 'seed'),

    -- horario_fim_semana_feriado (3)
    (1260, 'horario_fim_semana_feriado', 'abrem no feriado', 'seed'),
    (1261, 'horario_fim_semana_feriado', 'funciona no fim de semana', 'seed'),
    (1262, 'horario_fim_semana_feriado', 'final de semana funciona', 'seed'),

    -- equipamentos (4)
    (1263, 'equipamentos', 'a academia fica cheia', 'seed'),
    (1264, 'equipamentos', 'tem muita gente nos aparelhos', 'seed'),
    (1265, 'equipamentos', 'equipamentos da academia', 'seed'),
    (1266, 'equipamentos', 'tem fila nas maquinas', 'seed'),

    -- horario_fim_semana_feriado (1)
    (1267, 'horario_fim_semana_feriado', 'abre domingo', 'seed'),

    -- equipamentos (1)
    (1268, 'equipamentos', 'quais equipamentos tem', 'seed'),

    -- horario_fim_semana_feriado (1)
    (1269, 'horario_fim_semana_feriado', 'ate que horas funciona no sabado', 'seed'),

    -- equipamentos (2)
    (1270, 'equipamentos', 'as maquinas sao novas', 'seed'),
    (1271, 'equipamentos', 'tem fila pra usar os aparelhos', 'seed'),

    -- horario_fim_semana_feriado (1)
    (1272, 'horario_fim_semana_feriado', 'domingo funciona', 'seed'),

    -- equipamentos (1)
    (1273, 'equipamentos', 'maquinas novas', 'seed')
) AS v(ord, codigo, texto, origem)
JOIN intents i ON i.codigo = v.codigo
ORDER BY v.ord;

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
