package com.rgctraining.chatbot.service;

import com.rgctraining.chatbot.model.Intent;
import com.rgctraining.chatbot.model.TrainingPhrase;
import com.rgctraining.chatbot.nlp.CosineSimilarity;
import com.rgctraining.chatbot.nlp.StopWordsFilter;
import com.rgctraining.chatbot.nlp.TfIdfVectorizer;
import com.rgctraining.chatbot.nlp.Tokenizer;
import com.rgctraining.chatbot.repository.IntentRepository;
import com.rgctraining.chatbot.repository.TrainingPhraseRepository;
import jakarta.annotation.PostConstruct;
import org.springframework.stereotype.Service;

import java.util.*;

@Service
public class IntentClassifierService {

    private final IntentRepository intentRepository;
    private final TrainingPhraseRepository trainingPhraseRepository;
    private final Tokenizer tokenizer = new Tokenizer();
    private final StopWordsFilter stopWordsFilter = new StopWordsFilter();

    private TfIdfVectorizer vectorizer;
    // índice paralelo: vetoresDoCorpus[i] corresponde a intentCodigoPorFrase[i]
    private List<String> intentCodigoPorFrase = new ArrayList<>();
    private Map<String, Long> intentIdPorCodigo = new HashMap<>();

    public IntentClassifierService(IntentRepository intentRepository,
                                    TrainingPhraseRepository trainingPhraseRepository) {
        this.intentRepository = intentRepository;
        this.trainingPhraseRepository = trainingPhraseRepository;
    }

    /** Carrega todas as frases de treino do banco e monta o modelo TF-IDF em memória. */
    @PostConstruct
    public void carregarModelo() {
        List<Intent> intents = intentRepository.findAll();
        for (Intent intent : intents) {
            intentIdPorCodigo.put(intent.getCodigo(), intent.getId());
        }
        Map<Long, String> codigoPorId = new HashMap<>();
        for (Intent intent : intents) {
            codigoPorId.put(intent.getId(), intent.getCodigo());
        }

        List<TrainingPhrase> frases = trainingPhraseRepository.findAll();
        List<List<String>> corpusTokenizado = new ArrayList<>();
        intentCodigoPorFrase = new ArrayList<>();

        for (TrainingPhrase frase : frases) {
            List<String> tokens = stopWordsFilter.filtrar(tokenizer.tokenize(frase.getTexto()));
            corpusTokenizado.add(tokens);
            intentCodigoPorFrase.add(codigoPorId.get(frase.getIntentId()));
        }

        this.vectorizer = new TfIdfVectorizer(corpusTokenizado);
    }

    /** Recarrega o modelo (chame depois de alterar frases de treino no banco, sem reiniciar a aplicação). */
    public void recarregar() {
        carregarModelo();
    }

    public record Classificacao(String intentCodigo, double score) {}

    /**
     * Classifica a mensagem do usuário: tokeniza, vetoriza e compara (cosseno)
     * com todas as frases de treino. Retorna a intenção da frase mais parecida.
     */
    public Classificacao classificar(String mensagem) {
        List<String> tokens = stopWordsFilter.filtrar(tokenizer.tokenize(mensagem));
        double[] vetorMensagem = vectorizer.vetorizar(tokens);

        CosineSimilarity cosine = new CosineSimilarity();
        double melhorScore = -1;
        String melhorIntent = null;

        List<double[]> vetoresCorpus = vectorizer.getVetoresDoCorpus();
        for (int i = 0; i < vetoresCorpus.size(); i++) {
            double score = cosine.calcular(vetorMensagem, vetoresCorpus.get(i));
            if (score > melhorScore) {
                melhorScore = score;
                melhorIntent = intentCodigoPorFrase.get(i);
            }
        }

        if (melhorIntent == null) {
            return new Classificacao(null, 0.0);
        }
        return new Classificacao(melhorIntent, melhorScore);
    }
}
