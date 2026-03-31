# n8n Credential Setup — Copy-Paste Guide
## Open n8n → http://localhost:5678 → Settings → Credentials → + Add Credential

---

## Credential 1 — Gmail IMAP (for reading inbox)
**Type:** Email (IMAP)
| Field | Value |
|---|---|
| **Credential Name** | `Gmail IMAP` |
| **User** | `your-email@gmail.com` |
| **Password** | `ihmpvcamfrpercru` |
| **Host** | `imap.gmail.com` |
| **Port** | `993` |
| **SSL/TLS** | ✅ ON |
| **Allow Self-Signed Certs** | ❌ OFF |

---

## Credential 2 — Gmail SMTP (for sending emails)
**Type:** SMTP
| Field | Value |
|---|---|
| **Credential Name** | `Gmail SMTP` |
| **User** | `your-email@gmail.com` |
| **Password** | `ihmpvcamfrpercru` |
| **Host** | `smtp.gmail.com` |
| **Port** | `587` |
| **SSL/TLS** | `STARTTLS` |

---

## Credential 3 — Groq API (AI Classification + Drafting)
**Type:** HTTP Header Auth
| Field | Value |
|---|---|
| **Credential Name** | `Groq API Key` |
| **Name** | `Authorization` |
| **Value** | `Bearer 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` |

---

## Credential 4 — PostgreSQL Local (State Database)
**Type:** PostgreSQL
| Field | Value |
|---|---|
| **Credential Name** | `PostgreSQL Local` |
| **Host** | `postgres` ← (Docker service name, NOT localhost) |
| **Port** | `5432` |
| **Database** | `email_automation` |
| **User** | `n8n_user` |
| **Password** | `8Kmfo1mo5j3ObzIfuprYUA` |
| **SSL** | ❌ OFF |

> ⚠️ Use `postgres` as the host — this is the Docker container name,
> not `localhost`. n8n runs inside Docker and sees Postgres by its service name.

---

## Credential 5 — Google Sheets Service Account
**Type:** Google Sheets API (Service Account)
| Field | Value |
|---|---|
| **Credential Name** | `Google Sheets Service Account` |
| **Service Account Email** | *(your service account email from Google Cloud Console)* |
| **Private Key** | *(paste full contents of your downloaded service account JSON key file)* |

**How to add the private key in n8n:**
1. Download your real service account JSON key from **Google Cloud Console → IAM & Admin → Service Accounts → your account → Keys → Add Key → JSON**
2. Open that downloaded JSON file
3. In n8n credential → paste the full JSON content into the **"Service Account JSON"** field
   *(n8n will extract the private key automatically)*
4. Use `service-account.example.json` in this repo only as a reference for the expected JSON format

---

## After Adding All 5 Credentials — Import Workflows

Go to **Settings → Import Workflow** and import these 3 files in order:

1. `n8n-workflows/workflow_A_ingest_classify_draft.json`
2. `n8n-workflows/workflow_B_approval_send.json`
3. `n8n-workflows/workflow_C_watchdog.json`

Then for each workflow:
- Click each **red credential warning** and select the matching credential from the list
- Toggle the workflow to **Active** (green toggle top-right)

---

## Your Spreadsheet
https://docs.google.com/spreadsheets/d/1hbONbpY1YBOOi1dOIjUkG8khfJbG2E8ojhisGRIDdUA/edit

✅ All 4 tabs already set up: EmailApprovals | SentLog | Analytics | Blocklist
✅ Headers, freeze row, Status dropdown, color coding — all done

---

## Quick Test After Activation
1. Send an email TO `your-email@gmail.com` from any other address
2. Wait up to 60 seconds (IMAP poll interval)
3. Watch n8n Executions tab for the workflow running
4. Check Google Sheet — EmailApprovals tab should show a new PENDING row
5. Change Status to `APPROVED` → within 5 min the email is sent automatically

---

## System Login Summary
| Service | URL | Login |
|---|---|---|
| n8n Dashboard | http://localhost:5678 | admin / wwjygsydwhzg |
| PostgreSQL | localhost:5432 | n8n_user / 8Kmfo1mo5j3ObzIfuprYUA |
| Google Sheet | (link above) | Krishna's Google account |
| Groq Console | https://console.groq.com | Krishna's account |
