# GitHub Secrets Setup for AR Aging Sync

To enable automated daily sync via GitHub Actions, you need to add these secrets to your repository.

## Required Secrets

Go to: **GitHub Repo → Settings → Secrets and variables → Actions → New repository secret**

### 1. SUPABASE_URL
```
Value: https://jrlfcntftckbeqnabtqk.supabase.co
```

### 2. SUPABASE_KEY
```
Value: sb_publishable_tLLBpa5_NFhtoyPfWOCyHQ_5K-jEDME
```

### 3. AZURE_TENANT_ID
```
Value: aa7c3a1e-074a-4a58-89ab-e9862ca083f6
```

### 4. AZURE_CLIENT_ID
```
Value: 06a75972-ae22-4740-b511-8316a9a3c46c
```

### 5. AZURE_CLIENT_SECRET
```
Value: <get from /Users/ali/clawd/hop-dashboards/automation/.env>
```

## How to Add Secrets

1. Go to your GitHub repository: https://github.com/alikaaba-bit/hop-dashboards
2. Click **Settings** (top right)
3. In left sidebar, click **Secrets and variables** → **Actions**
4. Click **New repository secret** button
5. Enter **Name** (e.g., `SUPABASE_URL`)
6. Enter **Secret** value
7. Click **Add secret**
8. Repeat for all 5 secrets

## Verify Setup

After adding all secrets:

1. Go to **Actions** tab
2. Click **Sync AR Aging Report** workflow
3. Click **Run workflow** → **Run workflow** button
4. Wait 2-3 minutes
5. Check if workflow succeeded (green checkmark)

## Troubleshooting

**Workflow fails with "Missing credentials"**
- Check all 5 secrets are added correctly
- Verify secret names match exactly (case-sensitive)

**Workflow fails with "Authentication failed"**
- Azure secret may have expired
- Check Azure AD app registration is active

**Workflow succeeds but no data**
- Check Supabase tables exist (run schema.sql)
- Verify SharePoint file path is correct
- Check workflow logs for detailed errors

## Manual Trigger

To test immediately:
```bash
gh workflow run sync-aging.yml
```

Or via GitHub UI:
1. Go to **Actions** tab
2. Select **Sync AR Aging Report**
3. Click **Run workflow** dropdown
4. Click **Run workflow** button

## Schedule

The workflow runs automatically:
- **Daily at 7:00 AM UTC** (11 PM PST / 2 AM EST)
- After the PO Tracker sync (6 AM UTC)

## View Logs

```bash
# List recent runs
gh run list --workflow=sync-aging.yml

# View latest run
gh run view --workflow=sync-aging.yml

# Download logs
gh run download [RUN_ID]
```

## Next Steps

Once secrets are added and workflow succeeds:
1. Data will sync daily automatically
2. Check `retail_aging_invoices` table in Supabase
3. Query data via dashboard or SQL
4. No further action needed!
