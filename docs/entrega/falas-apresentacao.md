# Falas da apresentação (5 min + 3 min de perguntas)

Ritmo: cerca de 130 palavras por minuto. Os textos entre colchetes indicam o que muda na tela. **Reconfira os exemplos da demo no ensaio**, porque o modelo pode ter mudado desde que este roteiro foi escrito.

---

## Caio — problema, escopo e base (≈ 1 min 15 s)

**[Slide 1: capa]**
Bom dia, professor. Nós somos o Caio, o Diego e o Rafael, e o nosso projeto é o chatbot da RGC Training, uma academia.

**[Slide 2: problema]**
Toda academia recebe as mesmas perguntas o dia inteiro, pelo site e pelo WhatsApp: qual é o horário, quanto custa o plano, se tem aula de boxe, quais documentos a matrícula pede. A recepção perde tempo respondendo sempre a mesma coisa. Nosso objetivo foi um assistente no site que responde essas dúvidas na hora e, quando não sabe, encaminha para um atendente.

**[Slide 3: escopo]**
O escopo são os assuntos da academia: horários, planos e valores, matrícula e cancelamento, modalidades, estrutura e idade mínima. Dieta, saúde e assuntos gerais ficam de fora. Nesses casos o bot avisa que não pode ajudar e indica o atendimento humano.

**[Slide 4: base de conhecimento]**
Eu cuidei da base de conhecimento. São 49 intenções, 97 respostas e 1.412 frases de treino. Todas são fictícias, escritas pela equipe a partir das informações do site, e nenhuma tem dado pessoal. Também validei as regras de negócio, como a idade mínima de 14 anos nas aulas coletivas. Escrevemos 188 casos de teste: perguntas esperadas, reformulações, ambíguas e fora do escopo. Um teste automático garante que nenhum caso de teste é igual a uma frase de treino. Agora o Diego mostra como o bot decide.

---

## Diego — arquitetura e demonstração (≈ 2 min)

**[Slide 5: arquitetura]**
A técnica é TF-IDF com similaridade do cosseno, implementada à mão em Java, sem biblioteca de processamento de linguagem.

O fluxo tem quatro etapas:
1. A mensagem passa pelo pré-processamento. Tudo vai para minúsculas, os acentos e as palavras sem peso saem, e a negação e o "aí" são tratados pelo contexto da frase.
2. O texto vira um vetor TF-IDF.
3. Comparamos esse vetor com cada frase de treino.
4. A intenção da frase mais parecida vence.

Por cima disso há uma regra: se o score fica abaixo de 0,18, o bot não chuta e encaminha para um atendente. Resumindo: o TF-IDF mede o quanto a pergunta se parece com o que ele conhece, e as regras decidem se ele responde ou encaminha.

**[Demo: /demo.html]**
Vou mostrar no painel.
- "Qual o valor do plano mensal?" Aqui aparecem as palavras que sobraram depois do pré-processamento, as três intenções mais parecidas e o score 1,0. Ele respondeu sobre o plano mensal.
- "Funcionam aos domingos?" A palavra "funcionam" não existe no treino, então o score é zero e ele encaminha em vez de inventar.
- Agora um erro que a gente já conhece: "Não quero mais ser aluno". A negação vira o token `nao_quero`, mas "cancelamento" ficou em segundo lugar, muito perto de "matrícula". O Rafael volta nesse caso nos resultados.
- Por último, o contexto. Depois de perguntar do plano mensal, eu mando só "plano sem fidelidade". O bot usa a última intenção da conversa para desempatar e continua no plano mensal. O limite é que ele só desempata quando as duas primeiras intenções estão quase empatadas.

O Rafael apresenta os números.

---

## Rafael — resultados, falhas e encerramento (≈ 1 min 45 s)

**[Slide 6: resultados, ou /avaliacao.html]**
Rodamos os 188 casos pela página de avaliação. Temos duas medidas:
- **Acurácia estrita: 76,6 %.** Ela exige a intenção exata.
- **Acurácia com a regra de equivalência: 82,4 %.** Essa regra aceita, por exemplo, mandar uma pergunta fora do escopo para o atendente, ou responder sobre o plano anual quando o teste esperava "valores dos planos".

A regra foi definida antes de olharmos os erros.

**[Slide 7: comparação]**
Comparamos com uma alternativa, um Naive Bayes que também implementamos. Ele acertou 58 %. O TF-IDF ganha em quase todos os tipos de pergunta, mas perde nas difíceis, e registramos isso.

Também testamos regras mais rígidas, calibradas só com as frases de treino:
- as respostas erradas caíram de 32 para 9;
- em compensação, 55 perguntas iam para o atendente, e a acurácia caiu para 62 %.

Para uma academia, mandar quase um terço das perguntas para a recepção não compensa. Por isso essas regras estão no código, mas desligadas.

**[Slide 8: três falhas]**
Analisamos três falhas:
1. **Negação.** "Não quero mais ser aluno" vai para matrícula, porque quase não temos frases negadas no treino. A melhoria é acrescentar essas frases à intenção de cancelamento.
2. **Fora do escopo com palavra da academia.** "Como troco o pneu do carro?" cai em estacionamento por causa da palavra "carro". A melhoria é calibrar a regra de margem num conjunto de validação separado.
3. **Intenção genérica contra específica.** "Me explica a aula de yoga" fica quase empatada entre modalidades e aula de yoga. A melhoria é ter mais frases específicas de cada aula.

**[Slide 9: encerramento]**
O bot responde a maior parte das dúvidas e sabe quando não sabe. Obrigado. Estamos prontos para as perguntas.

---

## Perguntas: quem responde o quê

| Assunto | Quem |
|---|---|
| Técnica, algoritmo, arquitetura, "por que não um LLM" | Diego |
| Métricas, testes, matriz de confusão, páginas de demo e avaliação | Rafael |
| Escopo, base de conhecimento, dados e privacidade, regras de negócio | Caio |

**Mudança de requisito (a pergunta inédita).** Exemplo: "e se a academia abrir aula de pilates?"
- **Caio:** cria a intenção, as frases de treino e as respostas no banco.
- **Diego:** recarrega o modelo pelo endpoint de administração, sem novo deploy, e acrescenta casos de teste novos, escritos sem olhar o modelo.
- **Rafael:** roda a avaliação de novo para conferir que nada piorou.

Se a pergunta reformulada do professor falhar ao vivo, abram o painel do `/demo`, mostrem as três intenções e o score e expliquem o motivo e a correção. Isso também conta ponto.
