async function streamToText(stream) {
  return await new Response(stream).text();
}

function getHeader(headers, name) {
  return headers.get(name) || headers.get(name.toLowerCase()) || "";
}

function extractTextFromRaw(raw) {
  if (!raw) return "";

  const parts = raw.split(/\r?\n\r?\n/);
  if (parts.length < 2) return raw;

  let body = parts.slice(1).join("\n\n");
  body = body
    .replace(/=\r?\n/g, "")
    .replace(/=20/g, " ")
    .replace(/=0A/g, "\n")
    .replace(/=0D/g, "\r")
    .replace(/=3D/g, "=");

  return body.trim();
}

export default {
  async email(message, env, ctx) {
    try {
      const raw = await streamToText(message.raw);
      const subject = getHeader(message.headers, "subject") || "(No subject)";
      const from = message.from || getHeader(message.headers, "from");
      const to = message.to || getHeader(message.headers, "to");
      const text = extractTextFromRaw(raw);

      const payload = {
        from,
        to,
        subject,
        text,
        html: null,
        raw,
      };

      const response = await fetch(env.RAILWAY_INBOUND_URL, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "x-worker-secret": env.WORKER_SECRET,
        },
        body: JSON.stringify(payload),
      });

      if (!response.ok) {
        console.log("Railway API failed", response.status, await response.text());
      }
    } catch (error) {
      console.log("ShadowTempMail Worker error:", error.message);
    }
  },
};
