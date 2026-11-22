# ADR 0001 — Negação fundida ao próximo token

- Data: 2026-11-22
- Status: aceito

## Contexto

`não`/`nao` está na lista de stopwords. A negação some no pré-processamento: "Não quero mais ser aluno" vira `quero aluno`, igual a "quero ser aluno" do treino, e o bot responde `matricula`.

## Opções

1. **Ignorar** (como era): `não` continua stopword.
2. **Manter**: tirar `não`/`nao` das stopwords; vira um token comum.
3. **Fundir**: `não` + próximo token relevante viram um token só (`nao_quero`), no treino e na mensagem.
4. **Fundir com recuo**: como a 3, mas, se a fusão da mensagem nunca apareceu no treino, volta ao token simples.

## Decisão

Opção 4 (`chatbot.negacao: fundir_com_recuo`).

Medido por leave-one-out nas 1.412 frases de treino (acertos estrito / com equivalência): ignorar 700/743, manter 699/742, fundir 699/742, fundir com recuo 700/743. O treino tem só 11 frases com "não", então as opções praticamente empatam. A 4 foi escolhida porque dá significado à negação sem perder casos: a fusão pura mandava "não tem estacionamento" para fallback, porque `nao_estacionamento` não existe no treino.

### Por quê (com as palavras do Diego)

<!-- Diego: explique em 1–2 frases por que tratar a negação importa num chatbot de academia. -->

## Consequências

- A negação passa a existir no vetor quando o treino a conhece.
- O ganho depende de haver frases de treino com negação. Hoje são poucas, e "Não quero mais ser aluno" ainda erra (margem 0,043 entre `matricula` e `cancelamento`).
- Nos 188 casos de teste, `fundir_com_recuo` e `ignorar` dão exatamente o mesmo resultado (142 estrita / 153 com equivalência): a negação não muda nenhum caso. O efeito aparece só quando o treino tem a forma negada.
- Tratamento configurável: dá para comparar as quatro opções sem mudar código.
