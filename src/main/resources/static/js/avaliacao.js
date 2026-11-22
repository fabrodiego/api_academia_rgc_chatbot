/* Avaliação: chama /api/avaliacao* com X-Admin-Key (chave só em memória). */
(function () {
  'use strict';
  const CFG = window.RGC_CONFIG || {};
  const BASE = (CFG.API_BASE_URL || '') + '/api/avaliacao';
  const $ = id => document.getElementById(id);
  const statusEl = $('status'), result = $('result'), keyEl = $('key');
  const buttons = document.querySelectorAll('[data-act]');

  function el(tag, cls, text) {
    const e = document.createElement(tag);
    if (cls) e.className = cls;
    if (text != null) e.textContent = text;
    return e;
  }
  const isNum = v => typeof v === 'number' && isFinite(v);
  const pc = v => isNum(v) ? (v * 100).toFixed(1).replace('.', ',') + '%' : '—';
  const txt = v => (v == null || v === '') ? '(fallback)' : String(v);
  const obj = v => (v && typeof v === 'object' && !Array.isArray(v)) ? v : {};

  function setStatus(msg, kind) {
    statusEl.textContent = msg;
    statusEl.className = kind || '';
  }

  async function call(path, opts) {
    const key = keyEl.value;
    if (!key) { setStatus('Informe a chave de administrador.', 'err'); keyEl.focus(); return null; }
    buttons.forEach(b => b.disabled = true);
    try {
      const res = await fetch(BASE + path, Object.assign({ headers: { 'X-Admin-Key': key } }, opts));
      if (res.status === 401 || res.status === 403) {
        setStatus('Chave inválida ou ausente (HTTP ' + res.status + '). Confira a chave de administrador.', 'err');
        return null;
      }
      if (res.status === 404) { setStatus('Nada encontrado (HTTP 404). Execute os testes primeiro ou o recurso ainda não existe.', 'err'); return null; }
      if (!res.ok) { setStatus('O servidor respondeu com erro (HTTP ' + res.status + ').', 'err'); return null; }
      return res;
    } catch (e) {
      setStatus('Falha de rede: ' + e.message, 'err');
      return null;
    } finally {
      buttons.forEach(b => b.disabled = false);
    }
  }

  async function json(path, opts, okMsg, renderer) {
    setStatus('Carregando…');
    const res = await call(path, opts);
    if (!res) return;
    try {
      const data = await res.json();
      result.textContent = '';
      renderer(data);
      setStatus(okMsg, 'ok');
    } catch (e) {
      setStatus('Resposta em formato inesperado: ' + e.message, 'err');
    }
  }

  /* ---------- helpers de render ---------- */
  function table(headers, rows, caption, cls) {
    const w = el('div', 'tw');
    const t = el('table', 't' + (cls ? ' ' + cls : ''));
    if (caption) t.appendChild(el('caption', null, caption));
    const th = el('thead'), tr = el('tr');
    headers.forEach(h => {
      const c = el('th', h.n ? 'n' : '', h.t);
      c.scope = 'col';
      tr.appendChild(c);
    });
    th.appendChild(tr); t.appendChild(th);
    const tb = el('tbody');
    rows.forEach(r => tb.appendChild(r));
    t.appendChild(tb); w.appendChild(t);
    return w;
  }
  function row(cells) {
    const tr = el('tr');
    cells.forEach(c => {
      const td = el('td', c.n ? 'n' : '', c.t);
      if (c.cls) td.className += ' ' + c.cls;
      tr.appendChild(td);
    });
    return tr;
  }
  function card(label, value, sub) {
    const c = el('div', 'card');
    c.appendChild(el('b', null, value));
    c.appendChild(el('span', null, label + (sub ? ' · ' + sub : '')));
    return c;
  }
  function h2(t) { return el('h2', null, t); }

  function cards(m) {
    const w = el('div', 'cards');
    w.appendChild(card('Acurácia estrita', pc(m.acuracia), isNum(m.acertos) ? m.acertos + '/' + m.total : ''));
    w.appendChild(card('Com equivalência', pc(m.acuraciaEquivalencia), isNum(m.acertosEquivalencia) ? m.acertosEquivalencia + '/' + m.total : ''));
    if (isNum(m.taxaFallback)) w.appendChild(card('Taxa de fallback', pc(m.taxaFallback)));
    if (isNum(m.precisaoMacro)) w.appendChild(card('Precisão macro', pc(m.precisaoMacro)));
    if (isNum(m.recallMacro)) w.appendChild(card('Recall macro', pc(m.recallMacro)));
    return w;
  }

  function porTipo(pt) {
    const rows = Object.keys(obj(pt)).map(k => {
      const v = pt[k] || {};
      return row([{ t: k }, { t: isNum(v.total) ? v.total : '—', n: 1 }, { t: pc(v.acuracia), n: 1 }, { t: pc(v.acuraciaEquivalencia), n: 1 }]);
    });
    if (!rows.length) return null;
    return table([{ t: 'Tipo' }, { t: 'Casos', n: 1 }, { t: 'Estrita', n: 1 }, { t: 'Equivalência', n: 1 }], rows);
  }

  function matriz(mc) {
    mc = obj(mc);
    const exp = Object.keys(mc);
    if (!exp.length) return null;
    const cols = new Set();
    exp.forEach(e => Object.keys(obj(mc[e])).forEach(o => cols.add(o)));
    const cl = Array.from(new Set(exp.concat(Array.from(cols)))).sort();
    let max = 1;
    exp.forEach(e => Object.values(obj(mc[e])).forEach(v => { if (v > max) max = v; }));
    const w = el('div', 'tw');
    const t = el('table', 't cm');
    t.appendChild(el('caption', null, 'Linhas = intenção esperada; colunas = intenção obtida. Diagonal destacada = acertos.'));
    const hr = el('tr');
    const c0 = el('th', 'rl', 'esperada ↓ / obtida →'); c0.scope = 'col'; hr.appendChild(c0);
    cl.forEach(c => { const th = el('th', null, c); th.scope = 'col'; hr.appendChild(th); });
    const th = el('thead'); th.appendChild(hr); t.appendChild(th);
    const tb = el('tbody');
    cl.forEach(e => {
      const tr = el('tr');
      const rh = el('th', 'rl', e); rh.scope = 'row'; tr.appendChild(rh);
      cl.forEach(o => {
        const v = (mc[e] && mc[e][o]) || 0;
        const td = el('td', e === o ? 'diag' : '', v ? String(v) : '·');
        if (v) {
          const a = 0.15 + 0.7 * (v / max);
          td.style.background = e === o ? 'rgba(31,169,113,' + a + ')' : 'rgba(214,69,69,' + a + ')';
        }
        tr.appendChild(td);
      });
      tb.appendChild(tr);
    });
    t.appendChild(tb); w.appendChild(t);
    return w;
  }

  function erros(list) {
    if (!Array.isArray(list)) return null;
    if (!list.length) return el('p', 'muted', 'Nenhum erro.');
    const rows = list.map(c => row([
      { t: c.pergunta || '' }, { t: txt(c.intentEsperada) }, { t: txt(c.intentObtida) },
      { t: isNum(c.score) ? c.score.toFixed(2) : '—', n: 1 }]));
    return table([{ t: 'Pergunta' }, { t: 'Esperada' }, { t: 'Obtida' }, { t: 'Score', n: 1 }], rows);
  }

  function metricas(m) {
    m = obj(m);
    result.appendChild(h2('Resumo'));
    result.appendChild(cards(m));
    const pt = porTipo(m.porTipo);
    if (pt) { result.appendChild(h2('Por tipo de caso')); result.appendChild(pt); }
    const mc = matriz(m.matrizConfusao);
    if (mc) { result.appendChild(h2('Matriz de confusão')); result.appendChild(mc); }
    const er = erros(m.erros);
    if (er) { result.appendChild(h2('Erros (' + (m.erros || []).length + ')')); result.appendChild(er); }
    if (Array.isArray(m.acertosPorEquivalencia) && m.acertosPorEquivalencia.length) {
      result.appendChild(h2('Acertos só por equivalência (' + m.acertosPorEquivalencia.length + ')'));
      result.appendChild(erros(m.acertosPorEquivalencia));
    }
  }

  /* comparação: { tfidf:{acuracia,acuraciaEquivalencia,porTipo}, baseline:{...} } (tolerante) */
  function comparacao(d) {
    d = obj(d);
    const a = obj(d.tfidf), b = obj(d.baseline);
    result.appendChild(h2('TF-IDF × baseline'));
    const rows = [
      row([{ t: 'Acurácia estrita' }, { t: pc(a.acuracia), n: 1 }, { t: pc(b.acuracia), n: 1 }, { t: diff(a.acuracia, b.acuracia), n: 1 }]),
      row([{ t: 'Com equivalência' }, { t: pc(a.acuraciaEquivalencia), n: 1 }, { t: pc(b.acuraciaEquivalencia), n: 1 }, { t: diff(a.acuraciaEquivalencia, b.acuraciaEquivalencia), n: 1 }])
    ];
    const tipos = new Set(Object.keys(obj(a.porTipo)).concat(Object.keys(obj(b.porTipo))));
    tipos.forEach(k => {
      const x = obj(obj(a.porTipo)[k]), y = obj(obj(b.porTipo)[k]);
      rows.push(row([{ t: 'Tipo: ' + k }, { t: pc(x.acuraciaEquivalencia != null ? x.acuraciaEquivalencia : x.acuracia), n: 1 },
        { t: pc(y.acuraciaEquivalencia != null ? y.acuraciaEquivalencia : y.acuracia), n: 1 },
        { t: diff(x.acuraciaEquivalencia != null ? x.acuraciaEquivalencia : x.acuracia, y.acuraciaEquivalencia != null ? y.acuraciaEquivalencia : y.acuracia), n: 1 }]));
    });
    result.appendChild(table([{ t: 'Métrica' }, { t: 'TF-IDF', n: 1 }, { t: 'Baseline', n: 1 }, { t: 'Diferença', n: 1 }], rows,
      'Linhas por tipo usam a acurácia com equivalência (ou a estrita, se faltar).'));
    const extra = Object.keys(d).filter(k => k !== 'tfidf' && k !== 'baseline');
    if (!Object.keys(a).length && !Object.keys(b).length) {
      result.appendChild(el('p', 'muted', 'A resposta não trouxe os campos "tfidf" e "baseline". Chaves recebidas: ' + (extra.join(', ') || 'nenhuma') + '.'));
    }
  }
  function diff(a, b) {
    if (!isNum(a) || !isNum(b)) return '—';
    const d = (a - b) * 100;
    return (d > 0 ? '+' : '') + d.toFixed(1).replace('.', ',') + ' pp';
  }

  async function csv() {
    setStatus('Baixando…');
    const res = await call('/casos.csv');
    if (!res) return;
    const blob = await res.blob();
    const a = document.createElement('a');
    a.href = URL.createObjectURL(blob);
    a.download = 'casos.csv';
    document.body.appendChild(a); a.click(); a.remove();
    setTimeout(() => URL.revokeObjectURL(a.href), 2000);
    setStatus('CSV baixado.', 'ok');
  }

  const acts = {
    run: () => json('', { method: 'POST' }, 'Testes executados agora.', metricas),
    last: () => json('', {}, 'Última execução carregada.', metricas),
    cmp: () => json('/comparacao', {}, 'Comparação carregada.', comparacao),
    csv: csv
  };
  buttons.forEach(b => b.addEventListener('click', () => acts[b.dataset.act]()));
  $('keyform').addEventListener('submit', e => e.preventDefault());
})();
