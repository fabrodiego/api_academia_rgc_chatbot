package com.rgctraining.chatbot.avaliacao;

import java.util.Map;
import java.util.Set;

/**
 * Regra de equivalência da avaliação.
 *
 * Duas situações contam como acerto além da igualdade estrita:
 * 1. Esperado NULL (fora do escopo): acerta se o bot cair no fallback (obtida
 *    NULL) OU na intent "fora_escopo".
 * 2. Esperado é uma intent genérica (pai) e a obtida é uma especialização
 *    (filha) dela, conforme {@link #FILHAS_POR_PAI}. A relação é só pai -> filha:
 *    esperar a filha NÃO aceita o pai nem uma irmã.
 *
 * O mapa foi montado a partir da taxonomia das intents em sql/banco.sql (pela
 * descrição/significado de cada intent), antes de olhar quais testes erraram,
 * para a métrica não ficar circular. Só entram especializações inequívocas.
 *
 * Fora de propósito: horario_funcionamento -> horario_fim_semana_feriado. Uma
 * pergunta geral de horário respondida só com o fim de semana não atende o
 * cliente, então continua sendo erro.
 */
public final class EquivalenciaIntents {

    public static final String FORA_ESCOPO = "fora_escopo";

    private static final Set<String> AULAS_LUTA = Set.of("aula_boxe", "aula_muay_thai");
    private static final Set<String> CRIANCA_LUTA = Set.of("crianca_boxe", "crianca_muay_thai");

    /** pai -> filhas (especializações). */
    public static final Map<String, Set<String>> FILHAS_POR_PAI = Map.of(
            // planos_valores lista os planos; cada plano_* detalha um deles
            "planos_valores", Set.of("plano_mensal", "plano_trimestral", "plano_anual"),
            // aulas_modalidades lista as modalidades; cada aula_* detalha uma
            "aulas_modalidades", Set.of("aula_kids", "aula_danca", "aula_yoga", "aula_muay_thai",
                    "aula_boxe", "aula_lutas", "aula_bike"),
            // aula_lutas é a pergunta genérica sobre lutas (Boxe e Muay Thai)
            "aula_lutas", AULAS_LUTA,
            // idade_minima trata de idade/público; crianca_* é a idade mínima numa aula específica
            "idade_minima", Set.of("crianca_boxe", "crianca_muay_thai", "crianca_lutas",
                    "crianca_bike", "crianca_danca", "crianca_yoga"),
            // crianca_lutas é o genérico de criança em luta (Boxe e Muay Thai)
            "crianca_lutas", CRIANCA_LUTA,
            // matricula já cobre "documentos e taxa" na própria descrição
            "matricula", Set.of("documentos_matricula", "taxa_matricula"),
            // estrutura cobre "equipamentos e aparelhos" na própria descrição
            "estrutura", Set.of("equipamentos"));

    private EquivalenciaIntents() {}

    /** Acerto estrito: intent obtida igual à esperada (NULL == NULL). */
    public static boolean acertoEstrito(String esperada, String obtida) {
        return java.util.Objects.equals(esperada, obtida);
    }

    /** Acerto com a regra de equivalência (inclui o estrito). */
    public static boolean acertoComEquivalencia(String esperada, String obtida) {
        if (acertoEstrito(esperada, obtida)) return true;
        if (esperada == null) return FORA_ESCOPO.equals(obtida);
        return obtida != null && FILHAS_POR_PAI.getOrDefault(esperada, Set.of()).contains(obtida);
    }

    /**
     * Mesma família no mapa pai -> filhas: a própria intent, pai e filha, ou duas
     * filhas do mesmo pai (ex.: plano_mensal e plano_anual). Usado pelo contexto
     * de sessão para tratar "e o anual?" como seguimento de "quanto custa o mensal?".
     */
    public static boolean mesmaFamilia(String a, String b) {
        if (a == null || b == null) return false;
        if (a.equals(b)) return true;
        for (Map.Entry<String, Set<String>> e : FILHAS_POR_PAI.entrySet()) {
            String pai = e.getKey();
            Set<String> filhas = e.getValue();
            boolean aNaFamilia = a.equals(pai) || filhas.contains(a);
            boolean bNaFamilia = b.equals(pai) || filhas.contains(b);
            if (aNaFamilia && bNaFamilia) return true;
        }
        return false;
    }
}
