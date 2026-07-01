const express = require("express");
const cors = require("cors");
const crypto = require("crypto");
const rateLimit = require("express-rate-limit");
const sanitizeHtml = require("sanitize-html");
const cron = require("node-cron");
const { pool, initDb } = require("./db");

require("dotenv").config();

const app = express();

app.use(cors());
app.use(express.json({ limit: "3mb" }));

const APP_NAME = process.env.APP_NAME || "ShadowTempMail";
const PORT = process.env.PORT || 3000;
const DOMAIN = process.env.DOMAIN || "hezydark.site";
const WORKER_SECRET = process.env.WORKER_SECRET;
const MAX_EXPIRY_DAYS = Number(process.env.MAX_EXPIRY_DAYS || 30);
const DEFAULT_EXPIRY_DAYS = Number(process.env.DEFAULT_EXPIRY_DAYS || 1);
const CLOUDFLARE_API_TOKEN = process.env.CLOUDFLARE_API_TOKEN;
const CLOUDFLARE_ZONE_ID = process.env.CLOUDFLARE_ZONE_ID;
const CLOUDFLARE_WORKER_NAME =
  process.env.CLOUDFLARE_WORKER_NAME || "shadowtempmail-email-worker";
const CLOUDFLARE_API_BASE = "https://api.cloudflare.com/client/v4";

const createLimiter = rateLimit({
  windowMs: 60 * 1000,
  max: 10,
  standardHeaders: true,
  legacyHeaders: false,
});

function randomLocalPart() {
  return `shadow${crypto.randomBytes(4).toString("hex")}`;
}

function randomToken() {
  return crypto.randomBytes(32).toString("hex");
}

function clampExpiryDays(days) {
  const n = Number(days || DEFAULT_EXPIRY_DAYS);
  if (!Number.isFinite(n) || n < 1) return DEFAULT_EXPIRY_DAYS;
  if (n > MAX_EXPIRY_DAYS) return MAX_EXPIRY_DAYS;
  return Math.floor(n);
}

function normalizeEmail(email) {
  return String(email || "").toLowerCase().trim();
}

function isEmailRoutingProvisioned() {
  return Boolean(CLOUDFLARE_API_TOKEN && CLOUDFLARE_ZONE_ID);
}

async function cloudflareRequest(path, options = {}) {
  if (!isEmailRoutingProvisioned()) {
    throw new Error("Cloudflare Email Routing credentials are not configured");
  }

  const response = await fetch(`${CLOUDFLARE_API_BASE}${path}`, {
    ...options,
    headers: {
      Authorization: `Bearer ${CLOUDFLARE_API_TOKEN}`,
      "Content-Type": "application/json",
      ...(options.headers || {}),
    },
  });

  const data = await response.json().catch(() => ({}));
  if (!response.ok || data.success === false) {
    const message =
      data.errors?.map((error) => error.message).join("; ") ||
      `Cloudflare API request failed with ${response.status}`;
    throw new Error(message);
  }

  return data;
}

async function createEmailRoutingRule(email) {
  if (!isEmailRoutingProvisioned()) {
    return null;
  }

  const data = await cloudflareRequest(
    `/zones/${CLOUDFLARE_ZONE_ID}/email/routing/rules`,
    {
      method: "POST",
      body: JSON.stringify({
        name: `ShadowTempMail ${email}`,
        enabled: true,
        matchers: [
          {
            type: "literal",
            field: "to",
            value: email,
          },
        ],
        actions: [
          {
            type: "worker",
            value: [CLOUDFLARE_WORKER_NAME],
          },
        ],
        priority: 0,
      }),
    },
  );

  return data.result?.id || data.result?.tag || null;
}

async function deleteEmailRoutingRule(ruleId) {
  if (!ruleId || !isEmailRoutingProvisioned()) {
    return;
  }

  await cloudflareRequest(
    `/zones/${CLOUDFLARE_ZONE_ID}/email/routing/rules/${ruleId}`,
    {
      method: "DELETE",
    },
  );
}

function extractVerificationCode(text) {
  const body = String(text || "");
  const patterns = [
    /\b(\d{6})\b/,
    /\b(\d{5})\b/,
    /\b(\d{4})\b/,
    /\b([A-Z0-9]{6})\b/,
  ];

  for (const pattern of patterns) {
    const match = body.match(pattern);
    if (match) return match[1];
  }

  return null;
}

app.get("/", (req, res) => {
  res.json({
    success: true,
    app: APP_NAME,
    status: "online",
    domain: DOMAIN,
    version: "1.0.0",
  });
});

app.get("/api/v1/health", async (req, res) => {
  try {
    await pool.query("SELECT 1");
    res.json({
      success: true,
      app: APP_NAME,
      api: "ok",
      database: "ok",
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      api: "ok",
      database: "error",
      error: error.message,
    });
  }
});

app.post("/api/v1/address", createLimiter, async (req, res) => {
  try {
    const expiryDays = clampExpiryDays(req.body.expiryDays);
    let localPart;
    let email;
    let exists = true;

    while (exists) {
      localPart = randomLocalPart();
      email = `${localPart}@${DOMAIN}`;
      const check = await pool.query(
        "SELECT id FROM temp_addresses WHERE email = $1",
        [email],
      );
      exists = check.rows.length > 0;
    }

    const accessToken = randomToken();
    const result = await pool.query(
      `
      INSERT INTO temp_addresses
      (email, local_part, access_token, expires_at)
      VALUES
      ($1, $2, $3, NOW() + ($4 || ' days')::interval)
      RETURNING
        id,
        email,
        access_token,
        created_at,
        expires_at,
        last_used_at,
        is_active
      `,
      [email, localPart, accessToken, expiryDays],
    );

    let cloudflareRuleId = null;
    try {
      cloudflareRuleId = await createEmailRoutingRule(email);
      if (cloudflareRuleId) {
        await pool.query(
          "UPDATE temp_addresses SET cloudflare_rule_id = $1 WHERE id = $2",
          [cloudflareRuleId, result.rows[0].id],
        );
      }
    } catch (error) {
      await pool.query("DELETE FROM temp_addresses WHERE id = $1", [
        result.rows[0].id,
      ]);
      console.error("Create Cloudflare route error:", error);
      return res.status(502).json({
        success: false,
        error: "Failed to provision email routing",
      });
    }

    res.json({
      success: true,
      address: {
        ...result.rows[0],
        cloudflare_rule_id: cloudflareRuleId,
        message_count: 0,
        last_message_at: null,
      },
    });
  } catch (error) {
    console.error("Create address error:", error);
    res.status(500).json({
      success: false,
      error: "Failed to create temp address",
    });
  }
});

app.get("/api/v1/inbox/:addressId", async (req, res) => {
  try {
    const { addressId } = req.params;
    const token = req.headers["x-access-token"];

    if (!token) {
      return res.status(400).json({
        success: false,
        error: "Missing access token",
      });
    }

    const addressResult = await pool.query(
      `
      SELECT
        id,
        email,
        access_token,
        created_at,
        expires_at,
        last_used_at,
        is_active
      FROM temp_addresses
      WHERE id = $1 AND access_token = $2
      `,
      [addressId, token],
    );

    if (addressResult.rows.length === 0) {
      return res.status(404).json({
        success: false,
        error: "Inbox not found",
      });
    }

    await pool.query(
      "UPDATE temp_addresses SET last_used_at = NOW() WHERE id = $1",
      [addressId],
    );

    const messagesResult = await pool.query(
      `
      SELECT
        id,
        from_email,
        to_email,
        subject,
        text_body,
        html_body,
        received_at,
        is_read
      FROM messages
      WHERE address_id = $1
      ORDER BY received_at DESC
      `,
      [addressId],
    );

    const messages = messagesResult.rows.map((message) => ({
      ...message,
      code: extractVerificationCode(message.text_body || message.subject || ""),
    }));

    res.json({
      success: true,
      address: addressResult.rows[0],
      messages,
    });
  } catch (error) {
    console.error("Inbox error:", error);
    res.status(500).json({
      success: false,
      error: "Failed to load inbox",
    });
  }
});

app.get("/api/v1/message/:messageId", async (req, res) => {
  try {
    const { messageId } = req.params;
    const token = req.headers["x-access-token"];

    if (!token) {
      return res.status(400).json({
        success: false,
        error: "Missing access token",
      });
    }

    const result = await pool.query(
      `
      SELECT
        m.id,
        m.from_email,
        m.to_email,
        m.subject,
        m.text_body,
        m.html_body,
        m.received_at,
        m.is_read
      FROM messages m
      JOIN temp_addresses a ON a.id = m.address_id
      WHERE m.id = $1 AND a.access_token = $2
      `,
      [messageId, token],
    );

    if (result.rows.length === 0) {
      return res.status(404).json({
        success: false,
        error: "Message not found",
      });
    }

    await pool.query("UPDATE messages SET is_read = TRUE WHERE id = $1", [
      messageId,
    ]);

    const message = result.rows[0];

    res.json({
      success: true,
      message: {
        ...message,
        code: extractVerificationCode(
          `${message.subject || ""}\n${message.text_body || ""}`,
        ),
      },
    });
  } catch (error) {
    console.error("Message error:", error);
    res.status(500).json({
      success: false,
      error: "Failed to load message",
    });
  }
});

app.patch("/api/v1/address/:addressId/extend", async (req, res) => {
  try {
    const { addressId } = req.params;
    const token = req.headers["x-access-token"];
    const expiryDays = clampExpiryDays(req.body.expiryDays);

    if (!token) {
      return res.status(400).json({
        success: false,
        error: "Missing access token",
      });
    }

    const result = await pool.query(
      `
      UPDATE temp_addresses
      SET
        expires_at = NOW() + ($1 || ' days')::interval,
        last_used_at = NOW(),
        is_active = TRUE
      WHERE id = $2 AND access_token = $3
      RETURNING
        id,
        email,
        access_token,
        created_at,
        expires_at,
        last_used_at,
        is_active
      `,
      [expiryDays, addressId, token],
    );

    if (result.rows.length === 0) {
      return res.status(404).json({
        success: false,
        error: "Address not found",
      });
    }

    res.json({
      success: true,
      address: result.rows[0],
    });
  } catch (error) {
    console.error("Extend error:", error);
    res.status(500).json({
      success: false,
      error: "Failed to reuse address",
    });
  }
});

app.delete("/api/v1/address/:addressId", async (req, res) => {
  try {
    const { addressId } = req.params;
    const token = req.headers["x-access-token"];

    if (!token) {
      return res.status(400).json({
        success: false,
        error: "Missing access token",
      });
    }

    const result = await pool.query(
      "DELETE FROM temp_addresses WHERE id = $1 AND access_token = $2 RETURNING id, cloudflare_rule_id",
      [addressId, token],
    );

    if (result.rows.length === 0) {
      return res.status(404).json({
        success: false,
        error: "Address not found",
      });
    }

    try {
      await deleteEmailRoutingRule(result.rows[0].cloudflare_rule_id);
    } catch (error) {
      console.error("Delete Cloudflare route error:", error);
    }

    res.json({
      success: true,
    });
  } catch (error) {
    console.error("Delete error:", error);
    res.status(500).json({
      success: false,
      error: "Failed to delete address",
    });
  }
});

app.post("/api/v1/inbound/cloudflare", async (req, res) => {
  try {
    const secret = req.headers["x-worker-secret"];

    if (!WORKER_SECRET || secret !== WORKER_SECRET) {
      return res.status(401).json({
        success: false,
        error: "Unauthorized",
      });
    }

    const { from, to, subject, text, html, raw } = req.body;

    if (!to) {
      return res.status(400).json({
        success: false,
        error: "Missing recipient",
      });
    }

    const recipient = normalizeEmail(to);
    const addressResult = await pool.query(
      `
      SELECT id
      FROM temp_addresses
      WHERE LOWER(email) = $1
      AND is_active = TRUE
      AND expires_at > NOW()
      `,
      [recipient],
    );

    if (addressResult.rows.length === 0) {
      return res.json({
        success: true,
        stored: false,
        reason: "Address not found or expired",
      });
    }

    const cleanHtml = html
      ? sanitizeHtml(html, {
          allowedTags: sanitizeHtml.defaults.allowedTags.concat(["img"]),
          allowedAttributes: {
            a: ["href", "name", "target"],
            img: ["src", "alt"],
          },
          allowedSchemes: ["http", "https", "mailto"],
        })
      : null;

    await pool.query(
      `
      INSERT INTO messages
      (
        address_id,
        from_email,
        to_email,
        subject,
        text_body,
        html_body,
        raw_body
      )
      VALUES
      ($1, $2, $3, $4, $5, $6, $7)
      `,
      [
        addressResult.rows[0].id,
        from || "",
        recipient,
        subject || "(No subject)",
        text || "",
        cleanHtml,
        raw || "",
      ],
    );

    res.json({
      success: true,
      stored: true,
    });
  } catch (error) {
    console.error("Inbound email error:", error);
    res.status(500).json({
      success: false,
      error: "Failed to receive email",
    });
  }
});

app.get("/api/v1/recent/messages", async (req, res) => {
  try {
    const token = req.headers["x-access-token"];

    if (!token) {
      return res.status(400).json({
        success: false,
        error: "Missing access token",
      });
    }

    const result = await pool.query(
      `
      SELECT
        m.id,
        m.from_email,
        m.to_email,
        m.subject,
        m.text_body,
        m.received_at,
        m.is_read
      FROM messages m
      JOIN temp_addresses a ON a.id = m.address_id
      WHERE a.access_token = $1
      ORDER BY m.received_at DESC
      LIMIT 20
      `,
      [token],
    );

    res.json({
      success: true,
      messages: result.rows.map((message) => ({
        ...message,
        code: extractVerificationCode(
          `${message.subject || ""}\n${message.text_body || ""}`,
        ),
      })),
    });
  } catch (error) {
    console.error("Recent messages error:", error);
    res.status(500).json({
      success: false,
      error: "Failed to load recent messages",
    });
  }
});

cron.schedule("*/30 * * * *", async () => {
  try {
    const expiredRoutes = await pool.query(`
      SELECT cloudflare_rule_id
      FROM temp_addresses
      WHERE is_active = TRUE
      AND expires_at <= NOW()
      AND cloudflare_rule_id IS NOT NULL
    `);

    for (const row of expiredRoutes.rows) {
      try {
        await deleteEmailRoutingRule(row.cloudflare_rule_id);
      } catch (error) {
        console.error("Expired Cloudflare route cleanup failed:", error);
      }
    }

    await pool.query(`
      UPDATE temp_addresses
      SET is_active = FALSE
      WHERE expires_at <= NOW()
    `);
    await pool.query(`
      DELETE FROM temp_addresses
      WHERE expires_at <= NOW() - INTERVAL '14 days'
    `);
    console.log("ShadowTempMail cleanup complete");
  } catch (error) {
    console.error("Cleanup failed:", error);
  }
});

async function start() {
  try {
    await initDb();
    app.listen(PORT, () => {
      console.log(`${APP_NAME} API running on port ${PORT}`);
    });
  } catch (error) {
    console.error("Failed to start ShadowTempMail API:", error);
    process.exit(1);
  }
}

start();
