/* Demo técnica: chat + painel "Como o bot decidiu" (POST /api/chat/explicar). */
(function () {
  'use strict';
  const CFG = window.RGC_CONFIG || {};
  const URL_EXPLICAR = (CFG.API_BASE_URL || '') + (CFG.CHAT_ENDPOINT || '/api/chat') + '/explicar';
  const sessionId = (window.crypto && crypto.randomUUID) ? crypto.randomUUID()
    : 's' + Date.now().toString(36) + Math.random().toString(36).slice(2);

  const $ = id => document.getElementById(id);
  const log = $('log'), out = $('out'), input = $('in'), send = $('send');

  const MOTIVOS = {
    ok: 'Passou nas verificações: o score é alto e a primeira intenção se destaca das demais.',
    score_baixo: 'O score da melhor intenção ficou abaixo do limiar → encaminhou para humano.',
    margem_pequena: 'Margem pequena entre as 2 primeiras intenções → encaminhou para humano.',
    tokens_desconhecidos: 'Quase nenhuma palavra da pergunta é conhecida pelo vocabulário → encaminhou para humano.',
    contexto: 'Decisão influenciada pelo contexto da conversa.'
  };

  function el(tag, cls, text) {
    const e = document.createElement(tag);
    if (cls) e.className = cls;
    if (text != null) e.textContent = text;
    return e;
  }
  function add(text, cls) {
    const m = el('div', 'msg ' + cls, text);
    log.appendChild(m);
    log.scrollTop = log.scrollHeight;
    return m;
  }
  const pct = v => (Math.max(0, Math.min(1, Number(v) || 0)) * 100);
  const num = (v, d) => (Number(v) || 0).toFixed(d == null ? 2 : d);

  function step(title) {
    const s = el('section', 'step');
    s.appendChild(el('h3', null, title));
    return s;
  }

  function render(r, msg) {
    out.textContent = '';

    const s1 = step('1 · Pré-processamento');
    s1.appendChild(el('p', 'orig', '“' + msg + '”'));
    const ul = el('ul', 'tokens');
    ul.setAttribute('aria-label', 'Tokens');
    (r.tokens || []).forEach(t => ul.appendChild(el('li', null, t)));
    s1.appendChild(ul);
    if (!(r.tokens || []).length) s1.appendChild(el('p', 'muted', 'Nenhum token restou após o pré-processamento.'));
    s1.appendChild(el('p', 'muted', 'Fração de palavras conhecidas: ' + Math.round(pct(r.fracaoConhecida)) + '%'));
    out.appendChild(s1);

    const s2 = step('2 · Similaridade (top 3)');
    const bars = el('ul', 'bars');
    (r.top || []).slice(0, 3).forEach(t => {
      const li = el('li', 'bar-row');
      li.appendChild(el('span', 'nm', t.intent));
      const tr = el('div', 'track');
      tr.setAttribute('role', 'img');
      tr.setAttribute('aria-label', t.intent + ': ' + num(t.score));
      const f = el('div', 'fill'); f.style.width = pct(t.score) + '%';
      tr.appendChild(f);
      const th = el('div', 'thr'); th.style.left = pct(r.limiar) + '%';
      tr.appendChild(th);
      li.appendChild(tr);
      li.appendChild(el('span', 'lat', num(t.score)));
      bars.appendChild(li);
    });
    s2.appendChild(bars);
    const lg = el('p', 'thr-legend');
    const b = el('b', null, 'Linha tracejada'); lg.appendChild(b);
    lg.appendChild(document.createTextNode(' = limiar mínimo (' + num(r.limiar) + ').'
      + (r.margemMinima > 0
        ? ' Margem mínima exigida entre 1ª e 2ª: ' + num(r.margemMinima) + ' (observada: ' + num(r.margem) + ').'
        : ' Regra de margem desligada (margem observada entre 1ª e 2ª: ' + num(r.margem) + ').')));
    s2.appendChild(lg);
    out.appendChild(s2);

    const s3 = step('3 · Decisão');
    const v = el('div', 'verdict');
    const resp = r.decisao === 'resposta';
    v.appendChild(el('span', 'badge ' + (resp ? 'ok' : 'fb'), resp ? 'Respondeu' : 'Fallback'));
    const txt = el('div');
    txt.appendChild(el('p', null, resp
      ? 'Respondeu com a intenção “' + r.intent + '”. ' + (MOTIVOS[r.motivo] || '')
      : (MOTIVOS[r.motivo] || 'Motivo: ' + r.motivo)));
    v.appendChild(txt);
    s3.appendChild(v);
    s3.appendChild(el('p', 'muted', 'Latência: ' + (r.latenciaMs != null ? r.latenciaMs : '?') + ' ms · motivo técnico: ' + r.motivo));
    out.appendChild(s3);
  }

  async function ask(text) {
    text = (text || '').trim();
    if (!text) return;
    add(text, 'u');
    input.value = '';
    send.disabled = true;
    const wait = add('…', 'b');
    try {
      const ctl = new AbortController();
      const to = setTimeout(() => ctl.abort(), CFG.TIMEOUT_MS || 15000);
      const res = await fetch(URL_EXPLICAR, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ sessionId, mensagem: text }),
        signal: ctl.signal
      });
      clearTimeout(to);
      if (!res.ok) throw new Error('HTTP ' + res.status);
      const r = await res.json();
      wait.textContent = r.resposta || '(sem resposta)';
      render(r, text);
    } catch (e) {
      wait.textContent = 'Não foi possível consultar o servidor (' + e.message + ').';
      wait.classList.add('err');
    } finally {
      send.disabled = false;
      log.scrollTop = log.scrollHeight;
      input.focus();
    }
  }

  $('form').addEventListener('submit', e => { e.preventDefault(); ask(input.value); });
  document.querySelectorAll('.chip-btn').forEach(b => b.addEventListener('click', () => ask(b.textContent)));
  add('Olá! Pergunte algo sobre a academia e veja ao lado como o bot chegou na resposta.', 'b');
})();
