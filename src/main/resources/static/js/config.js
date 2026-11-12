/* Configuração do frontend. Edite só este arquivo para apontar para o backend
   e para trocar dados de contato e horários (o site inteiro lê daqui). */
window.RGC_CONFIG = {
  // '' = mesma origem (front servido pelo próprio Spring Boot).
  // Front separado (Live Server etc.): 'http://localhost:8080' (exige CORS no backend)
  API_BASE_URL: '',
  CHAT_ENDPOINT: '/api/chat',
  // Checagem de saúde ao abrir o chat. Só roda com API_BASE_URL '' (mesma origem),
  // porque o CORS do WebConfig cobre apenas /api/**. Use '' para desligar.
  HEALTH_ENDPOINT: '/actuator/health',
  USE_MOCK: false,      // true = responde no navegador, sem backend (demonstração)
  DEBUG: false,         // true = mostra intenção e score abaixo de cada resposta
  TIMEOUT_MS: 15000,
  MAX_LENGTH: 300,

  // Contato exibido no site e nos botões do chat (fallback / atendimento humano).
  CONTACT: {
    phoneDisplay: '(48) 4002-8922',
    phoneTel: '+554840028922',
    whatsapp: '554840028922',
    email: 'contato@rgctraining.com'
  },

  // Horários por grupo de dias (0 = domingo). open/close null = fechado o dia todo.
  HOURS: [
    { label: 'Segunda a sexta',    days: [1, 2, 3, 4, 5], open: 6, close: 22 },
    { label: 'Sábado',             days: [6],             open: 8, close: 14 },
    { label: 'Domingo e feriados', days: [0],             open: null, close: null }
  ]
};
// Atalhos na URL: index.html?mock=1  |  index.html?debug=1
