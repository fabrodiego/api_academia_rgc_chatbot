/* Chatbot RGC: contrato com o backend
   POST {API_BASE_URL}/api/chat
   Request : { "sessionId": string, "mensagem": string }
   Response: { "resposta": string, "intentDetectado": string|null, "score": number, "fallback": boolean } */
(function () {
  'use strict';

  const cfg = Object.assign({
    API_BASE_URL: '', CHAT_ENDPOINT: '/api/chat', HEALTH_ENDPOINT: '', USE_MOCK: false,
    DEBUG: false, TIMEOUT_MS: 15000, MAX_LENGTH: 300, CONTACT: {}
  }, window.RGC_CONFIG || {});
  const qs = new URLSearchParams(location.search);
  if (qs.has('mock'))  cfg.USE_MOCK = qs.get('mock')  !== '0';
  if (qs.has('debug')) cfg.DEBUG    = qs.get('debug') !== '0';
  const BASE = cfg.API_BASE_URL.replace(/\/$/, '');
  const CHAT_URL = BASE + cfg.CHAT_ENDPOINT;
  const HEALTH_URL = BASE + cfg.HEALTH_ENDPOINT;
  const C = cfg.CONTACT;

  const $ = id => document.getElementById(id);
  const chat = $('chat'), msgs = $('msgs'), input = $('in'), send = $('send'), fab = $('fab');
  const statusEl = $('ch-status'), banner = $('ch-banner'), counter = $('count');
  input.maxLength = cfg.MAX_LENGTH;

  /* ---------- Sessão e histórico (sessionStorage; some ao fechar a aba) ---------- */
  const store = {
    get(k) { try { return sessionStorage.getItem(k); } catch (e) { return null; } },
    set(k, v) { try { sessionStorage.setItem(k, v); } catch (e) { /* sem storage: segue sem persistir */ } },
    del(k) { try { sessionStorage.removeItem(k); } catch (e) { /* idem */ } }
  };
  function newId() {
    return 'web-' + (window.crypto && crypto.randomUUID ? crypto.randomUUID() : Math.random().toString(36).slice(2, 12));
  }
  let sessionId = store.get('rgc.sessionId') || (store.set('rgc.sessionId', newId()), store.get('rgc.sessionId')) || newId();

  let history = [];
  try { history = JSON.parse(store.get('rgc.history') || '[]'); } catch (e) { history = []; }
  if (!Array.isArray(history)) history = [];
  const saveHistory = () => store.set('rgc.history', JSON.stringify(history.slice(-40)));

  /* ---------- Chamada à API ---------- */
  class ApiError extends Error {
    constructor(kind, status) { super(kind); this.kind = kind; this.status = status; }
  }

  async function callApi(text) {
    if (cfg.USE_MOCK) return mockReply(text);
    const ctrl = new AbortController();
    const timer = setTimeout(() => ctrl.abort(), cfg.TIMEOUT_MS);
    try {
      const res = await fetch(CHAT_URL, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', 'Accept': 'application/json' },
        body: JSON.stringify({ sessionId, mensagem: text }),
        signal: ctrl.signal
      });
      if (!res.ok) throw new ApiError('http', res.status);
      const data = await res.json();
      if (!data || typeof data.resposta !== 'string') throw new ApiError('invalid');
      return data;
    } catch (e) {
      if (e instanceof ApiError) throw e;
      if (e.name === 'AbortError') throw new ApiError('timeout');
      throw new ApiError('network');
    } finally {
      clearTimeout(timer);
    }
  }

  function errorText(e) {
    const tel = C.phoneDisplay ? ' Se preferir, fale com a gente pelo ' + C.phoneDisplay + '.' : '';
    if (e.kind === 'timeout') return 'O servidor demorou para responder.' + tel;
    if (e.kind === 'http' && e.status >= 400 && e.status < 500) return 'Não consegui processar essa mensagem. Tente reescrever.';
    if (e.kind === 'http') return 'O atendimento automático está com problemas no momento.' + tel;
    if (e.kind === 'invalid') return 'Recebi uma resposta inesperada do servidor.' + tel;
    return 'Não consegui me conectar ao servidor.' + tel;
  }

  /* ---------- Saúde do backend (só mesma origem) ---------- */
  let online = true;
  function setStatus(kind) {
    statusEl.className = 'ch-status ' + kind;
    statusEl.textContent = kind === 'mock' ? 'Modo demonstração'
      : kind === 'off' ? 'Indisponível no momento' : 'Online';
    banner.hidden = kind !== 'off';
  }
  async function checkHealth() {
    if (cfg.USE_MOCK) return setStatus('mock');
    if (!cfg.HEALTH_ENDPOINT || cfg.API_BASE_URL) return setStatus('on');
    try {
      const r = await fetch(HEALTH_URL, { cache: 'no-store' });
      online = r.ok;
    } catch (e) { online = false; }
    setStatus(online ? 'on' : 'off');
  }

  /* ---------- Modo demonstração (sem backend) ---------- */
  const MOCK = [
    { intent: 'horario_funcionamento', kw: ['horario', 'funcionamento', 'abre', 'fecha', 'aberto', 'horas'],
      resp: 'Funcionamos de segunda a sexta das 6h às 22h e aos sábados das 8h às 14h. Fechamos aos domingos e feriados.' },
    { intent: 'planos_valores', kw: ['plano', 'planos', 'mensalidade', 'preco', 'valor', 'matricula', 'custa'],
      resp: 'Temos 3 planos, todos com musculação e aulas coletivas:\n• Mensal: R$ 129/mês, sem fidelidade.\n• Trimestral: R$ 109/mês.\n• Anual: R$ 89/mês, com matrícula grátis.' },
    { intent: 'personal_trainer', kw: ['personal', 'trainer', 'acompanhamento', 'instrutor'],
      resp: 'Sim, temos personal trainers credenciados. O valor é combinado direto com o profissional.' },
    { intent: 'cancelamento', kw: ['cancelar', 'cancelamento', 'trancar', 'trancamento', 'desistir'],
      resp: 'Para cancelar ou trancar, compareça à recepção com documento.' },
    { intent: 'aulas_modalidades', kw: ['aula', 'aulas', 'modalidade', 'bike', 'fitdance', 'kids', 'boxe', 'muay', 'yoga'],
      resp: 'Oferecemos RGC Bike, FitDance, RGC Kids, Boxe, Muay Thai e Yoga. Veja os detalhes na seção Aulas e modalidades.' },
    { intent: 'atendimento_humano', kw: ['atendente', 'humano', 'pessoa', 'gerente'],
      resp: 'Claro! Fale com a equipe pelo WhatsApp ' + (C.phoneDisplay || '') + ' ou passe na recepção.' }
  ];
  const norm = s => s.toLowerCase().normalize('NFD').replace(/[̀-ͯ]/g, '').replace(/[^a-z0-9\s]/g, ' ');

  async function mockReply(text) {
    await new Promise(r => setTimeout(r, 600));
    const words = norm(text).split(/\s+/);
    let best = null, hits = 0;
    MOCK.forEach(m => {
      const n = m.kw.filter(k => words.includes(k)).length;
      if (n > hits) { hits = n; best = m; }
    });
    if (!best) return { resposta: 'Não encontrei essa informação. Vou encaminhar você para um atendente humano.',
                        intentDetectado: null, score: 0, fallback: true };
    return { resposta: best.resp, intentDetectado: best.intent, score: Math.min(0.95, 0.4 + 0.25 * hits), fallback: false };
  }

  /* ---------- Interface ---------- */
  // Transforma e-mails, telefones e URLs do texto em links, sem usar innerHTML.
  const LINK_RX = /([\w.+-]+@[\w-]+(?:\.[\w-]+)+)|(\(?\d{2}\)?\s?\d{4,5}-\d{4})|(https?:\/\/[^\s]+)/g;
  function fillText(el, text) {
    let last = 0, m;
    LINK_RX.lastIndex = 0;
    while ((m = LINK_RX.exec(text))) {
      if (m.index > last) el.appendChild(document.createTextNode(text.slice(last, m.index)));
      let shown = m[0], href;
      if (m[1]) href = 'mailto:' + m[1];
      else if (m[2]) { const d = m[2].replace(/\D/g, ''); href = 'tel:+55' + d; }
      else { shown = m[3].replace(/[.,;:!?)]+$/, ''); href = shown; LINK_RX.lastIndex = m.index + shown.length; }
      const a = document.createElement('a');
      a.href = href; a.textContent = shown;
      if (m[3]) { a.target = '_blank'; a.rel = 'noopener noreferrer'; }
      el.appendChild(a);
      last = m.index + shown.length;
    }
    if (last < text.length) el.appendChild(document.createTextNode(text.slice(last)));
  }

  function scrollDown() { msgs.scrollTop = msgs.scrollHeight; }

  function add(text, who, extra) {
    const el = document.createElement('div');
    el.className = 'm ' + who + (extra ? ' ' + extra : '');
    if (who === 'bot') fillText(el, text); else el.textContent = text;
    msgs.appendChild(el);
    scrollDown();
    return el;
  }

  function remember(who, text, cls, actions) {
    history.push({ w: who, t: text, c: cls || '', a: !!actions });
    saveHistory();
  }

  function addMeta(el, data) {
    const meta = document.createElement('span');
    meta.className = 'meta';
    const score = typeof data.score === 'number' ? data.score.toFixed(2) : '-';
    meta.textContent = 'intent: ' + (data.intentDetectado || 'nenhum') + ' | score: ' + score + (data.fallback ? ' | fallback' : '');
    el.appendChild(meta);
  }

  function addTyping() {
    const el = document.createElement('div');
    el.className = 'm bot typing';
    el.setAttribute('aria-label', 'Digitando');
    for (let i = 0; i < 3; i++) el.appendChild(document.createElement('i'));
    msgs.appendChild(el);
    scrollDown();
    return el;
  }

  // Botões de atendimento humano (fallback ou intenção atendimento_humano)
  function addActions() {
    const row = document.createElement('div');
    row.className = 'actions';
    if (C.whatsapp) {
      const w = document.createElement('a');
      w.className = 'act wa'; w.textContent = 'Chamar no WhatsApp';
      w.href = 'https://wa.me/' + C.whatsapp; w.target = '_blank'; w.rel = 'noopener noreferrer';
      row.appendChild(w);
    }
    if (C.phoneTel) {
      const t = document.createElement('a');
      t.className = 'act'; t.textContent = 'Ligar';
      t.href = 'tel:' + C.phoneTel;
      row.appendChild(t);
    }
    if (row.childNodes.length) { msgs.appendChild(row); scrollDown(); }
  }

  // Sugestões de perguntas (as que ainda não foram feitas)
  const QUICK = ['Qual o horário de funcionamento?', 'Quais são os planos?', 'Tem personal trainer?',
                 'Quais aulas vocês têm?', 'Como faço para me matricular?', 'Quero falar com um atendente'];
  const asked = new Set(history.filter(h => h.w === 'me').map(h => h.t));
  function showChips(max) {
    document.querySelectorAll('.chips').forEach(c => c.remove());
    const pool = QUICK.filter(q => !asked.has(q)).slice(0, max);
    if (!pool.length) return;
    const chips = document.createElement('div'); chips.className = 'chips';
    pool.forEach(t => {
      const b = document.createElement('button'); b.type = 'button'; b.textContent = t;
      b.onclick = () => ask(t);
      chips.appendChild(b);
    });
    msgs.appendChild(chips);
    scrollDown();
  }

  const GREETING = 'Olá! Sou o assistente da RGC Training. Posso ajudar com horários, planos, personal trainer, aulas e cancelamento.';
  let started = false, busy = false, lastText = '';

  function start() {
    if (started) return;
    started = true;
    checkHealth();
    if (history.length) {
      history.forEach(h => {
        add(h.t, h.w, h.c);
        if (h.a) addActions();
      });
      showChips(3);
    } else {
      add(GREETING, 'bot');
      showChips(4);
    }
  }

  function toggle(show) {
    chat.classList.toggle('show', show);
    document.documentElement.classList.toggle('chat-open', show);
    fab.setAttribute('aria-expanded', show);
    if (!show) return;
    start();
    input.focus();
  }

  async function ask(text, retry) {
    if (busy) return;
    busy = true;
    lastText = text;
    document.querySelectorAll('.chips, .retry').forEach(c => c.remove());
    if (!retry) {
      add(text, 'me');
      remember('me', text);
      asked.add(text);
    }
    send.disabled = true;
    const wait = addTyping();
    try {
      const data = await callApi(text);
      wait.remove();
      const el = add(data.resposta, 'bot', data.fallback ? 'fb' : '');
      if (cfg.DEBUG) addMeta(el, data);
      const needsHuman = data.fallback || data.intentDetectado === 'atendimento_humano';
      remember('bot', data.resposta, data.fallback ? 'fb' : '', needsHuman);
      if (needsHuman) addActions();
      if (!online) { online = true; setStatus(cfg.USE_MOCK ? 'mock' : 'on'); }
      showChips(3);
    } catch (e) {
      wait.remove();
      add(errorText(e), 'bot', 'err');
      if (e.kind !== 'http' || e.status >= 500) {
        const r = document.createElement('button');
        r.type = 'button'; r.className = 'retry'; r.textContent = 'Tentar novamente';
        r.onclick = () => ask(lastText, true);
        msgs.appendChild(r);
        scrollDown();
        addActions();
      }
      console.error('[chat] falha ao chamar', CHAT_URL, e);
    } finally {
      busy = false;
      send.disabled = false;
      input.focus();
    }
  }

  function reset() {
    history = [];
    asked.clear();
    store.del('rgc.history');
    sessionId = newId();
    store.set('rgc.sessionId', sessionId);
    msgs.textContent = '';
    started = false;
    start();
    input.focus();
  }

  /* ---------- Eventos ---------- */
  fab.onclick = () => toggle(!chat.classList.contains('show'));
  $('close').onclick = () => { toggle(false); fab.focus(); };
  $('new').onclick = reset;
  document.addEventListener('keydown', e => { if (e.key === 'Escape' && chat.classList.contains('show')) toggle(false); });
  input.addEventListener('input', () => {
    const n = input.value.length;
    counter.textContent = n >= cfg.MAX_LENGTH * 0.8 ? n + '/' + cfg.MAX_LENGTH : '';
  });
  $('form').addEventListener('submit', e => {
    e.preventDefault();
    const t = input.value.trim();
    if (!t) return;
    input.value = '';
    counter.textContent = '';
    ask(t);
  });

  // API pública para o resto da página (botões "Quero este plano" etc.)
  window.RGCChat = {
    open(text) {
      toggle(true);
      if (text) ask(text);
    }
  };
})();
