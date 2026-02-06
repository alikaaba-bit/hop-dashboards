# HOP Tracker Sync - Quick Reference Card

## 🚀 First Time Setup (5 minutes)

```bash
# 1. Get SharePoint Site ID
# Open SharePoint → Press F12 → Console → Run:
_spPageContextInfo.siteId

# 2. Update configuration
nano automation/.env
# Change: SHAREPOINT_SITE_ID=paste-your-site-id-here

# 3. Create Supabase table
cat automation/supabase-schema.sql
# → Copy → Supabase SQL Editor → Paste → Run

# 4. Test sync
node automation/sync-hop-tracker.js

# 5. Install scheduler (optional)
./automation/setup-scheduler.sh
```

## 📋 Daily Commands

```bash
# Run sync now
node automation/sync-hop-tracker.js

# View logs (real-time)
tail -f logs/sync.log

# Check last sync status
cat logs/tracking.json

# View all logs
ls -lh logs/
```

## 🔧 Scheduler Management

```bash
# Test scheduler now
launchctl start com.hop.tracker.sync

# Check if running
launchctl list | grep com.hop.tracker.sync

# Disable daily sync
launchctl unload ~/Library/LaunchAgents/com.hop.tracker.sync.plist

# Enable daily sync
launchctl load ~/Library/LaunchAgents/com.hop.tracker.sync.plist

# View scheduler logs
tail -f logs/sync_stdout.log
tail -f logs/sync_stderr.log
```

## 🗄️ Supabase Queries

```javascript
// Get all records for a SKU
const { data } = await supabase
  .from('hop_tracker')
  .select('*')
  .eq('sku', 'SKU-12345');

// Sales by retailer
const { data } = await supabase
  .from('vw_hop_sales_by_retailer')
  .select('*')
  .order('total_sales', { ascending: false });

// PO status
const { data } = await supabase
  .from('vw_hop_po_status')
  .select('*')
  .eq('po_number', 'PO-12345');
```

```sql
-- Total sales by product (SQL)
SELECT product_name, SUM(units_sold), SUM(sales_amount)
FROM hop_tracker
GROUP BY product_name
ORDER BY SUM(sales_amount) DESC;

-- Monthly trend
SELECT DATE_TRUNC('month', transaction_date) as month,
       SUM(sales_amount) as sales
FROM hop_tracker
GROUP BY month
ORDER BY month DESC;
```

## 🐛 Troubleshooting

| Problem | Solution |
|---------|----------|
| "File not found" | Check SHAREPOINT_SITE_ID in `.env` |
| "Table not found" | Run SQL schema in Supabase |
| "Auth failed" | Verify Azure credentials in `.env` |
| "No changes" | Normal! File unchanged since last sync |
| Wrong columns | Edit `transformData()` in sync script |

```bash
# Force a full sync (bypass change detection)
rm logs/tracking.json
node automation/sync-hop-tracker.js
```

## 📁 File Locations

```
/Users/ali/clawd/hop-dashboards/
├── automation/
│   ├── sync-hop-tracker.js    ← Main script
│   ├── .env                   ← Your configuration
│   └── README.md              ← Full documentation
├── logs/
│   ├── sync.log               ← Sync logs
│   └── tracking.json          ← Change tracking
└── SETUP.md                   ← Quick start guide
```

## ⚙️ Configuration

```bash
# Edit configuration
nano automation/.env

# Key settings:
SHAREPOINT_SITE_ID=your-site-id     # Required!
TRACKER_FILE_NAME=HOP Retail...     # Exact filename
SUPABASE_URL=https://...            # Already set
SUPABASE_KEY=...                    # Already set
```

## 📊 Excel Column Mapping

Default mapping (customize in `transformData()` if needed):

| Excel | Database |
|-------|----------|
| Date / Transaction Date | transaction_date |
| SKU / Product SKU | sku |
| Product Name | product_name |
| Retailer / Customer | retailer |
| Units Sold / Quantity | units_sold |
| Sales Amount / Revenue | sales_amount |
| PO Number / PO# | po_number |
| PO Status / Status | po_status |

## 🔍 Logs Explained

```bash
# Main sync log
logs/sync.log
  [INFO] Normal operations
  [WARN] Warnings (non-fatal)
  [ERROR] Errors (needs attention)

# Tracking status
logs/tracking.json
  {
    "lastModified": "...",    # File timestamp
    "eTag": "...",            # File version
    "lastSynced": "...",      # Last sync time
    "recordsProcessed": 250   # Records synced
  }

# Scheduler output
logs/sync_stdout.log  # Standard output
logs/sync_stderr.log  # Errors
```

## 📞 Getting Help

1. **Read full docs**: `cat automation/README.md`
2. **Check logs**: `tail -f logs/sync.log`
3. **Test manually**: `node automation/sync-hop-tracker.js`
4. **Verify config**: `cat automation/.env`

## 🎯 Quick Tests

```bash
# Test Azure auth
node -e "const {ClientSecretCredential} = require('@azure/identity'); \
  const c = new ClientSecretCredential('tenant','client','secret'); \
  c.getToken('https://graph.microsoft.com/.default').then(t => \
  console.log('✅ Azure auth works'))"

# Test Supabase connection
node -e "const {createClient} = require('@supabase/supabase-js'); \
  const s = createClient(process.env.SUPABASE_URL, process.env.SUPABASE_KEY); \
  s.from('hop_tracker').select('count').limit(1).then(r => \
  console.log('✅ Supabase works'))"

# Test full sync
node automation/sync-hop-tracker.js
```

## 📅 Schedule Information

Default schedule: **Daily at 6:00 AM**

To change time, edit:
```bash
nano ~/Library/LaunchAgents/com.hop.tracker.sync.plist

# Change these values:
<key>Hour</key>
<integer>6</integer>    ← 0-23 (24h format)
<key>Minute</key>
<integer>0</integer>    ← 0-59

# Then reload:
launchctl unload ~/Library/LaunchAgents/com.hop.tracker.sync.plist
launchctl load ~/Library/LaunchAgents/com.hop.tracker.sync.plist
```

---

**💡 Pro Tips:**
- First sync takes longer (downloads file)
- Subsequent syncs are fast if file unchanged
- Check logs weekly to ensure it's running
- Test manually before relying on automation
- Keep `tracking.json` for change detection
