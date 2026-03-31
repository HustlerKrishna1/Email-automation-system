<div align="center">

# 📬 Email Automation System

**Production-grade AI email automation — fully self-hosted, $0.00/month,save $20 to $100 per month**

[![n8n](https://img.shields.io/badge/n8n-self--hosted-FF6D5A?logo=n8n&logoColor=white)](https://n8n.io)
[![Groq](https://img.shields.io/badge/Groq-Llama_3_70B-F55036)](https://console.groq.com)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-16-4169E1?logo=postgresql&logoColor=white)](https://postgresql.org)
[![Cost](https://img.shields.io/badge/monthly_cost-$0.00-brightgreen)]()
[![License](https://img.shields.io/badge/license-MIT-blue)](LICENSE)

</div>

---

## Stack

| Layer | Tool | Limit |
|---|---|---|
| Orchestration | n8n (self-hosted) | Unlimited workflows |
| AI / LLM | Groq — Llama 3 70B | 14,400 req/day free |
| Fallback LLM | Ollama — Llama 3 8B | Local, offline |
| Database | PostgreSQL 16 | Local disk |
| Approval UI | Google Sheets | 300 API req/min |
| Email I/O | Gmail IMAP / SMTP | 500 sends/day |
| Remote Access | Cloudflare Tunnel | Free, no open ports |

---
## Architecture

```
                        ┌──────────────────────────────────────────┐
                        │              n8n  (port 5678)            │
                        │                                          │
┌─────────────┐  IMAP   │  ┌─────────┐   ┌──────────┐  ┌───────┐ │
│    Gmail    │◄────────┤  │  Ingest │──►│ Classify │─►│ Draft │ │
│    IMAP /   │         │  └─────────┘   └──────────┘  └───┬───┘ │
│    SMTP     │◄────────┤                                   │     │
└─────────────┘  SMTP   │  ┌─────────┐   ┌──────────┐  ┌───▼───┐ │
                        │  │  Postgres│  │   Groq   │  │Sheets │ │
┌─────────────┐         │  │    DB   │  │   API    │  │ HITL  │ │
│   Google    │◄─Write──┤  └─────────┘   └──────────┘  └───────┘ │
│   Sheets    │──Read──►│                                          │
└─────────────┘         └──────────────────────────────────────────┘
                                          │
                        cloudflared ──► https://xxx.trycloudflare.com
```

---

## Data Flow

```
1. INGEST       →  IMAP polls every 60s for UNSEEN messages
2. DEDUPLICATE  →  SELECT by message_id — skip if already seen
3. SAFETY       →  6-layer anti-loop guard
4. CLASSIFY     →  Groq call #1 → { category, confidence, needs_reply }
5. CONTEXT      →  Load business_context.json + last 3 thread emails
6. DRAFT        →  Groq call #2 → { subject, body, reasoning }
7. HITL         →  Append to Google Sheets → human APPROVES / EDITS / REJECTS
8. SEND         →  SMTP with 45s delay, daily cap enforced in DB
9. ANALYTICS    →  Token usage, sentiment, lead score → PostgreSQL
```


---

## Installation

### 1. Prerequisites

- [Node.js LTS](https://nodejs.org)
- [PostgreSQL 16](https://www.postgresql.org/download/)
- [Groq API key](https://console.groq.com) — free, no credit card
- [Google Cloud project](https://console.cloud.google.com) — Sheets + Drive API enabled
- [Ollama](https://ollama.com/download) *(optional — offline fallback)*
- [Cloudflare account](https://dash.cloudflare.com) *(optional — remote access)*

### 2. Clone & Configure

```bash
git clone https://github.com/YOUR_USERNAME/zero-cost-email-automation.git
cd zero-cost-email-automation

cp .env.example .env

Fill in .env:

POSTGRES_PASSWORD=your_db_password
N8N_BASIC_AUTH_PASSWORD=your_n8n_password
GROQ_API_KEY=gsk_YOUR_KEY_HERE

3. Database
psql -U postgres -c "CREATE DATABASE email_automation;"
psql -U postgres -c "CREATE USER n8n_user WITH PASSWORD 'your_db_password';"
psql -U postgres -c "GRANT ALL PRIVILEGES ON DATABASE email_automation TO n8n_user;"
psql -U n8n_user -d email_automation -f sql/init.sql

4. Business Context
cp business_context.example.json business_context.json

Edit business_context.json with your company name, tone, products and FAQs.
This file is injected into every Groq prompt — it's the AI's memory of your business.

5. Install & Start n8n
npm install -g n8n
n8n start

Open http://localhost:5678 and log in.

6. Import Workflows
Go to Settings → Import Workflow and import from n8n-workflows/:

File	Purpose
workflow-a-ingest.json	Ingest → Classify → Draft → Sheets
workflow-b-send.json	Sheets poller → SMTP send
workflow-c-watchdog.json	Hourly health + alert checks
workflow-d-reset.json	Midnight daily send counter reset
7. Add Credentials in n8n
Gmail — IMAP/SMTP using App Password (Google Account → Security → App Passwords)
Google Sheets — Service Account JSON key from Google Cloud Console
Groq — HTTP Header Auth: Authorization: Bearer gsk_YOUR_KEY_HERE
Google Sheets Setup
Create a sheet named Email Automation Dashboard with these tabs:

Tab	Purpose
EmailApprovals	AI drafts — set column H to control sending
SentLog	Audit trail of all sent emails
Analytics	Daily KPIs auto-written by Workflow C
Blocklist	Addresses to never reply to
Column H status values:

Value	Action
PENDING	Awaiting review (default)
APPROVED	Send AI draft as-is
EDIT	Send the text you wrote in column G
REJECTED	Skip — do not send
ESCALATE	Trigger personal alert
Safety — Anti-Loop Guard
Every inbound email passes 6 checks before any AI call:

1. Auto-submission headers  (x-auto-submitted, auto-submitted, precedence)
2. Bot sender address       (no-reply@, noreply@, mailer-daemon@, bounce@...)
3. Auto-reply subject       (out of office:, auto-reply:, delivery status:...)
4. Own email addresses      (prevent self-reply loops)
5. Thread depth > 5         (max 5 AI replies per thread)
6. Rapid reply              (sent to this address in last 10 min)

Blocked emails are logged as status = 'loop_blocked' with a reason field.

Rate Limiting
Rule	Detail
Inter-send delay	45 seconds between sends
Daily cap	Enforced in accounts.daily_send_count before every send
Midnight reset	Cron workflow resets counter at 00:00
Warm-up	Week 1: 50/day → Week 2: 150/day → Week 3+: 450/day
Database Schema
accounts    — mailboxes, send limits, daily counters
email_logs  — every email: status, draft, approval, tokens, sentiment
leads       — engagement score, stage (cold/warm/hot/customer), CRM fields

Offline Fallback (Ollama)
When Groq is unreachable, n8n automatically reroutes to local Ollama:

ollama pull llama3:8b   # one-time download ~4.7 GB
# Ollama runs on port 11434, OpenAI-compatible API

Add an IF node before the Groq HTTP Request node:

TRUE (reachable) → https://api.groq.com/...
FALSE (down) → http://localhost:11434/v1/chat/completions
Remote Access (Cloudflare Tunnel)
cloudflared tunnel login
cloudflared tunnel create n8n-tunnel
cloudflared tunnel run n8n-tunnel
# n8n is now at https://n8n.yourdomain.com — HTTPS, no open ports

Quick test (no domain needed):

cloudflared tunnel --url http://localhost:5678

Quick-Start Checklist
☐ Install Node.js, PostgreSQL, n8n
☐ cp .env.example .env — fill in passwords + Groq key
☐ Run sql/init.sql to create schema
☐ Fill in business_context.json
☐ Enable Gmail 2FA → generate App Password
☐ Google Cloud → enable Sheets API → download service account key
☐ Create "Email Automation Dashboard" sheet with correct tabs
☐ Start n8n → import all 4 workflows → add credentials
☐ (Optional) Install Ollama → ollama pull llama3:8b
☐ (Optional) Set up Cloudflare Tunnel
☐ Send a test email → watch it in n8n execution log ✅

Project Structure
├── business_context.json          # AI memory — your company info
├── business_context.example.json
├── .env.example
├── sql/
│   └── init.sql                   # PostgreSQL schema
├── n8n-workflows/
│   ├── workflow-a-ingest.json
│   ├── workflow-b-send.json
│   ├── workflow-c-watchdog.json
│   └── workflow-d-reset.json
└── .claude/
    └── launch.json

Roadmap
 Multi-mailbox support
 Auto-unsubscribe handler
 Multi-language replies
 CRM sync (HubSpot / Notion)
 Gmail Push Notifications (real-time, no polling)
 A/B subject line testing
License
MIT — see LICENSE

<div align="center"> Built with n8n · Groq · PostgreSQL · Google Sheets </div> ```

