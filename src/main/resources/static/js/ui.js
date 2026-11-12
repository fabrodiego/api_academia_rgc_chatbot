/* Interações da página: menu mobile, sombra do cabeçalho, revelar ao rolar,
   botões que abrem o chat com uma pergunta pronta (data-ask) e dados de contato. */
(function () {
  'use strict';
  const C = (window.RGC_CONFIG && window.RGC_CONFIG.CONTACT) || {};

  // Dados de contato vindos do config
  document.querySelectorAll('[data-contact]').forEach(el => {
    const k = el.dataset.contact;
    if (k === 'phone')    { el.textContent = C.phoneDisplay; if (el.tagName === 'A') el.href = 'tel:' + C.phoneTel; }
    if (k === 'whatsapp') { el.href = 'https://wa.me/' + C.whatsapp; el.target = '_blank'; el.rel = 'noopener'; }
    if (k === 'email')    { el.textContent = C.email; if (el.tagName === 'A') el.href = 'mailto:' + C.email; }
    if (k === 'call')     { el.href = 'tel:' + C.phoneTel; }
    if (k === 'mail')     { el.href = 'mailto:' + C.email; }
  });

  // Cabeçalho
  const header = document.querySelector('header');
  const onScroll = () => header.classList.toggle('scrolled', window.scrollY > 8);
  onScroll();
  window.addEventListener('scroll', onScroll, { passive: true });

  // Menu mobile
  const burger = document.getElementById('burger');
  const nav = document.getElementById('nav');
  function setMenu(open) {
    nav.classList.toggle('open', open);
    burger.setAttribute('aria-expanded', open);
    burger.setAttribute('aria-label', open ? 'Fechar menu' : 'Abrir menu');
  }
  burger.addEventListener('click', () => setMenu(!nav.classList.contains('open')));
  nav.querySelectorAll('a').forEach(a => a.addEventListener('click', () => setMenu(false)));
  document.addEventListener('keydown', e => { if (e.key === 'Escape') setMenu(false); });

  // Revelar ao rolar (sem JS ou com redução de movimento, tudo aparece direto)
  const items = document.querySelectorAll('.reveal');
  if ('IntersectionObserver' in window && !matchMedia('(prefers-reduced-motion: reduce)').matches) {
    document.documentElement.classList.add('js-reveal');
    const io = new IntersectionObserver(es => es.forEach(e => {
      if (e.isIntersecting) { e.target.classList.add('in'); io.unobserve(e.target); }
    }), { threshold: 0.12 });
    items.forEach(el => io.observe(el));
  }

  // Botões "pergunte ao chat"
  document.querySelectorAll('[data-ask]').forEach(b => b.addEventListener('click', e => {
    e.preventDefault();
    if (window.RGCChat) window.RGCChat.open(b.dataset.ask);
  }));
  document.querySelectorAll('[data-open-chat]').forEach(b => b.addEventListener('click', e => {
    e.preventDefault();
    if (window.RGCChat) window.RGCChat.open();
  }));

  const y = document.getElementById('year');
  if (y) y.textContent = new Date().getFullYear();
})();
