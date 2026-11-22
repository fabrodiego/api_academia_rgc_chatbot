# ADR 0003 — "Aí" tratado pelo contexto e modalidades não oferecidas numa intent só

- Data: 2026-11-22
- Status: aceito

## Contexto

No ensaio, "Tem crossfit aí?" foi respondido com saudação, e "Tem cross fit aí?" não. Havia dois problemas.

**1. O "aí".** A frase de treino "e aí" vira só o token `ai` ("e" é stopword). Isso dá à `saudacao` uma frase com 100 % de `ai`, e o `ai` tem IDF alto (está em 5 das 1.412 frases). Em "Tem crossfit aí?" sobram `crossfit` e `ai`, e o `ai` pesa mais. Pelo `/api/chat/explicar` em produção, toda pergunta "X aí?" ia para `saudacao`: pilates, natação, yoga, boxe, musculação, estacionamento, horário, preço. A lista de stopwords tem a decisão de não mexer, e o "aí" tem dois papéis (cumprimento em "e aí", lugar em "tem crossfit aí?") que uma stopword fixa não separa.

**2. As modalidades que a RGC não oferece em duas intents.** "tem pilates", "tem natacao", "tem crossfit" e "tem piscina" estavam em `aulas_modalidades`. As duas primeiras também estavam em `modalidades_nao_oferecidas`, ou seja, a mesma frase estava nas duas intents e o empate era decidido pela ordem do treino. Os casos de teste seguiam essa divisão: "Vocês têm pilates?" e "Tem crossfit aí?" esperavam `aulas_modalidades`, e "Vocês oferecem pilates de solo?" e "Quero fazer crossfit, onde treino?" esperavam `modalidades_nao_oferecidas`.

## Opções

Para o "aí":
1. **Só dados**: uma frase "tem X aí" por assunto. Não generaliza e chega perto de copiar o caso de teste no treino.
2. **Pôr "ai" nas stopwords**: "e aí" sozinho vira mensagem vazia (fallback), e a lista fechada muda.
3. **"Aí" pelo contexto**, no `Preprocessador`, como a negação.

Para as modalidades:
1. Manter como está (o empate continua decidido pela ordem).
2. **Uma intent só**: a descrição de `modalidades_nao_oferecidas` é "Modalidades que a RGC não oferece (pilates, crossfit, natação)".

## Decisão

- **"Aí" pelo contexto.** Logo depois de um cumprimento ("e", "fala", "oi", "olá", "opa", "salve") vira o token `e_ai`; em qualquer outra posição é advérbio de lugar e sai. Vale igual no treino e na mensagem e em todos os modos de negação. A lista de stopwords não muda.
- **Modalidades numa intent só.** "tem pilates" e "tem natacao" saem de `aulas_modalidades` (já existiam em `modalidades_nao_oferecidas`). "tem crossfit" e "tem piscina" vão para `modalidades_nao_oferecidas`. Os casos "Vocês têm pilates?" e "Tem crossfit aí?" passam a esperar `modalidades_nao_oferecidas`. Treino: 1.412 → 1.410 frases.

Medido com as frases e os casos do `sql/banco.sql` (os mesmos de produção):

| | Estrita | Com equivalência | Erradas / fallbacks |
|---|---|---|---|
| Antes | 142 (75,5 %) | 153 (81,4 %) | 34 / 1 |
| Só o "aí" | 144 (76,6 %) | 155 (82,4 %) | 32 / 1 |
| "Aí" + modalidades | 145 (77,1 %) | 156 (83,0 %) | 31 / 1 |

Casos que mudaram (nenhum piorou):
- "Tem crossfit aí?": `saudacao` → `modalidades_nao_oferecidas` (rótulo corrigido).
- "Criança treina boxe aí?": `saudacao` → `crianca_boxe`.
- "Vocês oferecem pilates de solo?": `aulas_modalidades` → `modalidades_nao_oferecidas` (rótulo **não** mudou: o acerto vem só da correção dos dados).
- "Vocês têm pilates?": continua certo, agora em `modalidades_nao_oferecidas` (rótulo corrigido).

Outros efeitos:
- Leave-one-out dos modos de negação: 717/760, 716/759, 716/759, 717/760. O empate do ADR 0001 se mantém.
- Baseline Naive Bayes: 109/130 → 111/132.
- A recalibração das regras no treino agora escolhe margem 0,03 (limiar 0,46 e fração 1,0 iguais), com 119/127 nos casos de teste. As regras continuam desligadas (ADR 0002). O CSV `docs/resultados/calibracao.csv` foi regerado.

**Transparência.** O erro foi achado no ensaio, mas "Tem crossfit aí?" está no conjunto de teste, então o ganho foi medido depois de olhar o teste. Dois rótulos de teste foram mudados. Sem essa correção, o resultado seria 143, porque os dois casos passariam a errar contra o rótulo antigo. A mudança dos rótulos segue a descrição da intent e os outros dois casos que já esperavam `modalidades_nao_oferecidas`; não foi escolhida para bater com o modelo. A regra do "aí" não usa nenhum caso de teste, e o `AiNoTreinoRealTest` a verifica em perguntas que não estão no teste.

### Por quê (com as palavras do Diego)

<!-- Diego: explique em 1–2 frases por que corrigir a regra do "aí" e a divisão das intents, e não só a frase do crossfit. -->

## Consequências

- "aí" depois de qualquer outra palavra é descartado; um "aí" com sentido próprio fora de cumprimento ("aí sim") se perde. As três frases de treino com "aí" de lugar ("oi alguem ai", "tem alguem ai", "como chego ai") perdem esse token. "como chego aí" passa de `saudacao` (errado) para o fallback.
- "eai" escrito junto continua sendo outro token (o treino não tem).
- "tem pilates?" passa a receber a resposta de `modalidades_nao_oferecidas` ("Não temos pilates, crossfit nem natação. O que oferecemos: …"), que responde à pergunta melhor que a lista geral de aulas.
- Produção: SQL incremental com trava (backup → SQL → reinício do pod → avaliação), fora do repositório.
- Regressão coberta por `PreprocessadorTest` (regra) e `AiNoTreinoRealTest` (dados reais: "X aí?" dá a mesma intent que "X?" e nunca `saudacao`; "e aí" continua `saudacao`).
