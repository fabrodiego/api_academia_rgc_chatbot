# ADR 0003 — "Aí" tratado pelo contexto

- Data: 2026-11-22
- Status: aceito

## Contexto

No ensaio, "Tem crossfit aí?" foi respondido com saudação, e "Tem cross fit aí?" não. A causa é o pré-processamento: a frase de treino "e aí" vira só o token `ai` ("e" é stopword). Isso dá à `saudacao` uma frase com 100 % de `ai`, e o `ai` tem IDF alto (aparece em 5 das 1.412 frases). Em "Tem crossfit aí?" sobram `crossfit` e `ai`, e o `ai` pesa mais.

Não era só o crossfit. Pelo `/api/chat/explicar` em produção, toda pergunta "X aí?" ia para `saudacao`: pilates, natação, yoga, boxe, musculação, estacionamento, horário, preço. Nos 188 casos de teste, dois erravam por isso: "Tem crossfit aí?" e "Criança treina boxe aí?".

A lista de stopwords tem a decisão de não mexer. O "aí" tem dois papéis em português: cumprimento ("e aí", "fala aí") e advérbio de lugar ("tem crossfit aí?"). Uma stopword fixa não separa os dois.

## Opções

1. **Só dados**: incluir frases como "tem pilates aí" em cada intent. Não generaliza (precisaria de uma por assunto) e chega perto de copiar o caso de teste no treino.
2. **Pôr "ai" nas stopwords**: resolve o lugar, mas "e aí" sozinho vira mensagem vazia e cai no fallback. Também mexe na lista, que está fechada.
3. **"Aí" pelo contexto**, no `Preprocessador`, como a negação: logo depois de um cumprimento ("e", "fala", "oi", "olá", "opa", "salve") vira o token `e_ai`; em qualquer outra posição sai.

## Decisão

Opção 3. Vale igual no treino e na mensagem e em todos os modos de negação. A lista de stopwords não muda.

Medido com as frases e os casos do `sql/banco.sql` (os mesmos de produção):

| | Estrita | Com equivalência | Erradas / fallbacks |
|---|---|---|---|
| Antes | 142 (75,5 %) | 153 (81,4 %) | 34 / 1 |
| Depois | 144 (76,6 %) | 155 (82,4 %) | 32 / 1 |

- Mudaram só os dois casos do "aí", ambos para o acerto. Nenhum caso piorou.
- Leave-one-out no treino (limiar 0,18): o total não muda. Uma frase muda: "como chego aí" deixa de ir para `saudacao` e vai para o fallback ("chego" só existe nessa frase).
- Baseline Naive Bayes: sem mudança (109 / 130).
- A recalibração das regras no treino agora escolhe margem 0,05 em vez de 0,02 (limiar 0,46 e fração 1,0 iguais), com 116 / 124 nos casos de teste. As regras continuam desligadas (ADR 0002). O CSV `docs/resultados/calibracao.csv` foi regerado.

Transparência: o erro foi achado no ensaio, mas um dos casos que melhoraram ("Tem crossfit aí?") está no conjunto de teste. Por isso o ganho de 142 para 144 foi medido depois de olhar o teste. A correção não usa nenhum caso de teste (é uma regra da língua, não uma frase nova), e o teste `AiNoTreinoRealTest` verifica a regra em perguntas que não estão no teste.

### Por quê (com as palavras do Diego)

<!-- Diego: explique em 1–2 frases por que corrigir a regra do "aí" e não só a frase do crossfit. -->

## Consequências

- "aí" depois de qualquer outra palavra é descartado; um "aí" com sentido próprio fora de cumprimento ("aí sim") se perde. As três frases de treino com "aí" de lugar ("oi alguem ai", "tem alguem ai", "como chego ai") perdem esse token, e o leave-one-out não piora.
- "eai" escrito junto continua sendo outro token (o treino não tem).
- Regressão coberta por `PreprocessadorTest` (regra) e `AiNoTreinoRealTest` (dados reais: "X aí?" dá a mesma intent que "X?" e nunca `saudacao`; "e aí" continua `saudacao`).
