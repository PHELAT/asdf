const ALLOWED_EVENTS = new Set(["install", "update_success", "update_failed"]);
const MAX_BODY_BYTES = 2048;
const ANALYTICS_BINDING = "ASDF_ANALYTICS";

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

function cleanDimension(value, fallback = "unknown") {
  if (typeof value !== "string") {
    return fallback;
  }

  const base = value.split(/[\\/]/).pop() || fallback;
  const cleaned = base.toLowerCase().replace(/[^a-z0-9._-]/g, "_").slice(0, 40);
  return cleaned || fallback;
}

function cleanVersion(value, pattern, maxLength, fallback = "unknown") {
  if (typeof value !== "string") {
    return fallback;
  }

  const trimmed = value.trim();
  if (trimmed.length > maxLength) {
    return fallback;
  }

  return pattern.test(trimmed) ? trimmed : fallback;
}

function cleanInstallName(value) {
  const cleaned = cleanDimension(value);
  return cleaned === "asdf" || cleaned === "asdff" ? cleaned : "other";
}

function cleanConflictFallback(value) {
  return value === true ? "true" : "false";
}

async function readJsonBody(request) {
  const contentLength = request.headers.get("content-length");
  if (contentLength !== null) {
    if (!/^[0-9]+$/.test(contentLength)) {
      return { error: json(413, { error: "invalid_payload_size" }) };
    }

    const length = Number.parseInt(contentLength, 10);
    if (length <= 0 || length > MAX_BODY_BYTES) {
      return { error: json(413, { error: "invalid_payload_size" }) };
    }
  }

  const body = await request.text();
  if (new TextEncoder().encode(body).length > MAX_BODY_BYTES) {
    return { error: json(413, { error: "invalid_payload_size" }) };
  }

  try {
    return { payload: JSON.parse(body) };
  } catch {
    return { error: json(400, { error: "invalid_json" }) };
  }
}

function cleanPayload(payload) {
  return {
    event: payload.event,
    humanVersion: cleanVersion(payload.human_version, /^[0-9]+[.][0-9]+[.][0-9]+$/, 20),
    updateVersion: cleanVersion(payload.update_version, /^[0-9]+$/, 20),
    installName: cleanInstallName(payload.install_name),
    os: cleanDimension(payload.os),
    shell: cleanDimension(payload.shell),
    conflictFallback: cleanConflictFallback(payload.conflict_fallback),
  };
}

function analyticsIndex(event) {
  return [
    event.event,
    event.humanVersion,
    event.updateVersion,
    event.installName,
    event.conflictFallback,
  ].join(":");
}

function writeAnalyticsEvent(env, event) {
  const analytics = env[ANALYTICS_BINDING];
  if (!analytics || typeof analytics.writeDataPoint !== "function") {
    console.error(`missing ${ANALYTICS_BINDING} Analytics Engine binding`);
    return false;
  }

  try {
    analytics.writeDataPoint({
      blobs: [
        event.event,
        event.humanVersion,
        event.updateVersion,
        event.installName,
        event.os,
        event.shell,
        event.conflictFallback,
      ],
      doubles: [1],
      indexes: [analyticsIndex(event)],
    });
  } catch (error) {
    console.error("failed to write Analytics Engine data point", error);
    return false;
  }

  return true;
}

export default {
  async fetch(request, env) {
    const url = new URL(request.url);

    if (request.method === "OPTIONS" && url.pathname === "/event") {
      return text(204);
    }

    if (request.method !== "POST" || url.pathname !== "/event") {
      return text(404);
    }

    const { payload, error } = await readJsonBody(request);
    if (error) {
      return error;
    }

    if (!payload || typeof payload !== "object" || Array.isArray(payload) || !ALLOWED_EVENTS.has(payload.event)) {
      return json(400, { error: "unknown_event" });
    }

    if (!writeAnalyticsEvent(env, cleanPayload(payload))) {
      return json(500, { error: "analytics_not_configured" });
    }

    return text(204);
  },
};
