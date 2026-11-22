# Roteiro da apresentação (8 min: 5 de demonstração + 3 de perguntas)

## Antes de começar
- Abrir `/demo.html` e `/avaliacao.html` em abas separadas.
- Na aba de avaliação, digitar a chave de admin no campo de senha **fora do projetor**.
- Rodar "Executar testes" uma vez antes, para a tela já ter números.

## 1. Problema e escopo (40 s)
- Academia recebe as mesmas perguntas no site e no WhatsApp: horário, planos, aulas, matrícula.
- O bot responde o que é da academia; o resto (dieta, assuntos gerais) vai para `fora_escopo` ou para o atendimento humano.

## 2. Como o bot decide (1 min 30 s) — `/demo.html`
Mostrar no painel, nesta ordem (conferido em 2026-11-22 com a configuração de produção; **reconfira no ensaio**):
1. **Acerto:** "Qual o valor do plano mensal?" → `plano_mensal`, score 1,0, margem 0,30, responde.
2. **Palavra fora do vocabulário:** "Funcionam aos domingos?" → score 0, fallback. Explicar: a forma "funcionam" não existe no treino, então o bot encaminha em vez de chutar.
3. **Erro conhecido (fora do escopo):** "Como troco o pneu do carro?" → `estacionamento` 0,69, com `fora_escopo` em 2º (0,59). Explicar: "carro" é palavra do negócio; com a regra de margem ligada isso iria para o humano (ADR 0002).
4. **Erro conhecido (negação):** "Não quero mais ser aluno" → `matricula` 0,62, `cancelamento` em 2º (0,58). Mostrar o token `nao_quero` e a margem 0,043.
5. **Contexto:** na mesma aba, "Qual o valor do plano mensal?" e depois "plano sem fidelidade". Sem contexto vai para `planos_valores`; com contexto, `plano_mensal` (motivo `contexto`). Dizer o limite: o contexto só desempata quando as duas primeiras estão quase empatadas; não resolve um seguimento como "e no sábado?".

Frase-chave: "O TF-IDF mede o quanto a pergunta se parece com cada frase de treino; as regras decidem se respondemos ou encaminhamos."

## 3. Resultados (1 min 30 s) — `/avaliacao.html`
- 188 casos: estrita 76,6 %, com equivalência 82,4 %; baseline Naive Bayes 58,0 % / 69,1 %. Explicar por que existem as duas métricas (regra definida antes de olhar os erros).
- A acurácia caiu de 81 % (127 casos) para 77 % (188) porque os 61 casos novos foram escritos sem olhar o modelo e cobrem intents antes sem teste. É o número mais honesto.
- Matriz de confusão: apontar as intents vizinhas que se confundem.
- Comparação com o baseline Naive Bayes.
- O experimento das regras calibradas (ADR 0002): menos respostas erradas, mas encaminhamento demais; por isso ficaram desligadas.

## 4. Limitações e próximos passos (1 min)
- Separação treino/teste garantida por teste automatizado.
- Falta um conjunto de validação separado para calibrar as regras.
- "Tem crossfit aí?" ia para saudação: o "aí" de lugar era lido como o "e aí" do cumprimento. Corrigido pelo contexto da palavra (ADR 0003): +2 casos, nenhum piorou. Transparência: o erro foi achado no ensaio e também aparece no teste, então esse ganho foi medido depois de olhar o teste.
- Principais causas de erro (33 casos; contagem por causa feita antes do ADR 0003, com 35): intent genérica × específica quase empatadas (12), palavra que puxa a intent errada (11), fora do escopo com vocabulário da academia (6), negação (3).
- O baseline ganha no tipo difícil (17 × 15): o TF-IDF 1-NN depende da frase de treino mais parecida.

## Perguntas prováveis (ensaiar)
- **"Por que não um LLM/RAG?"** Custo, latência e respostas controladas pela academia; o enunciado pede a técnica implementada à mão.
- **"Como você mudaria o comportamento se o requisito mudasse?"** Ex.: "errar é proibido" → ligar as regras calibradas pelo `application.yml`, sem mudar código.
- **"Como sabem que o teste não está viciado?"** `SeparacaoTreinoTesteTest` falha se um caso de teste repetir uma frase de treino; os casos novos foram escritos sem rodar o modelo.
- **"Por que a acurácia com equivalência é maior?"** Regra fixa: fora do escopo aceita fallback ou `fora_escopo`; a intent genérica aceita as específicas. O mapa vem da taxonomia, não dos erros.
