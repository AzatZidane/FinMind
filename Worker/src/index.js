// index.js (Cloudflare Worker, вариант под CLIENT_TOKEN)

const textEncoder = new TextEncoder();

function b64(ab) {
  let s = "";
  const bytes = new Uint8Array(ab);
  for (let i = 0; i < bytes.length; i++) s += String.fromCharCode(bytes[i]);
  return btoa(s);
}

async function hmacSHA256(key, msg) {
  const cryptoKey = await crypto.subtle.importKey(
    "raw",
    key,
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"]
  );
  const mac = await crypto.subtle.sign("HMAC", cryptoKey, textEncoder.encode(msg));
  return b64(mac);
}

function timingSafeEqual(a, b) {
  if (a.length !== b.length) return false;
  let out = 0;
  for (let i = 0; i < a.length; i++) out |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return out === 0;
}

function json(status, body, extraHeaders) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      "content-type": "application/json; charset=utf-8",
      "cache-control": "no-store",
      ...(extraHeaders || {})
    },
  });
}

async function validateClient(req, env) {
  const token = req.headers.get("x-fm-token") || "";
  const tsStr = req.headers.get("x-fm-ts") || "";
  const bundle = req.headers.get("x-fm-bundle") || "";
  const device = req.headers.get("x-fm-device") || "";

  if (!token || !tsStr) {
    return { ok: false, res: json(401, { error: "WORKER_URL/CLIENT_TOKEN not provided" }) };
  }

  const ts = Number(tsStr);
  if (!Number.isFinite(ts)) {
    return { ok: false, res: json(401, { error: "Bad timestamp" }) };
  }

  const now = Math.floor(Date.now() / 1000);
  if (Math.abs(now - ts) > 15 * 60) {
    return { ok: false, res: json(401, { error: "Token expired" }) };
  }

  if (env.ALLOWED_BUNDLES) {
    const allowed = env.ALLOWED_BUNDLES.split(",").map(s => s.trim()).filter(Boolean);
    if (bundle && !allowed.includes(bundle)) {
      return { ok: false, res: json(403, { error: "Forbidden bundle" }) };
    }
  }

  const rawSecret = textEncoder.encode(env.CLIENT_TOKEN); // <── здесь CLIENT_TOKEN
  const message = `${bundle}.${device}.${ts}`;
  const expected = await hmacSHA256(rawSecret, message);

  if (!timingSafeEqual(expected, token)) {
    return { ok: false, res: json(401, { error: "Invalid CLIENT_TOKEN" }) };
  }

  return { ok: true };
}

async function handleChat(req, env) {
  const auth = await validateClient(req, env);
  if (!auth.ok) return auth.res;

  let payload = null;
  try { payload = await req.json(); } catch {}
  if (!payload || typeof payload.text !== "string" || !payload.text.trim()) {
    return json(400, { error: "Text is required" });
  }

  const model = payload.model || "gpt-4o-mini";
  const system = payload.system || "Ты — финансовый советник. Отвечай коротко и по делу.";
  const temperature = Number.isFinite(payload.temperature) ? payload.temperature : 0.2;

  const r = await fetch("https://api.openai.com/v1/chat/completions", {
    method: "POST",
    headers: {
      "authorization": `Bearer ${env.OPENAI_API_KEY}`,
      "content-type": "application/json"
    },
    body: JSON.stringify({
      model,
      temperature,
      messages: [
        { role: "system", content: system },
        { role: "user", content: payload.text }
      ]
    })
  });

  if (!r.ok) {
    const t = await r.text().catch(() => "");
    return json(r.status, { error: "OpenAI error", detail: t || r.statusText });
  }

  const data = await r.json();
  const reply = data.choices?.[0]?.message?.content ?? "";
  return json(200, { reply, model });
}

export default {
  async fetch(req, env) {
    const url = new URL(req.url);

    if (req.method === "OPTIONS") {
      return new Response(null, {
        status: 204,
        headers: {
          "access-control-allow-origin": "*",
          "access-control-allow-headers": "content-type, x-fm-token, x-fm-ts, x-fm-bundle, x-fm-device",
          "access-control-allow-methods": "POST, OPTIONS",
          "access-control-max-age": "86400"
        }
      });
    }

    if (url.pathname === "/v1/advise" && req.method === "POST") {
      try {
        const res = await handleChat(req, env);
        res.headers.set("access-control-allow-origin", "*");
        return res;
      } catch (e) {
        return json(500, { error: "Worker failure", detail: String(e?.message || e) });
      }
    }

    return json(404, { error: "Not found" });
  }
};
