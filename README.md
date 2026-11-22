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
- **Sem contexto de conversa**: cada mensagem é classificada isoladamente. O `ChatService` guarda a última intenção por `sessionId` em memória, mas esse valor não é usado em nenhuma decisão (não há resolução de perguntas de seguimento como "e o anual?").
- **Log de conversas**: toda interação é persistida, servindo de base para avaliação.

## Escopo

**O que o bot responde** (assuntos da academia, conforme as intents do `sql/banco.sql`):

- Social: saudação, despedida, agradecimento e perguntas sobre o próprio assistente.
- Informações da academia: horário (inclusive sábados, domingos e feriados), endereço, contato, estacionamento, estrutura e equipamentos, acesso (catraca/biometria) e idade mínima (inclusive criança por modalidade).
- Planos e matrícula: planos e valores (mensal, trimestral, anual), comparação entre planos, matrícula, documentos, taxa, descontos, troca de plano, cancelamento e trancamento.
- Financeiro: formas de pagamento e mensalidade atrasada.
- Serviços e aulas: personal trainer, avaliação física, aula experimental, modalidades (Kids, FitDance, Yoga, Muay Thai, Boxe, Bike), grade de horários e modalidades que a RGC não oferece.
- Suporte: pedido de atendimento humano, reclamações e sugestões.

**O que o bot não responde**: qualquer assunto sem relação com a academia (clima, câmbio, filmes, contas, trabalho de faculdade etc.). Nesses casos a resposta é a da intent `fora_escopo` (ou o fallback, se a similaridade ficar abaixo do limiar), que redireciona para os temas da RGC e oferece o atendimento humano (WhatsApp/recepção).

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

## Pré-requisitos

- Java 17
- Maven 3.9+
- PostgreSQL (qualquer versão recente) com um banco criado, ex.: `academia_rgc_chatbot`

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
| `acuracia` | Acurácia **estrita**: intenção obtida igual à esperada (esperada `NULL` só acerta no fallback) |
| `acuraciaEquivalencia` (`acertosEquivalencia`) | Acurácia **com a regra de equivalência** (ver abaixo) |
| `porTipo` | Acerto e acurácia por tipo de caso, nas duas métricas |
| `acertosPorEquivalencia` | Casos que erram no critério estrito mas acertam pela equivalência |
| `taxaFallback` | Fração das perguntas que caíram no fallback |
| `porClasse`, `precisaoMacro`, `recallMacro` | Precisão e recall por intenção e a média entre as intenções testadas. O fallback conta como a classe `(fallback)` |
| `matrizConfusao` | `esperada → obtida → quantidade` |
| `erros` | Casos que erram mesmo com a equivalência, com intenção esperada, obtida e score |

**Regra de equivalência.** Além do critério estrito, o relatório traz a acurácia
com equivalência (`EquivalenciaIntents`), que também aceita:

1. Esperado `NULL` (fora do escopo): acerta se o bot cair no fallback **ou** na intent `fora_escopo`, pois as duas são o comportamento correto (encaminhar sem responder o assunto).
2. Esperado = intent genérica (pai): acerta se a obtida for uma especialização (filha) dela, ex.: `planos_valores` aceita `plano_mensal`, `plano_trimestral` e `plano_anual`. A relação vale só de pai para filha: quem espera a filha **não** aceita o pai nem uma irmã.

O mapa pai → filhas é uma constante em `EquivalenciaIntents`, montado a partir
da taxonomia das intents no `sql/banco.sql` (pelo significado de cada uma) e
definido **antes** de olhar quais testes erravam. Isso evita uma métrica
circular, em que a regra seria moldada para "consertar" os erros. Mudanças no
mapa devem ser justificadas pela taxonomia, nunca pelo resultado dos testes.

Fica de fora de propósito `horario_funcionamento` → `horario_fim_semana_feriado`:
uma pergunta geral de horário ("Que horas vocês abrem?") respondida só com o
horário de fim de semana não atende o cliente, então conta como erro.

A matriz de confusão e precisão/recall continuam usando a intent realmente
obtida. O campo `resultado` gravado em `test_cases` (`ACERTO`/`ERRO`) segue a
regra **com** equivalência; a acurácia estrita só aparece nas métricas.

**Separação entre treino e teste.** Nenhum caso de teste pode ser igual a uma
frase de treino depois de normalizar (minúsculas, sem acento, sem pontuação,
como o `Tokenizer`). Caso igual ao treino acerta por memória e infla a
acurácia. O teste `SeparacaoTreinoTesteTest` lê o `sql/banco.sql` e falha se
isso acontecer. Ao criar casos novos, escreva frases que não estão no treino,
e não ajuste o treino para acertar um caso de teste específico.

O usuário do banco precisa de permissão de `UPDATE` em `test_cases`.

Testes automatizados (cálculo das métricas, regra de equivalência e separação treino/teste; não exigem banco):

```bash
mvn test
```

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
