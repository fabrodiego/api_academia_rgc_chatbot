# ADR 0002 — Regras de decisão calibradas ficam desligadas

- Data: 2026-11-22
- Status: aceito

## Contexto

Além do limiar de score, implementamos duas regras para mandar a pergunta ao atendimento humano: **margem mínima** entre a 1ª e a 2ª intent e **fração mínima de tokens conhecidos**. Os valores foram calibrados **só no treino** (leave-one-out, utilidade = acertos − respostas erradas), para não viciar o conjunto de teste. Valores escolhidos: limiar 0,46, margem 0,02, fração 1,0 (`docs/resultados/calibracao.csv`).

Nos 127 casos de teste da época:

| Configuração | Estrita | Com equivalência | Respostas erradas | Encaminhadas |
|---|---|---|---|---|
| Limiar 0,18, sem regras | 81,1 % | 87,4 % | 16 | 0 |
| Regras calibradas | 69,3 % | 74,8 % | 9 | 23 |

Confirmado depois nos 188 casos (com os 61 casos novos, escritos sem rodar o modelo):

| Configuração | Estrita | Com equivalência | Respostas erradas | Fallbacks nos erros |
|---|---|---|---|---|
| Limiar 0,18, sem regras (+ negação) | 142 (75,5 %) | 153 (81,4 %) | 34 | 1 |
| Regras calibradas | 116 (61,7 %) | 124 (66,0 %) | 13 | 51 |
| Baseline Naive Bayes | 109 (58,0 %) | 130 (69,1 %) | — | — |

As regras quase cortaram pela metade as respostas erradas, mas encaminharam 23 perguntas, a maioria que o bot acertava. A causa principal é a fração 1,0: uma palavra fora do vocabulário ("boleto", "Gympass") manda para o humano mesmo com score 1,0.

## Opções

1. **Ligar as regras calibradas**: menos respostas erradas, muito mais encaminhamento.
2. **Desligar as regras e manter o limiar 0,18**: mesma acurácia de antes; as regras ficam no código, configuráveis.
3. **Recalibrar olhando o teste**: descartada, porque seria vazamento (a métrica deixa de medir generalização).

## Decisão

Opção 2. Em `application.yml`: `fallback-threshold: 0.18`, `margem-minima: 0.0`, `fracao-minima-conhecida: 0.0`. A margem só é usada para **desempatar pelo contexto da sessão** (`margem-contexto: 0.02`), não para encaminhar.

Transparência: esta escolha foi feita **depois** de ver o resultado no teste. Por isso o conjunto de teste não serve mais para comparar as duas configurações de forma independente. O relatório apresenta as duas, e a próxima calibração precisa de um conjunto de validação separado.

### Por quê (com as palavras do Diego)

<!-- Diego: para a academia, o que custa mais, uma resposta errada ou encaminhar para a recepção? Escreva em 1–2 frases. -->

## Consequências

- Produção mantém o comportamento medido; o ganho de `fora_escopo` das regras fica de fora.
- As regras continuam testadas (JUnit) e podem ser ligadas por configuração.
- Próximo passo, se houver tempo: separar um conjunto de validação e definir o custo relativo de erro × encaminhamento antes de calibrar.
