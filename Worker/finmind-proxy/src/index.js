const AUTH_HEADER = 'x-client-token';
const CORS_HEADERS = {
  'Access-Control-Allow-Methods': 'GET,POST,OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, Authorization, X-Client-Token',
  'Vary': 'Origin',
};
const cors = (req) => ({ 'Access-Control-Allow-Origin': req.headers.get('Origin') ?? '*', ...CORS_HEADERS });

export default {
  async fetch(request, env) {
    const url = new URL(request.url);

    // CORS preflight
    if (request.method === 'OPTIONS') {
      return new Response(null, { headers: cors(request) });
    }

    // Проверка клиентского токена
    const token = request.headers.get(AUTH_HEADER)
      ?? (request.headers.get('authorization') || '').replace(/^Bearer\s+/i, '');
    if (!token || token !== env.CLIENT_TOKEN) {
      return new Response('Unauthorized', { status: 401, headers: cors(request) });
    }

    // healthcheck
    if (url.pathname === '/ping') {
      return new Response('pong', { headers: cors(request) });
    }

    // Прокси к OpenAI (пути /v1/)
    if (url.pathname.startsWith('/v1/')) {
      const upstream = new URL('https://api.openai.com' + url.pathname + url.search);
      const hdrs = new Headers({
        'Authorization': `Bearer ${env.OPENAI_API_KEY}`,
        'Content-Type': request.headers.get('Content-Type') ?? 'application/json',
        'Accept': request.headers.get('Accept') ?? 'application/json'
      });
      const res = await fetch(upstream, {
        method: request.method,
        headers: hdrs,
        body: request.body,
        redirect: 'manual',
      });
      const out = new Headers(res.headers);
      for (const h of ['www-authenticate','alt-svc']) out.delete(h);
      const extra = cors(request);
      for (const [k,v] of Object.entries(extra)) out.set(k,v);
      return new Response(res.body, { status: res.status, headers: out });
    }

    return new Response('Not Found', { status: 404, headers: cors(request) });
  }
};