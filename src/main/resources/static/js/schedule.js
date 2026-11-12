/* Horário de funcionamento: monta os cartões e o status "aberto agora"
   a partir de RGC_CONFIG.HOURS (única fonte no front). */
(function () {
  'use strict';
  const HOURS = (window.RGC_CONFIG && window.RGC_CONFIG.HOURS) || [];
  const DIAS = ['domingo', 'segunda', 'terça', 'quarta', 'quinta', 'sexta', 'sábado'];

  const fmt = h => {
    const m = Math.round((h % 1) * 60);
    return String(Math.floor(h)).padStart(2, '0') + 'h' + (m ? String(m).padStart(2, '0') : '');
  };
  const range = g => (g.open == null ? 'Fechado' : fmt(g.open) + ' – ' + fmt(g.close));
  const groupOf = d => HOURS.find(g => g.days.includes(d));

  const now = new Date();
  const d = now.getDay();
  const h = now.getHours() + now.getMinutes() / 60;

  // Cartões da seção Horários
  const box = document.getElementById('hours');
  if (box) {
    box.textContent = '';
    HOURS.forEach(g => {
      const card = document.createElement('div');
      card.className = 'hour-card' + (g.days.includes(d) ? ' now' : '') + (g.open == null ? ' closed' : '');
      const t = document.createElement('h3'); t.textContent = g.label;
      const b = document.createElement('b'); b.textContent = range(g);
      card.append(t, b);
      if (g.days.includes(d)) {
        const tag = document.createElement('span'); tag.className = 'tag'; tag.textContent = 'Hoje';
        card.appendChild(tag);
      }
      box.appendChild(card);
    });
  }

  // Status no hero
  const today = groupOf(d);
  const open = !!today && today.open != null && h >= today.open && h < today.close;
  const card = document.getElementById('today');
  if (card) card.classList.toggle('open', open);
  const st = document.getElementById('st');
  if (st) st.textContent = open ? 'Aberto agora' : 'Fechado agora';

  let msg = '';
  if (open) msg = 'Hoje até ' + fmt(today.close) + '.';
  else if (today && today.open != null && h < today.open) msg = 'Abrimos hoje às ' + fmt(today.open) + '.';
  else {
    for (let i = 1; i <= 7; i++) {
      const k = (d + i) % 7, g = groupOf(k);
      if (g && g.open != null) { msg = 'Abrimos ' + (i === 1 ? 'amanhã' : DIAS[k]) + ' às ' + fmt(g.open) + '.'; break; }
    }
  }
  const st2 = document.getElementById('st2');
  if (st2) st2.textContent = msg;

  // Linha "hoje" no cartão do hero
  const line = document.getElementById('st3');
  if (line && today) line.textContent = 'Hoje (' + DIAS[d] + '): ' + range(today).replace(' – ', ' às ');
})();
