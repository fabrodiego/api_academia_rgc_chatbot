# Academia RGC Training — Chatbot

Chatbot de atendimento desenvolvido em **Java (Spring Boot)**, com classificação
de intenção por **TF-IDF e similaridade de cosseno** implementados nativamente
(sem dependência de serviço de PLN pronto para o mecanismo central de decisão).

## Arquitetura

Arquitetura **híbrida**: a similaridade (TF-IDF + cosseno) mede *quão parecida* a mensagem é de cada intent;
**regras explícitas** decidem se o bot responde, usa o contexto da sessão ou encaminha a um humano.

```
Usuário → POST /api/chat
   → Preprocessador        (Tokenizer: minúsculas, sem acento/pontuação; StopWordsFilter; negação "nao_quero")
   → TfIdfVectorizer       (vetorização no espaço do corpus de treino)
   → ClassificadorTfIdf    (cosseno com todas as frases de treino → top-3 intents distintas,
                            tokens e fração de tokens conhecidos)
   → PoliticaDecisao       (regras: fração conhecida → limiar → margem → contexto)
   → resposta da intent  |  fallback (encaminhamento a atendimento humano)
   → persistência em `conversations` (Postgres)
```

- **Base de conhecimento**: tabelas `intents`, `training_phrases`, `bot_responses`.
- **Avaliação**: tabela `test_cases` com a intenção esperada de cada pergunta (acurácia e matriz de confusão).
- **Fallback controlado**: limiar configurável via `chatbot.fallback-threshold`.
- **Contexto de sessão (mínimo)**: o `ChatService` guarda em memória a última intent *respondida* de cada `sessionId` (`ContextoSessao`). Ela é usada **só para desempate**: quando a diferença de score entre a 1ª e a 2ª intent fica abaixo de `chatbot.margem-contexto` (0,02) e uma das duas é a última intent da sessão (ou da mesma família no mapa de `EquivalenciaIntents`, ex.: `plano_mensal` e `plano_anual`), o bot escolhe essa (motivo `contexto`). Fora desse caso o contexto não interfere: não há resolução de pronomes nem de perguntas de seguimento sem ambiguidade. Limites: a entrada expira após 30 min (`chatbot.contexto.ttl-minutos`) e o mapa guarda no máximo 10.000 sessões (`chatbot.contexto.max-sessoes`; descarta as expiradas e depois a menos usada). Sem `sessionId` a sessão é `anonimo`, compartilhada por todos, e por isso não usa contexto. Reiniciar a aplicação zera o contexto.
- **Log de conversas**: toda interação é persistida, servindo de base para avaliação.

## Regras de decisão: quem decide o quê

**Ligado por padrão:** limiar 0,18, desempate por contexto (margem 0,02) e negação fundida. **Desligado por padrão:** fallback por margem (`margem-minima` 0) e por fração de tokens conhecidos (`fracao-minima-conhecida` 0). Os valores calibrados no treino (0,46 / 0,02 / 1,0) pioraram a acurácia nos casos de teste ao mandar ao humano perguntas que o bot acertava; ficam no código e no CSV, desligados por decisão de produto (ver `docs/adr/0002`).

| Quem | Decide |
|---|---|
| **Similaridade** (`ClassificadorTfIdf`) | Os scores de cada intent (melhor frase de treino de cada intent), o top-3, os tokens e a fração de tokens conhecidos. Não decide nada sozinha. |
| **Regras** (`PoliticaDecisao`) | Responder ou encaminhar, nesta ordem (a primeira que falha define o `motivo`). |
| **Contexto** (`ContextoSessao`) | Só desempata a regra 3, quando há uma intent anterior na sessão. |

1. **Tokens conhecidos** (`chatbot.fracao-minima-conhecida`): fração dos tokens da mensagem que existem no vocabulário de treino. Abaixo do mínimo → fallback, motivo `tokens_desconhecidos` (inclui mensagem só com stopwords).
2. **Limiar** (`chatbot.fallback-threshold`): score da 1ª intent abaixo do limiar → fallback, motivo `score_baixo`.
3. **Contexto e margem**: se a diferença entre o score da 1ª e da 2ª intent é menor que `chatbot.margem-contexto` e a 1ª ou a 2ª for a última intent da sessão (ou da mesma família em `EquivalenciaIntents`), usa essa, motivo `contexto`; se o contexto não ajuda, segue. Depois, se a diferença é menor que `chatbot.margem-minima` → fallback, motivo `margem_pequena`. As duas margens são independentes: o contexto continua valendo com a regra de fallback por margem desligada.
4. Passou em tudo → responde com a 1ª intent, motivo `ok`.

**Negação.** "não/nao" era stopword e sumia ("Não quero mais ser aluno" virava "quero aluno" e caía em matrícula). Agora ele funde com o próximo token que não é stopword (`nao_quero`), igual no treino e na mensagem. Se a mensagem tem uma fusão que nenhuma frase de treino contém (ex.: `nao_estacionamento`), volta ao token simples (`estacionamento`), para a negação não apagar uma palavra conhecida. Configurável em `chatbot.negacao` (`ignorar`, `manter`, `fundir`, `fundir_com_recuo`). Comparação por leave-one-out nas 1.412 frases de treino (1-NN, acertos estrito / com equivalência): `ignorar` 700 / 743, `manter` 699 / 742, `fundir` 699 / 742, `fundir_com_recuo` 700 / 743. O treino tem poucas frases com negação (11), então o leave-one-out praticamente empata; a escolha por `fundir_com_recuo` é o empate que mantém a negação distinguível sem perder o que já funcionava.

**Calibração dos três valores.** Varredura de limiar (0 a 0,60), margem (0 a 0,15) e fração mínima (0 a 1) por **leave-one-out só nas frases de treino**: cada frase é classificada por um modelo montado com todas as outras (IDF incluído). As frases da intent `fora_escopo` funcionam como negativas (certo = fallback ou `fora_escopo`); as demais acertam por igualdade ou equivalência pai → filha. Os casos de teste não entram na calibração. A curva completa (1.736 combinações) está em `docs/resultados/calibracao.csv`, gerada por `GET /api/avaliacao/calibracao`, com a linha escolhida marcada (`escolhido=1`).

Critério: utilidade = acertos − respostas erradas (encaminhar a um humano custa 0; responder errado custa 1). O máximo da utilidade (limiar 0, margem 0,08, fração 1,0) responde menos da metade das frases, então vale entre as combinações com pelo menos 99% da utilidade máxima, a que **mais acerta**. Ponto escolhido pelo critério (hoje **desligado**, ver acima): **limiar 0,46, margem 0,02, fração mínima 1,0**. No leave-one-out: 655 acertos, 236 respostas erradas, 521 encaminhadas, 90 de 96 frases de `fora_escopo` rejeitadas; a configuração anterior (0,18 / 0 / 0) tinha 748 acertos e 591 respostas erradas. Limites desta escolha: o leave-one-out é mais pessimista que o uso real (tira da base a paráfrase mais próxima de cada frase) e a ponderação 1:1 entre erro e acerto é uma decisão de projeto; o CSV permite escolher outro ponto, mas **a escolha deve continuar sendo feita no treino, nunca nos casos de teste**.

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

Parâmetros do bot em `application.yml` (`chatbot.*`): `fallback-threshold` (0,18), `margem-minima` (0,0 = desligada), `fracao-minima-conhecida` (0,0 = desligada), `margem-contexto` (0,02), `negacao` (`fundir_com_recuo`), `contexto.ttl-minutos` (30) e `contexto.max-sessoes` (10000).

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

Os campos de `/api/chat` continuam os mesmos.

### Endpoints novos

**`POST /api/chat/explicar`** (público; **não grava** em `conversations` nem altera o contexto da sessão). Mostra como a mensagem seria decidida:

```bash
curl -X POST http://localhost:8080/api/chat/explicar \
  -H "Content-Type: application/json" \
  -d '{"sessionId":"teste1","mensagem":"Não quero mais ser aluno"}'
```
```json
{
  "tokens": ["nao_quero", "aluno"],
  "fracaoConhecida": 1.0,
  "top": [{"intent": "matricula", "score": 0.62}, {"intent": "cancelamento", "score": 0.58}, {"intent": "saudacao", "score": 0.0}],
  "limiar": 0.18,
  "margem": 0.043,
  "margemMinima": 0.0,
  "margemContexto": 0.02,
  "fracaoMinima": 0.0,
  "decisao": "resposta",
  "motivo": "ok",
  "intent": "matricula",
  "resposta": "...",
  "latenciaMs": 3
}
```
`decisao` = `resposta` ou `fallback`; `motivo` = `ok`, `score_baixo`, `margem_pequena`, `tokens_desconhecidos` ou `contexto`; `margem` é a diferença observada entre a 1ª e a 2ª intent (`limiar`, `margemMinima`, `margemContexto` e `fracaoMinima` são os valores configurados); `intent` é `null` no fallback.

**`GET /api/avaliacao/comparacao`** (header `X-Admin-Key`; não grava em `test_cases`). Roda os casos de teste no TF-IDF (mesma decisão do chat, sem contexto) e num baseline Naive Bayes multinomial feito à mão (mesmo pré-processamento sem negação, sem limiar nem regras; só cai no fallback se nenhum token é conhecido). Devolve acurácia estrita e com equivalência de cada um, no geral e por tipo.

**`GET /api/avaliacao/calibracao`** (header `X-Admin-Key`): refaz a varredura leave-one-out sobre o treino e devolve o CSV da curva (leva alguns segundos). Parâmetro opcional `negacao` para comparar os modos.

Para recarregar o modelo após alterar `training_phrases` sem reiniciar a aplicação
(endpoint restrito: exige o header `X-Admin-Key`):
```bash
curl -X POST http://localhost:8080/api/chat/recarregar-modelo \
  -H "X-Admin-Key: <chave-dos-devs>"
```

## Avaliação com os casos de teste

A tabela `test_cases` guarda as perguntas de teste com a intenção esperada
(`NULL` = o certo é cair no fallback) e o tipo (`padrao`, `variacao`,
`dificil`, `fora_escopo`, `ambigua`). Os casos `ambigua` são perguntas curtas
e vagas ("Quanto custa?"); a intent esperada é a genérica mais provável, e a
regra de equivalência aceita as filhas dela. O executor roda cada pergunta pela mesma decisão do
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

### Resultados nos 127 casos de teste

| | Estrita | Com equivalência | padrao | variacao | dificil | fora_escopo |
|---|---|---|---|---|---|---|
| TF-IDF só com limiar 0,18 (antes das regras) | 103/127 (81,1%) | 111/127 (87,4%) | 52/55 | 43/46 | 4/15 | 4/11 |
| (mesma configuração antiga com a negação fundida: idêntico) | 103/127 | 111/127 | 52/55 | 43/46 | 4/15 | 4/11 |
| TF-IDF + regras calibradas no treino (atual) | 88/127 (69,3%) | 95/127 (74,8%) | 44/55 | 35/46 | 2/15 | 7/11 |
| Baseline Naive Bayes | 67/127 (52,8%) | 80/127 (63,0%) | 28/55 | 29/46 | 6/15 | 4/11 |

(colunas por tipo: acurácia estrita.) As regras novas **reduziram** a acurácia nos casos de teste: a calibração no treino (leave-one-out) escolheu um ponto conservador, e dos 32 erros restantes (com equivalência) 23 são casos que caíram no fallback, a maioria com score alto mas com uma palavra fora do vocabulário (fração mínima 1,0) ou score abaixo de 0,46. Em troca, o bot responde errado menos vezes (9 respostas erradas contra 16 antes, todas as 16 sem nenhum fallback) e encaminha mais ao humano. A calibração não foi refeita olhando esses casos: seria vazamento do teste para os parâmetros.

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

## Privacidade

- A tabela `conversations` guarda o **texto livre** que o usuário digitou, junto com o `sessionId`, a intent detectada, o score e a resposta. Texto livre pode conter dado pessoal sem que ninguém peça.
- Os dados do projeto (frases de treino, casos de teste, respostas) são **fictícios**. O bot **não pede** nome, CPF, telefone, e-mail ou qualquer dado pessoal, e a interface deve avisar o usuário para não digitá-los.
- `POST /api/chat/explicar` não grava nada em `conversations`. O contexto de sessão fica só em memória (expira em 30 min e some ao reiniciar).
- O feedback confirmado copia o texto de uma conversa para `training_phrases`. Antes de confirmar, o humano deve conferir que a frase não tem dado pessoal.
- Retenção sugerida: manter `conversations` por até 90 dias para avaliação e apagar depois (por exemplo, `DELETE FROM conversations WHERE created_at < now() - interval '90 days'`, em rotina agendada). Frases que viraram treino (`origem = 'aprendida'`) mantêm só o texto, sem ligação com a sessão, depois que a conversa de origem for apagada (`conversation_id` vai para `NULL`).

## Páginas de demonstração

- `/demo.html`: chat com o painel "Como o bot decidiu" (tokens, top-3 de intenções, limiar e motivo da decisão), via `POST /api/chat/explicar`.
- `/avaliacao.html`: executa e consulta a avaliação do classificador (acurácia, matriz de confusão, erros, comparação com baseline). Exige a chave de administrador, informada na página e mantida só em memória.
