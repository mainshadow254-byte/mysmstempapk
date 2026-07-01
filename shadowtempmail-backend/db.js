const { Pool } = require("pg");

require("dotenv").config();

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: process.env.DATABASE_URL ? { rejectUnauthorized: false } : undefined,
});

async function initDb() {
  await pool.query(`
    CREATE EXTENSION IF NOT EXISTS "pgcrypto";

    CREATE TABLE IF NOT EXISTS temp_addresses (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      email TEXT UNIQUE NOT NULL,
      local_part TEXT UNIQUE NOT NULL,
      access_token TEXT NOT NULL,
      created_at TIMESTAMPTZ DEFAULT NOW(),
      expires_at TIMESTAMPTZ NOT NULL,
      last_used_at TIMESTAMPTZ DEFAULT NOW(),
      is_active BOOLEAN DEFAULT TRUE
    );

    CREATE TABLE IF NOT EXISTS messages (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      address_id UUID REFERENCES temp_addresses(id) ON DELETE CASCADE,
      from_email TEXT,
      to_email TEXT,
      subject TEXT,
      text_body TEXT,
      html_body TEXT,
      raw_body TEXT,
      received_at TIMESTAMPTZ DEFAULT NOW(),
      is_read BOOLEAN DEFAULT FALSE
    );

    CREATE INDEX IF NOT EXISTS idx_temp_addresses_email ON temp_addresses(email);
    CREATE INDEX IF NOT EXISTS idx_temp_addresses_token ON temp_addresses(access_token);
    CREATE INDEX IF NOT EXISTS idx_messages_address_id ON messages(address_id);
    CREATE INDEX IF NOT EXISTS idx_messages_received_at ON messages(received_at);
  `);
}

module.exports = {
  pool,
  initDb,
};
