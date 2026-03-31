-- ═══════════════════════════════════════════════════════════════════════════
-- Zero-Cost Email Automation System — PostgreSQL Schema
-- Run automatically by Docker on first container start
-- ═══════════════════════════════════════════════════════════════════════════

-- ─── EXTENSION ─────────────────────────────────────────────────────────────
CREATE EXTENSION IF NOT EXISTS pg_trgm;   -- For fast text search on email bodies

-- ─── ACCOUNTS ──────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS accounts (
    id                  SERIAL PRIMARY KEY,
    account_name        VARCHAR(100)  NOT NULL,
    email_address       VARCHAR(255)  NOT NULL UNIQUE,
    provider            VARCHAR(50)   NOT NULL DEFAULT 'gmail',
    imap_host           VARCHAR(255)  DEFAULT 'imap.gmail.com',
    imap_port           INTEGER       DEFAULT 993,
    smtp_host           VARCHAR(255)  DEFAULT 'smtp.gmail.com',
    smtp_port           INTEGER       DEFAULT 587,
    username            VARCHAR(255)  NOT NULL,
    credential_ref      VARCHAR(255),
    is_active           BOOLEAN       DEFAULT TRUE,
    daily_send_count    INTEGER       DEFAULT 0,
    daily_send_limit    INTEGER       DEFAULT 450,
    last_reset_date     DATE          DEFAULT CURRENT_DATE,
    created_at          TIMESTAMPTZ   DEFAULT NOW(),
    updated_at          TIMESTAMPTZ   DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_accounts_email  ON accounts(email_address);
CREATE INDEX IF NOT EXISTS idx_accounts_active ON accounts(is_active);

-- ─── EMAIL LOGS ─────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS email_logs (
    id                  BIGSERIAL PRIMARY KEY,
    account_id          INTEGER       REFERENCES accounts(id),
    message_id          VARCHAR(500)  NOT NULL UNIQUE,
    thread_id           VARCHAR(500),
    direction           VARCHAR(10)   DEFAULT 'inbound',
    from_address        VARCHAR(500)  NOT NULL,
    to_addresses        TEXT[],
    subject             TEXT,
    body_text           TEXT,
    body_html           TEXT,
    received_at         TIMESTAMPTZ,
    processed_at        TIMESTAMPTZ   DEFAULT NOW(),

    -- Classification
    category            VARCHAR(50),
    sentiment_score     NUMERIC(4,3),
    confidence          NUMERIC(4,3),

    -- AI Draft
    draft_subject       TEXT,
    draft_body          TEXT,
    draft_reasoning     TEXT,

    -- Human-in-the-Loop
    sheets_row_id       INTEGER,
    approval_status     VARCHAR(20)   DEFAULT 'PENDING',
    approved_by         VARCHAR(100),
    approved_at         TIMESTAMPTZ,
    final_body          TEXT,

    -- Send tracking
    status              VARCHAR(30)   DEFAULT 'processing',
    sent_at             TIMESTAMPTZ,
    send_attempts       INTEGER       DEFAULT 0,
    last_error          TEXT,

    -- Token / cost tracking
    token_usage         JSONB,

    created_at          TIMESTAMPTZ   DEFAULT NOW(),
    updated_at          TIMESTAMPTZ   DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_email_message_id  ON email_logs(message_id);
CREATE INDEX IF NOT EXISTS idx_email_thread_id   ON email_logs(thread_id);
CREATE INDEX IF NOT EXISTS idx_email_status      ON email_logs(status);
CREATE INDEX IF NOT EXISTS idx_email_approval    ON email_logs(approval_status);
CREATE INDEX IF NOT EXISTS idx_email_from        ON email_logs(from_address);
CREATE INDEX IF NOT EXISTS idx_email_received    ON email_logs(received_at DESC);
CREATE INDEX IF NOT EXISTS idx_email_category    ON email_logs(category);
CREATE INDEX IF NOT EXISTS idx_email_body_trgm   ON email_logs USING gin(body_text gin_trgm_ops);

-- ─── LEADS ─────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS leads (
    id                  BIGSERIAL PRIMARY KEY,
    account_id          INTEGER       REFERENCES accounts(id),
    email_address       VARCHAR(500)  NOT NULL,
    name                VARCHAR(255),
    company             VARCHAR(255),
    domain              VARCHAR(255),
    first_seen_at       TIMESTAMPTZ   DEFAULT NOW(),
    last_seen_at        TIMESTAMPTZ   DEFAULT NOW(),
    email_count         INTEGER       DEFAULT 1,
    reply_count         INTEGER       DEFAULT 0,
    avg_sentiment       NUMERIC(4,3),
    score               INTEGER       DEFAULT 0,
    stage               VARCHAR(50)   DEFAULT 'cold',
    tags                TEXT[],
    notes               TEXT,
    crm_id              VARCHAR(255),
    unsubscribed        BOOLEAN       DEFAULT FALSE,
    unsubscribed_at     TIMESTAMPTZ,
    created_at          TIMESTAMPTZ   DEFAULT NOW(),
    updated_at          TIMESTAMPTZ   DEFAULT NOW(),
    UNIQUE(account_id, email_address)
);

CREATE INDEX IF NOT EXISTS idx_leads_email  ON leads(email_address);
CREATE INDEX IF NOT EXISTS idx_leads_stage  ON leads(stage);
CREATE INDEX IF NOT EXISTS idx_leads_score  ON leads(score DESC);
CREATE INDEX IF NOT EXISTS idx_leads_domain ON leads(domain);

-- ─── RATE LIMIT QUEUE ───────────────────────────────────────────────────────
-- Emails waiting to be sent (respects Gmail 500/day & SMTP spacing)
CREATE TABLE IF NOT EXISTS send_queue (
    id                  BIGSERIAL PRIMARY KEY,
    email_log_id        BIGINT        REFERENCES email_logs(id),
    account_id          INTEGER       REFERENCES accounts(id),
    scheduled_at        TIMESTAMPTZ   DEFAULT NOW(),
    priority            INTEGER       DEFAULT 5,   -- 1=urgent, 5=normal, 10=bulk
    status              VARCHAR(20)   DEFAULT 'queued',
    attempts            INTEGER       DEFAULT 0,
    created_at          TIMESTAMPTZ   DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_queue_status    ON send_queue(status, scheduled_at);
CREATE INDEX IF NOT EXISTS idx_queue_priority  ON send_queue(priority, scheduled_at);

-- ─── AUTO-UPDATE TRIGGER ────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DO $$ BEGIN
    CREATE TRIGGER trg_accounts_updated_at
        BEFORE UPDATE ON accounts
        FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
    CREATE TRIGGER trg_email_logs_updated_at
        BEFORE UPDATE ON email_logs
        FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
    CREATE TRIGGER trg_leads_updated_at
        BEFORE UPDATE ON leads
        FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- ─── DAILY COUNTER RESET FUNCTION ──────────────────────────────────────────
CREATE OR REPLACE FUNCTION reset_daily_send_counts()
RETURNS void AS $$
BEGIN
    UPDATE accounts
    SET daily_send_count = 0,
        last_reset_date  = CURRENT_DATE
    WHERE last_reset_date < CURRENT_DATE;
END;
$$ LANGUAGE plpgsql;

-- ─── ANALYTICS VIEW ────────────────────────────────────────────────────────
CREATE OR REPLACE VIEW v_daily_stats AS
SELECT
    DATE(processed_at)                                      AS day,
    COUNT(*)                                                AS total_processed,
    COUNT(*) FILTER (WHERE status = 'sent')                 AS sent,
    COUNT(*) FILTER (WHERE status = 'rejected')             AS rejected,
    COUNT(*) FILTER (WHERE status = 'loop_blocked')         AS loops_blocked,
    COUNT(*) FILTER (WHERE status = 'failed')               AS failed,
    COUNT(*) FILTER (WHERE category = 'spam')               AS spam_detected,
    COUNT(*) FILTER (WHERE category = 'lead')               AS leads_detected,
    COUNT(*) FILTER (WHERE category = 'urgent')             AS urgent_count,
    ROUND(AVG(sentiment_score)::numeric, 3)                 AS avg_sentiment,
    SUM(COALESCE((token_usage->>'total_tokens')::int, 0))   AS total_tokens
FROM email_logs
GROUP BY DATE(processed_at)
ORDER BY day DESC;

-- ─── SEED DEFAULT ACCOUNT ──────────────────────────────────────────────────
-- UPDATE THIS with your real email before running!
INSERT INTO accounts (account_name, email_address, provider,
    imap_host, smtp_host, username, credential_ref, daily_send_limit)
VALUES ('Primary Gmail', 'your-email@gmail.com', 'gmail',
    'imap.gmail.com', 'smtp.gmail.com',
    'your-email@gmail.com', 'Gmail App Password', 450)
ON CONFLICT (email_address) DO NOTHING;

-- ═══════════════════════════════════════════════════════════════════════════
-- Schema complete. Verify with:
--   \dt          → list all tables
--   \dv          → list all views
--   SELECT * FROM accounts;
-- ═══════════════════════════════════════════════════════════════════════════
