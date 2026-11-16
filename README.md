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
- **Avaliação**: tabela `test_cases` com a intenção esperada de cada pergunta (acurácia e matriz de confusão).
- **Fallback controlado**: limiar configurável via `chatbot.fallback-threshold`.
- **Contexto de sessão**: última intenção detectada mantida por `sessionId`.
- **Log de conversas**: toda interação é persistida, servindo de base para avaliação.

## Stack

- Java 17, Spring Boot 3, Spring Data JPA
- PostgreSQL
- Maven
- springdoc-openapi (Swagger)

## Estrutura do projeto

```
src/main/java/com/rgctraining/chatbot/
├── controller/   endpoint REST
├── service/      orquestração do chat e classificação de intenção
├── nlp/          tokenizador, stopwords, TF-IDF, similaridade de cosseno
├── model/        entidades JPA
├── repository/   acesso a dados
└── dto/          contratos de entrada/saída da API

src/main/resources/
├── static/       site da academia com o chat (servido pela própria aplicação)
└── stopwords/    lista de stopwords em português

sql/
└── banco.sql   estrutura + base completa (intents, respostas, frases de treino e casos de teste)
```

O `banco.sql` cria as tabelas que ainda não existem e **substitui todos os dados**
(as tabelas e as permissões continuam). Serve tanto para instalação nova quanto
para reiniciar a base de um banco já em uso.

## Configuração

A aplicação lê a configuração via variáveis de ambiente:

| Variável      | Padrão                     |
|---------------|----------------------------|
| `DB_HOST`     | —                          |
| `DB_PORT`     | `5432`                     |
| `DB_NAME`     | `academia_rgc_chatbot`     |
| `DB_USER`     | —                          |
| `DB_PASSWORD` | —                          |
| `ADMIN_KEY`   | — (sem ela, `feedback`, `recarregar-modelo` e `avaliacao` ficam bloqueados) |

Nenhuma credencial é versionada no repositório.

## Executando

```bash
# 1. Banco de dados (requer um Postgres acessível e já criado)
psql -d academia_rgc_chatbot -v ON_ERROR_STOP=1 -f sql/banco.sql

# 2. Aplicação
export DB_HOST=<host>
export DB_USER=<usuario>
export DB_PASSWORD=<senha>
export ADMIN_KEY=<chave-dos-devs>
mvn spring-boot:run
```

Site com o chat: `http://localhost:8080/`

## API

Documentação interativa (Swagger): `http://localhost:8080/swagger-ui/index.html`

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

Para recarregar o modelo após alterar `training_phrases` sem reiniciar a aplicação
(endpoint restrito: exige o header `X-Admin-Key`):
```bash
curl -X POST http://localhost:8080/api/chat/recarregar-modelo \
  -H "X-Admin-Key: <chave-dos-devs>"
```

## Avaliação com os casos de teste

A tabela `test_cases` guarda as perguntas de teste com a intenção esperada
(`NULL` = o certo é cair no fallback) e o tipo (`padrao`, `variacao`,
`dificil`, `fora_escopo`). O executor roda cada pergunta pela mesma decisão do
`/api/chat` (sem gravar em `conversations`) e salva o resultado na própria
tabela (`intent_obtida`, `score`, `resposta_obtida`, `resultado`, `executado_em`).

Endpoints restritos (header `X-Admin-Key`):

```bash
# executa todos os casos e devolve as métricas
curl -X POST http://localhost:8080/api/avaliacao -H "X-Admin-Key: <chave-dos-devs>"

# métricas da última execução, sem rodar de novo
curl http://localhost:8080/api/avaliacao -H "X-Admin-Key: <chave-dos-devs>"

# planilha da última execução (CSV para Excel em pt-BR)
curl http://localhost:8080/api/avaliacao/casos.csv -H "X-Admin-Key: <chave-dos-devs>" -o casos-de-teste.csv
```

Métricas devolvidas:

| Campo | O que é |
|---|---|
| `acuracia` | Acertos / total. Critério estrito: intenção obtida igual à esperada |
| `porTipo` | Acurácia separada por tipo de caso |
| `taxaFallback` | Fração das perguntas que caíram no fallback |
| `porClasse`, `precisaoMacro`, `recallMacro` | Precisão e recall por intenção e a média entre as intenções testadas. O fallback conta como a classe `(fallback)` |
| `matrizConfusao` | `esperada → obtida → quantidade` |
| `erros` | Casos que erraram, com intenção esperada, obtida e score |

O usuário do banco precisa de permissão de `UPDATE` em `test_cases`.

Testes automatizados do cálculo das métricas: `mvn test`.

## Aprendizado por feedback confirmado

O sistema **não** aprende automaticamente de toda conversa — isso reforçaria
erros de classificação (uma mensagem mal classificada, se virasse treino para
a intenção errada, ensinaria o erro ao invés de corrigi-lo).

Em vez disso, uma conversa só vira novo dado de treino depois que um humano
da equipe confirma qual era a intenção correta (endpoint restrito: exige o header `X-Admin-Key`):

```bash
curl -X POST http://localhost:8080/api/chat/feedback \
  -H "Content-Type: application/json" \
  -H "X-Admin-Key: <chave-dos-devs>" \
  -d '{"conversationId": 42, "intentCorreta": "planos_valores"}'
```

Isso cria uma linha em `training_phrases` com `origem = 'aprendida'` (rastreável
até a conversa de origem via `conversation_id`) e recarrega o modelo automaticamente.
