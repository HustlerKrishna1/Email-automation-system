# Credentials Checklist
## Everything you need before running setup.sh

---

### ✅ 1. Gmail App Password (FREE — 5 min)
**What it is:** A special password that lets n8n read/send your Gmail without using your main password.

**Steps:**
1. Go to: https://myaccount.google.com/security
2. Click **2-Step Verification** → Enable it if not already on
3. Click the back arrow → Search **"App passwords"**
4. App: Mail | Device: Other → Name it **"n8n Bot"**
5. Click **Generate** → Copy the 16-character code (shows once!)

**What you'll enter in setup.sh:**
- Gmail address: `your-email@gmail.com`
- App Password: `xxxx xxxx xxxx xxxx`

---

### ✅ 2. Groq API Key (FREE — 2 min, no credit card)
**What it is:** The API key for Llama 3 70B AI — runs on Groq's servers (not your laptop).

**Steps:**
1. Go to: https://console.groq.com
2. Click **Sign Up** (use Google or email)
3. Click **API Keys** → **Create API Key**
4. Name it **"email-bot"** → Copy the key

**Your key will look like:** `gsk_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx`

---

### ✅ 3. Google Sheets Setup (FREE — 10 min)
**What it is:** Your approval dashboard — you review AI drafts here before they're sent.

#### Part A: Create the Spreadsheet
1. Go to: https://sheets.google.com
2. Create a new spreadsheet named **"Email Automation Dashboard"**
3. Create these 4 tabs (sheets):
   - `EmailApprovals`
   - `Analytics`
   - `SentLog`
   - `Blocklist`
4. **Add headers to EmailApprovals tab (Row 1):**
   `Timestamp | From | From Name | Subject | Category | Confidence | Draft Subject | Draft Body | Edited Body | Status | Message ID | AI Reasoning | Sentiment | Sent At`
5. Copy the Spreadsheet ID from the URL bar:
   `https://docs.google.com/spreadsheets/d/` **`THIS_IS_YOUR_ID`** `/edit`

#### Part B: Service Account (so n8n can write to it)
1. Go to: https://console.cloud.google.com
2. Click **Select a project** → **New Project** → Name it "email-bot"
3. In the search bar, search **"Google Sheets API"** → Enable it
4. Search **"Google Drive API"** → Enable it too
5. Left menu → **IAM & Admin** → **Service Accounts**
6. Click **Create Service Account** → Name: "n8n-sheets-bot"
7. Click the service account → **Keys** tab → **Add Key** → **JSON**
8. A `.json` file downloads — keep it safe!
9. Back in your Google Sheet → **Share** button
10. Paste the service account email (looks like `n8n-sheets-bot@email-bot.iam.gserviceaccount.com`) → **Editor** access

**What you'll put in n8n:**
- Credential type: Google Sheets OAuth2 API
- Upload the downloaded JSON key file

---

### ✅ 4. (Optional) Cloudflare Account (FREE — 5 min)
**What it is:** Lets you access your n8n dashboard from your phone/another computer.

**Steps:**
1. Sign up at: https://dash.cloudflare.com (free)
2. Install cloudflared on your laptop (instructions in setup guide)
3. Run: `cloudflared tunnel login`

---

## Summary Table

| Credential | Where to Get | Time | Cost |
|---|---|---|---|
| Gmail App Password | myaccount.google.com/security | 5 min | Free |
| Groq API Key | console.groq.com | 2 min | Free |
| Google Sheets ID | sheets.google.com URL bar | 1 min | Free |
| Google Service Account JSON | console.cloud.google.com | 10 min | Free |
| Cloudflare (optional) | dash.cloudflare.com | 5 min | Free |

**Total setup time: ~20-30 minutes**
**Total monthly cost: $0.00**
