const ALLOWED_EVENTS = new Set(["install", "update_success", "update_failed"]);

function json(status, body) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      "content-type": "application/json; charset=utf-8",
      "cache-control": "no-store",
    },
  });
}

function text(status, body = "") {
  return new Response(status === 204 || status === 304 ? null : body, {
    status,
    headers: {
      "cache-control": "no-store",
    },
  });
}

function dayKey(date = new Date()) {
  return date.toISOString().slice(0, 10);
}

function cleanDimension(value, fallback = "unknown") {
  if (typeof value !== "string") {
    return fallback;
  }

  const base = value.split(/[\\/]/).pop() || fallback;
  const cleaned = base.toLowerCase().replace(/[^a-z0-9._-]/g, "_").slice(0, 40);
  return cleaned || fallback;
}

function cleanVersion(value, pattern, fallback = "unknown") {
  if (typeof value !== "string") {
    return fallback;
  }

  const trimmed = value.trim();
  return pattern.test(trimmed) ? trimmed : fallback;
}

function cleanInstallName(value) {
  const cleaned = cleanDimension(value);
  return cleaned === "asdf" || cleaned === "asdff" ? cleaned : "other";
}

function cleanConflictFallback(value) {
  return value === true ? "true" : "false";
}

function aggregateKey(payload) {
  const parts = [
    "v1",
    dayKey(),
    payload.event,
    cleanVersion(payload.human_version, /^[0-9]+[.][0-9]+[.][0-9]+$/),
    cleanVersion(payload.update_version, /^[0-9]+$/),
    cleanInstallName(payload.install_name),
    cleanDimension(payload.os),
    cleanDimension(payload.shell),
    cleanConflictFallback(payload.conflict_fallback),
  ];

  return parts.join(":");
}

async function incrementAggregate(env, key) {
  const store = env.ASDF_ANALYTICS_KV || env.ASDF_ANALYTICS;
  if (!store) {
    return;
  }

  const current = Number.parseInt((await store.get(key)) || "0", 10);
  const next = Number.isFinite(current) && current >= 0 ? current + 1 : 1;
  await store.put(key, String(next));
}

export default {
  async fetch(request, env) {
    const url = new URL(request.url);

    if (request.method === "OPTIONS") {
      return text(204);
    }

    if (request.method !== "POST" || url.pathname !== "/event") {
      return text(404);
    }

    const contentLength = Number.parseInt(request.headers.get("content-length") || "0", 10);
    if (contentLength > 2048) {
      return json(413, { error: "payload_too_large" });
    }

    let payload;
    try {
      payload = await request.json();
    } catch {
      return json(400, { error: "invalid_json" });
    }

    if (!payload || typeof payload !== "object" || !ALLOWED_EVENTS.has(payload.event)) {
      return json(400, { error: "unknown_event" });
    }

    await incrementAggregate(env, aggregateKey(payload));
    return text(204);
  },
};
