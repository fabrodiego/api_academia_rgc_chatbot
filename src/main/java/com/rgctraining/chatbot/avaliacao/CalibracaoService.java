package com.rgctraining.chatbot.avaliacao;

import com.rgctraining.chatbot.model.Intent;
import com.rgctraining.chatbot.model.TrainingPhrase;
import com.rgctraining.chatbot.nlp.Preprocessador;
import com.rgctraining.chatbot.repository.IntentRepository;
import com.rgctraining.chatbot.repository.TrainingPhraseRepository;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

/**
 * Calibração por leave-one-out sobre training_phrases. Só lê o treino: os
 * casos de teste (test_cases) não entram em nenhum cálculo daqui.
 */
@Service
public class CalibracaoService {

    private final TrainingPhraseRepository trainingPhraseRepository;
    private final IntentRepository intentRepository;
    private final String negacao;

    public CalibracaoService(TrainingPhraseRepository trainingPhraseRepository,
                             IntentRepository intentRepository,
                             @Value("${chatbot.negacao:fundir_com_recuo}") String negacao) {
        this.trainingPhraseRepository = trainingPhraseRepository;
        this.intentRepository = intentRepository;
        this.negacao = negacao;
    }

    /** Roda o LOO e a varredura; devolve o CSV da curva (com a linha escolhida marcada). */
    @Transactional(readOnly = true)
    public String varreduraCsv(String modoNegacao) {
        Map<Long, String> codigoPorId = new HashMap<>();
        for (Intent i : intentRepository.findAll()) codigoPorId.put(i.getId(), i.getCodigo());
        List<String> textos = new ArrayList<>();
        List<String> intents = new ArrayList<>();
        for (TrainingPhrase f : trainingPhraseRepository.findAll()) {
            textos.add(f.getTexto());
            intents.add(codigoPorId.get(f.getIntentId()));
        }
        Preprocessador pre = new Preprocessador(Preprocessador.ModoNegacao.de(modoNegacao == null ? negacao : modoNegacao));
        List<CalibradorLoo.Amostra> amostras = CalibradorLoo.executar(textos, intents, pre, 3);
        List<CalibradorLoo.Linha> linhas = CalibradorLoo.varrer(amostras);
        return CalibradorLoo.csv(linhas, CalibradorLoo.escolher(linhas));
    }
}
