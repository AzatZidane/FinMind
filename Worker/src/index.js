// Cloudflare Worker proxy for OpenAI Chat Completions
// Supports POST /v1/chat/completions, /v1/chat, /v1/advise (+ optional trailing /)
// Auth header: x-client-token или x-app-token
// Env: OPENAI_API_KEY, CLIENT_TOKEN (или APP_TOKEN), CORS_ORIGIN (опц.: "*", "https://site1,https://site2")

export default {
  async fetch(req, env) {
    const url = new URL(req.url);
    const path = normalizePath(url.pathname);

    // CORS preflight
    if (req.method === "OPTIONS") return cors(null, 204, req, env);

    // health
    if (req.method === "GET" && path === "/healthz") {
      return cors(JSON.stringify({ ok: true, now: new Date().toISOString() }), 200, req, env, {
        "Content-Type": "application/json",
      });
    }

    // chat proxy (несколько совместимых путей)
    if (req.method === "POST" && isAllowedPath(path)) {
      // простая проверка токена: принимаем оба заголовка и сравниваем с любой из переменных
      const hdrToken = req.headers.get("x-client-token") || req.headers.get("x-app-token") || "";
      const allowed = [env.CLIENT_TOKEN, env.APP_TOKEN].filter(Boolean);
      if (allowed.length > 0 && !allowed.includes(hdrToken)) {
        return cors(JSON.stringify({ error: "Unauthorized" }), 401, req, env, {
          "Content-Type": "application/json",
        });
      }

      if (!env.OPENAI_API_KEY) {
        return cors(JSON.stringify({ error: "server_misconfigured" }), 500, req, env, {
          "Content-Type": "application/json",
        });
      }

      const bodyText = await req.text();

      const upstream = await fetch("https://api.openai.com/v1/chat/completions", {
        method: "POST",
        headers: {
          Authorization: `Bearer ${env.OPENAI_API_KEY}`,
          "Content-Type": "application/json",
        },
        body: bodyText,
      });

      // пробрасываем JSON или SSE как есть + CORS
      const headers = corsCloneHeaders(upstream.headers, req, env);
      return new Response(upstream.body, { status: upstream.status, headers });
    }

    // 404
    return cors("Not found", 404, req, env, { "Content-Type": "text/plain; charset=utf-8" });
  },
};

// ---- helpers ----
function normalizePath(p) {
  // схлопываем // и срезаем конечный /
  p = p.replace(/\/{2,}/g, "/");
  if (p.length > 1 && p.endsWith("/")) p = p.slice(0, -1);
  return p;
}

function isAllowedPath(p) {
  // поддерживаем несколько «исторических» путей
  return (
    p === "/v1/chat/completions" ||
    p === "/v1/chat" ||
    p === "/v1/advise" // был в ранних версиях клиента/тестах curl
  );
}

function getCorsOrigin(req, env) {
  const cfg = (env.CORS_ORIGIN || "*").trim();
  if (cfg === "*") return "*";
  const allowed = cfg.split(",").map((s) => s.trim());
  const origin = req.headers.get("Origin") || "";
  return allowed.includes(origin) ? origin : allowed[0] || "*";
}

function cors(body, status, req, env, extra = {}) {
  const h = new Headers(extra);
  const origin = getCorsOrigin(req, env);
  h.set("Access-Control-Allow-Origin", origin);
  h.set("Vary", "Origin");
  h.set("Access-Control-Allow-Methods", "GET,POST,OPTIONS");
  h.set(
    "Access-Control-Allow-Headers",
    req.headers.get("Access-Control-Request-Headers") ||
      "content-type,x-client-token,x-app-token"
  );
  h.set("Access-Control-Max-Age", "86400");
  return new Response(body, { status, headers: h });
}

function corsCloneHeaders(upstreamHeaders, req, env) {
  const h = new Headers();
  upstreamHeaders.forEach((v, k) => {
    const key = k.toLowerCase();
    if (key === "content-length" || key === "transfer-encoding" || key === "connection" || key === "keep-alive") {
      return;
    }
    h.set(k, v);
  });
  const origin = getCorsOrigin(req, env);
  h.set("Access-Control-Allow-Origin", origin);
  h.set("Vary", "Origin");
  h.set("Access-Control-Allow-Methods", "GET,POST,OPTIONS");
  h.set("Access-Control-Allow-Headers", "content-type,x-client-token,x-app-token");
  h.set("Access-Control-Expose-Headers", "content-type");
  return h;
}
