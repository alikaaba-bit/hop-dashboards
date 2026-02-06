# AR Aging Report Sync - SharePoint to Supabase

Automated daily sync of Petra Brands AR Aging data from SharePoint to Supabase.

## Features

- ✅ Downloads AR Aging Report Excel from SharePoint
- ✅ Parses detailed invoice data
- ✅ Normalizes brand names (FOMIN → Fomin, HOP → House of Party)
- ✅ Upserts to Supabase (prevents duplicates)
- ✅ Creates daily snapshots for trend tracking
- ✅ Runs daily via GitHub Actions at 7 AM UTC

## Setup

### 1. Install Python Dependencies

```bash
pip install -r automation/aging/requirements.txt
```

### 2. Create Supabase Tables

Run the SQL schema in Supabase SQL Editor:
```bash
cat automation/aging/schema.sql
# Copy and paste into Supabase SQL Editor
```

This creates:
- `retail_aging_invoices` - Detailed invoice-level data
- `retail_aging_summary` - Brand/retailer summaries
- `retail_aging_snapshots` - Daily snapshots for trends
- Views: `vw_aging_overview`, `vw_aging_by_retailer`

### 3. Configure Environment Variables

Environment variables are already in `automation/.env`:
- `AZURE_TENANT_ID` - Azure AD tenant
- `AZURE_CLIENT_ID` - App registration client ID
- `AZURE_CLIENT_SECRET` - App registration secret
- `SUPABASE_URL` - Supabase project URL
- `SUPABASE_KEY` - Supabase service key

### 4. Test Manual Sync

```bash
cd automation/aging
python sync_aging.py
```

Expected output:
```
[INFO] Starting AR Aging Report Sync
[INFO] Authenticating with Microsoft Graph...
[INFO] Getting SharePoint site ID...
[INFO] Searching for file...
[INFO] Found file
[INFO] Downloading Excel file...
[INFO] Parsing Excel data...
[INFO] Parsed 471 invoices from Excel
[INFO] Syncing 471 invoices to Supabase...
[INFO] Batch 1: 100/471
[INFO] Batch 2: 200/471
...
[INFO] Creating daily snapshots...
[INFO] Created 4 snapshots
[INFO] Sync Complete
[INFO]   Invoices synced: 471
[INFO]   Brands: 4
```

### 5. GitHub Actions (Automated Daily Sync)

The workflow is already set up in `.github/workflows/sync-aging.yml`

**To enable:**
1. Add secrets to GitHub repository:
   - `SUPABASE_URL`
   - `SUPABASE_KEY`
   - `AZURE_TENANT_ID`
   - `AZURE_CLIENT_ID`
   - `AZURE_CLIENT_SECRET`

2. Workflow runs automatically at 7 AM UTC daily

3. Manual trigger:
   ```bash
   gh workflow run sync-aging.yml
   ```

## Data Structure

### retail_aging_invoices

| Column | Type | Description |
|--------|------|-------------|
| brand | TEXT | Fomin, House of Party, Roofus, EveryMood |
| retailer | TEXT | TJX, Target, KeHe, CVS, etc. |
| po_number | TEXT | Purchase order number |
| invoice_number | TEXT | Invoice number (unique per brand) |
| invoice_date | DATE | Invoice issue date |
| due_date | DATE | Payment due date |
| invoice_amount | DECIMAL | Total invoice amount |
| received | DECIMAL | Amount received |
| outstanding | DECIMAL | Amount still owed |
| days_overdue | INTEGER | Days past due date |
| aging_bucket | TEXT | Not Yet Due, 1-30 Days, 31-60 Days, 61-90 Days, 90+ Days |
| status | TEXT | Due, Not Due |
| report_date | DATE | Date report was generated |

### retail_aging_snapshots

Daily snapshots for trend analysis:
- Total outstanding per brand
- Not yet due vs overdue amounts
- Invoice counts
- Historical tracking

## Querying the Data

### JavaScript (Supabase Client)

```javascript
import { createClient } from '@supabase/supabase-js';

const supabase = createClient(SUPABASE_URL, SUPABASE_KEY);

// Get all aging invoices for a brand
const { data } = await supabase
  .from('retail_aging_invoices')
  .select('*')
  .eq('brand', 'House of Party')
  .order('outstanding', { ascending: false });

// Get aging overview
const { data: overview } = await supabase
  .from('vw_aging_overview')
  .select('*');

// Get aging by retailer
const { data: retailers } = await supabase
  .from('vw_aging_by_retailer')
  .select('*')
  .order('total_outstanding', { ascending: false });

// Get historical trend
const { data: trend } = await supabase
  .from('retail_aging_snapshots')
  .select('*')
  .eq('brand', 'Fomin')
  .order('snapshot_date', { ascending: false })
  .limit(30);  // Last 30 days
```

### SQL Queries

```sql
-- Total outstanding by brand
SELECT
  brand,
  SUM(outstanding) as total_outstanding,
  COUNT(*) as invoice_count
FROM retail_aging_invoices
WHERE outstanding > 0
GROUP BY brand
ORDER BY total_outstanding DESC;

-- Worst aging (90+ days)
SELECT
  brand,
  retailer,
  invoice_number,
  outstanding,
  days_overdue
FROM retail_aging_invoices
WHERE aging_bucket = '90+ Days'
ORDER BY outstanding DESC;

-- Aging trend (last 30 days)
SELECT
  snapshot_date,
  brand,
  total_outstanding,
  overdue_total
FROM retail_aging_snapshots
WHERE snapshot_date >= CURRENT_DATE - INTERVAL '30 days'
ORDER BY snapshot_date DESC, brand;

-- Retailer performance
SELECT
  retailer,
  COUNT(DISTINCT brand) as brands,
  SUM(outstanding) as total_outstanding,
  AVG(days_overdue) as avg_days_overdue
FROM retail_aging_invoices
WHERE outstanding > 0
GROUP BY retailer
HAVING SUM(outstanding) > 10000
ORDER BY total_outstanding DESC;
```

## Current State (As of Last Sync)

**Brands:**
- Fomin: 285 invoices, $689K outstanding ($39K at 90+ days - KeHe issue)
- House of Party: 134 invoices, $1.98M outstanding ($78K in 1-30 days)
- Roofus: 35 invoices, $155K outstanding (minor aging)
- EveryMood: 17 invoices, $166K outstanding (all current)

**Top Retailers:**
- TJX: 181 invoices
- Target: 89 invoices
- Bealls: 49 invoices
- CVS: 33 invoices
- KeHE: 32+ invoices (Fomin aging issue)

## Monitoring

### View Logs

```bash
# Local test runs
tail -f ../logs/aging_sync.log

# GitHub Actions runs
gh run list --workflow=sync-aging.yml
gh run view [RUN_ID] --log
```

### Check Sync Status

```sql
-- Last sync time
SELECT MAX(synced_at) as last_sync
FROM retail_aging_invoices;

-- Today's snapshot
SELECT * FROM retail_aging_snapshots
WHERE snapshot_date = CURRENT_DATE;

-- Record counts
SELECT
  (SELECT COUNT(*) FROM retail_aging_invoices) as invoices,
  (SELECT COUNT(*) FROM retail_aging_snapshots) as snapshots;
```

## Troubleshooting

**"File not found"**
- Check `SHAREPOINT_SITE_PATH` and file name in script
- Verify Azure app has `Sites.Read.All` permission
- Check file exists at SharePoint URL

**"Authentication failed"**
- Verify Azure credentials in `.env`
- Check app registration is active
- Confirm client secret hasn't expired

**"Supabase error"**
- Run schema.sql to create tables
- Verify Supabase URL and key
- Check table names match exactly

**"Duplicate key violation"**
- This is normal on re-runs (upsert working correctly)
- Means same invoice numbers being processed

**"No data synced"**
- Check Excel sheet names: "Detailed Invoices"
- Verify column order matches expected format
- Check logs for parsing errors

## Integration with Dashboard

The aging data can be visualized in the React retail dashboard:

```javascript
// Add to petra-retail-dashboard
const [agingData, setAgingData] = useState([]);

useEffect(() => {
  async function fetchAging() {
    const { data } = await supabase
      .from('retail_aging_invoices')
      .select('*')
      .order('outstanding', { ascending: false });
    setAgingData(data);
  }
  fetchAging();
}, []);
```

See dashboard integration example in the main retail dashboard repo.

## File Structure

```
automation/aging/
├── sync_aging.py          # Main sync script
├── schema.sql             # Supabase table definitions
├── requirements.txt       # Python dependencies
└── README.md              # This file
```

## Logs

```
logs/
└── aging_sync.log         # Sync operation logs
```

## Support

For issues:
1. Check logs: `tail -f ../logs/aging_sync.log`
2. Verify config: `cat ../.env`
3. Test manually: `python sync_aging.py`
4. Check Supabase table: Query `retail_aging_invoices`
