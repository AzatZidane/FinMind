export default {
  async fetch(req, env) {
    const url = new URL(req.url);

    // Health check
    if (req.method === "GET" && url.pathname === "/healthz") {
      return new Response(JSON.stringify({ ok: true, uptime: Date.now() }), {
        headers: { "Content-Type": "application/json" },
      });
    }

    // Chat proxy
    if (req.method === "POST" && url.pathname === "/v1/chat") {
      // Проверка токена
      const t = req.headers.get("x-app-token");
      if (env.APP_TOKEN && t !== env.APP_TOKEN) {
        return new Response(JSON.stringify({ error: "Unauthorized" }), {
          status: 401,
          headers: { "Content-Type": "application/json" },
        });
      }

      const body = await req.text();

      const upstream = await fetch("https://api.openai.com/v1/chat/completions", {
        method: "POST",
        headers: {
          "Authorization": `Bearer ${env.OPENAI_API_KEY}`,
          "Content-Type": "application/json",
        },
        body,
      });

      // Прокидываем ответ как есть (и JSON, и stream)
      return new Response(upstream.body, {
        status: upstream.status,
        headers: upstream.headers,
      });
    }

    // Всё остальное — 404
    return new Response("Not found", { status: 404 });
  },
};
