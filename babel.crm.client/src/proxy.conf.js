const { env } = require('process');
const { Agent } = require('https');

const target = env.ASPNETCORE_HTTPS_PORT
  ? `https://localhost:${env.ASPNETCORE_HTTPS_PORT}`
  : env.ASPNETCORE_URLS
    ? env.ASPNETCORE_URLS.split(';')[0]
    : 'https://localhost:7263';

// En desarrollo Angular reenvía /api al backend de .NET (mismo origen para la cookie de sesión).
const PROXY_CONFIG = [
  {
    context: ['/api', '/openapi'],
    target,
    secure: false,
    agent: new Agent({ keepAlive: true }),
  },
];

module.exports = PROXY_CONFIG;
