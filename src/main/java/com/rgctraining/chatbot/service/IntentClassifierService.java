package com.rgctraining.chatbot.service;

import com.rgctraining.chatbot.model.Intent;
import com.rgctraining.chatbot.model.TrainingPhrase;
import com.rgctraining.chatbot.nlp.ClassificadorTfIdf;
import com.rgctraining.chatbot.nlp.ClassificadorTfIdf.Classificacao;
import com.rgctraining.chatbot.nlp.Preprocessador;
import com.rgctraining.chatbot.repository.IntentRepository;
import com.rgctraining.chatbot.repository.TrainingPhraseRepository;
import jakarta.annotation.PostConstruct;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import java.util.*;

@Service
public class IntentClassifierService {

    /** Quantas intents distintas o classificador devolve por padrão. */
    public static final int TOP_K = 3;

    private final IntentRepository intentRepository;
    private final TrainingPhraseRepository trainingPhraseRepository;
    private final Preprocessador preprocessador;

    /**
     * Estado do modelo, imutável: classificador e mapas são montados fora e a
     * referência é trocada de uma vez só no recarregar (leitores concorrentes
     * nunca veem um modelo pela metade).
     */
    private record Modelo(ClassificadorTfIdf classificador, Map<String, Long> intentIdPorCodigo) {}

    private volatile Modelo modelo;

    public IntentClassifierService(IntentRepository intentRepository,
                                    TrainingPhraseRepository trainingPhraseRepository,
                                    @Value("${chatbot.negacao:fundir_com_recuo}") String negacao) {
        this.preprocessador = new Preprocessador(Preprocessador.ModoNegacao.de(negacao));
        this.intentRepository = intentRepository;
        this.trainingPhraseRepository = trainingPhraseRepository;
    }

    /** Carrega todas as frases de treino do banco e monta o modelo TF-IDF em memória. */
    @PostConstruct
    public void carregarModelo() {
        List<Intent> intents = intentRepository.findAll();
        Map<String, Long> intentIdPorCodigo = new HashMap<>();
        Map<Long, String> codigoPorId = new HashMap<>();
        for (Intent intent : intents) {
            intentIdPorCodigo.put(intent.getCodigo(), intent.getId());
            codigoPorId.put(intent.getId(), intent.getCodigo());
        }

        List<String> textos = new ArrayList<>();
        List<String> intentPorFrase = new ArrayList<>();
        for (TrainingPhrase frase : trainingPhraseRepository.findAll()) {
            textos.add(frase.getTexto());
            intentPorFrase.add(codigoPorId.get(frase.getIntentId()));
        }

        this.modelo = new Modelo(new ClassificadorTfIdf(preprocessador, textos, intentPorFrase),
                Map.copyOf(intentIdPorCodigo));
    }

    /** Recarrega o modelo (chame depois de alterar frases de treino no banco, sem reiniciar a aplicação). */
    public void recarregar() {
        carregarModelo();
    }

    /**
     * Classifica a mensagem do usuário: tokeniza, vetoriza e compara (cosseno)
     * com todas as frases de treino. Devolve as {@link #TOP_K} melhores intents
     * distintas, os tokens e a fração de tokens conhecidos.
     */
    public Classificacao classificar(String mensagem) {
        return modelo.classificador().classificar(mensagem, TOP_K);
    }
}
