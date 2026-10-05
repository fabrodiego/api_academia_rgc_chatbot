# Academia RGC Training — Chatbot

Chatbot de atendimento desenvolvido em **Java (Spring Boot)**, com classificação
de intenção por **TF-IDF e similaridade de cosseno** implementados nativamente
(sem dependência de serviço de PLN pronto para o mecanismo central de decisão).

## Arquitetura

```
Usuário → POST /api/chat
   → Tokenizer            (normalização: minúsculas, remoção de acentos/pontuação)
   → StopWordsFilter       (remoção de palavras sem valor discriminativo)
   → TfIdfVectorizer       (vetorização no espaço do corpus de treino)
   → CosineSimilarity      (comparação com as frases de treino)
   → score >= limiar  → resposta da intenção correspondente
   → score <  limiar  → fallback (encaminhamento a atendimento humano)
   → persistência em `conversations` (Postgres)
```

- **Base de conhecimento**: tabelas `intents`, `training_phrases`, `bot_responses`.
- **Fallback controlado**: limiar configurável via `chatbot.fallback-threshold`.
- **Contexto de sessão**: última intenção detectada mantida por `sessionId`.
- **Log de conversas**: toda interação é persistida, servindo de base para avaliação.

## Stack

- Java 17, Spring Boot 3, Spring Data JPA
- PostgreSQL
- Maven

## Estrutura do projeto

```
src/main/java/com/rgctraining/chatbot/
├── controller/   endpoint REST
├── service/      orquestração do chat e classificação de intenção
├── nlp/          tokenizador, stopwords, TF-IDF, similaridade de cosseno
├── model/        entidades JPA
├── repository/   acesso a dados
└── dto/          contratos de entrada/saída da API

sql/
├── schema.sql                              estrutura das tabelas (instalação nova)
├── seed.sql                                base de conhecimento inicial (intents de exemplo)
├── migration_001_feedback_aprendizado.sql  incremento para banco já existente (colunas de origem/rastreabilidade)
└── ampliacao_training_phrases.sql          variações extras de frases de treino por intenção
```

Em uma instalação nova, rode `schema.sql` → `seed.sql` → `ampliacao_training_phrases.sql`, nessa ordem
(`schema.sql` já inclui as colunas de rastreabilidade, então `migration_001` não é necessária).

Em um banco que já estava rodando antes dessas mudanças, rode primeiro `migration_001_feedback_aprendizado.sql`
e depois `ampliacao_training_phrases.sql`.

## Configuração

A aplicação lê a conexão com o banco via variáveis de ambiente:

| Variável      | Padrão                     |
|---------------|----------------------------|
| `DB_HOST`     | `localhost`                |
| `DB_PORT`     | `5432`                     |
| `DB_NAME`     | `academia_rgc_chatbot`     |
| `DB_USER`     | —                          |
| `DB_PASSWORD` | —                          |

Nenhuma credencial é versionada no repositório.

## Executando

```bash
# 1. Banco de dados (requer um Postgres acessível e já criado)
psql -d academia_rgc_chatbot -f sql/schema.sql
psql -d academia_rgc_chatbot -f sql/seed.sql

# 2. Aplicação
export DB_USER=<usuario>
export DB_PASSWORD=<senha>
mvn spring-boot:run
```

## API

```bash
curl -X POST http://localhost:8080/api/chat \
  -H "Content-Type: application/json" \
  -d '{"sessionId":"teste1","mensagem":"qual o horario de funcionamento"}'
```

Resposta:
```json
{
  "resposta": "...",
  "intentDetectado": "horario_funcionamento",
  "score": 0.83,
  "fallback": false
}
```

Para recarregar o modelo após alterar `training_phrases` sem reiniciar a aplicação:
```bash
curl -X POST http://localhost:8080/api/chat/recarregar-modelo
```

## Aprendizado por feedback confirmado

O sistema **não** aprende automaticamente de toda conversa — isso reforçaria
erros de classificação (uma mensagem mal classificada, se virasse treino para
a intenção errada, ensinaria o erro ao invés de corrigi-lo).

Em vez disso, uma conversa só vira novo dado de treino depois que um humano
confirma qual era a intenção correta:

```bash
curl -X POST http://localhost:8080/api/chat/feedback \
  -H "Content-Type: application/json" \
  -d '{"conversationId": 42, "intentCorreta": "planos_matricula"}'
```

Isso cria uma linha em `training_phrases` com `origem = 'aprendida'` (rastreável
até a conversa de origem via `conversation_id`) e recarrega o modelo automaticamente.
