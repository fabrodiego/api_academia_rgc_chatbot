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
├── schema.sql    estrutura das tabelas
└── seed.sql      base de conhecimento inicial (intents de exemplo)
```

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
