# HOP SharePoint to Supabase Sync Automation

Automatically syncs "HOP Retail Sales & PO Tracker" Excel file from SharePoint to Supabase daily, only when there are changes.

## Features

- **Smart change detection** - Only syncs when file has changed (tracks eTag/lastModified)
- **Batch upsert** - Efficiently handles large datasets (500 records per batch)
- **Automatic scheduling** - Runs daily at 6 AM via macOS LaunchAgent
- **Comprehensive logging** - Tracks all sync operations and errors
- **Duplicate handling** - Upserts based on SKU + transaction date

## Setup

### 1. Install Dependencies

Dependencies are already installed in the project root:
```bash
cd /Users/ali/clawd/hop-dashboards
npm install
```

### 2. Configure Environment Variables

Edit `automation/.env` and update:

```bash
# SharePoint Site ID - REQUIRED
SHAREPOINT_SITE_ID=your_site_id_here

# File name - Update if different
TRACKER_FILE_NAME=HOP Retail Sales & PO Tracker.xlsx
```

**How to find SharePoint Site ID:**
1. Go to your SharePoint site
2. Open browser dev tools (F12)
3. Run in console: `_spPageContextInfo.siteId`
4. Copy the GUID value

### 3. Create Supabase Table

Run the SQL schema in Supabase:
```bash
# Copy the SQL file contents
cat automation/supabase-schema.sql

# Then paste in Supabase SQL Editor
# (Dashboard → SQL Editor → New Query → Paste → Run)
```

This creates:
- `hop_tracker` table with proper indexes
- Views for sales analysis
- Triggers for automatic timestamps
- Row-level security policies

### 4. Test the Sync

Run a manual sync to verify everything works:
```bash
node automation/sync-hop-tracker.js
```

Expected output:
```
[INFO] Starting HOP Tracker Sync
[INFO] Searching for file: HOP Retail Sales & PO Tracker.xlsx
[INFO] Found file: HOP Retail Sales & PO Tracker.xlsx (ID: xxx)
[INFO] Downloading file (123.45 KB)...
[INFO] Parsing Excel file...
[INFO] Parsed 250 rows from Excel
[INFO] Transforming data...
[INFO] Connecting to Supabase...
[INFO] Upserting 250 records to Supabase...
[INFO] Batch 1: 250/250 records
[INFO] Sync Complete
```

### 5. Setup Automated Scheduler

Install the LaunchAgent to run daily at 6 AM:
```bash
chmod +x automation/setup-scheduler.sh
./automation/setup-scheduler.sh
```

This will:
- Create a LaunchAgent configuration
- Schedule daily sync at 6:00 AM
- Set up logging to `logs/` directory

## Excel Column Mapping

The script expects these Excel columns (customize in `transformData()` function):

| Excel Column | Database Column | Type | Required |
|--------------|----------------|------|----------|
| Date / Transaction Date | transaction_date | DATE | No |
| SKU / Product SKU | sku | TEXT | Yes* |
| Product Name / Product | product_name | TEXT | No |
| Retailer / Customer | retailer | TEXT | No |
| Units Sold / Quantity | units_sold | INTEGER | No |
| Sales Amount / Revenue | sales_amount | NUMERIC | No |
| PO Number / PO# | po_number | TEXT | No |
| PO Status / Status | po_status | TEXT | No |

*Required for upsert logic (SKU + date uniqueness)

**To customize column mapping:**
Edit the `transformData()` function in `sync-hop-tracker.js`:
```javascript
function transformData(rows) {
  return rows.map(row => ({
    transaction_date: row['Your Column Name'],
    sku: row['Your SKU Column'],
    // ... customize other mappings
  }));
}
```

## Monitoring

### View Sync Logs
```bash
# Real-time logs
tail -f logs/sync.log

# All logs
cat logs/sync.log

# LaunchAgent output
tail -f logs/sync_stdout.log
tail -f logs/sync_stderr.log
```

### Check Tracking Status
```bash
cat logs/tracking.json
```

Shows:
- Last modified timestamp
- eTag (file version identifier)
- Last sync timestamp
- Records processed/inserted

### Manual Sync Commands
```bash
# Run sync now
node automation/sync-hop-tracker.js

# Test LaunchAgent
launchctl start com.hop.tracker.sync

# Check LaunchAgent status
launchctl list | grep com.hop.tracker.sync
```

## Scheduler Management

### Disable Daily Sync
```bash
launchctl unload ~/Library/LaunchAgents/com.hop.tracker.sync.plist
```

### Enable Daily Sync
```bash
launchctl load ~/Library/LaunchAgents/com.hop.tracker.sync.plist
```

### Change Schedule Time
Edit the plist file:
```bash
nano ~/Library/LaunchAgents/com.hop.tracker.sync.plist
```

Change these values:
```xml
<key>Hour</key>
<integer>6</integer>    <!-- Hour in 24h format (0-23) -->
<key>Minute</key>
<integer>0</integer>    <!-- Minute (0-59) -->
```

Then reload:
```bash
launchctl unload ~/Library/LaunchAgents/com.hop.tracker.sync.plist
launchctl load ~/Library/LaunchAgents/com.hop.tracker.sync.plist
```

## Querying the Data

### Supabase JavaScript Client
```javascript
const { createClient } = require('@supabase/supabase-js');
const supabase = createClient(SUPABASE_URL, SUPABASE_KEY);

// Get all records for a SKU
const { data } = await supabase
  .from('hop_tracker')
  .select('*')
  .eq('sku', 'SKU-12345')
  .order('transaction_date', { ascending: false });

// Get sales by retailer
const { data } = await supabase
  .from('vw_hop_sales_by_retailer')
  .select('*')
  .order('total_sales', { ascending: false });

// Get PO status
const { data } = await supabase
  .from('vw_hop_po_status')
  .select('*')
  .eq('po_number', 'PO-12345');
```

### SQL Queries
```sql
-- Total sales by product
SELECT
  product_name,
  SUM(units_sold) as total_units,
  SUM(sales_amount) as total_sales
FROM hop_tracker
GROUP BY product_name
ORDER BY total_sales DESC;

-- Monthly sales trend
SELECT
  DATE_TRUNC('month', transaction_date) as month,
  SUM(sales_amount) as monthly_sales
FROM hop_tracker
GROUP BY month
ORDER BY month DESC;

-- Top retailers by revenue
SELECT * FROM vw_hop_sales_by_retailer
ORDER BY total_sales DESC
LIMIT 10;
```

## Troubleshooting

### "File not found" Error
- Verify `SHAREPOINT_SITE_ID` is correct
- Check `TRACKER_FILE_NAME` matches exactly (case-sensitive)
- Ensure Azure credentials have access to the SharePoint site

### "Table not found" Error
- Run the SQL schema in Supabase (see Setup step 3)
- Verify table name is `hop_tracker` (lowercase)

### "Authentication failed" Error
- Verify Azure credentials in `.env`
- Check that the service principal has permissions to the SharePoint site

### "No changes detected" Message
- This is normal - means file hasn't changed since last sync
- Check `logs/tracking.json` to see last sync details
- Delete `logs/tracking.json` to force a full sync

### Sync Running But No Data
- Check `logs/sync.log` for detailed error messages
- Verify Excel column names match the mapping
- Test parse locally: `node -e "console.log(require('xlsx').readFile('path/to/file.xlsx'))"`

## File Structure

```
hop-dashboards/
├── automation/
│   ├── sync-hop-tracker.js      # Main sync script
│   ├── setup-scheduler.sh       # LaunchAgent installer
│   ├── supabase-schema.sql      # Database schema
│   ├── .env                     # Configuration (private)
│   ├── .env.template            # Configuration template
│   └── README.md                # This file
├── logs/
│   ├── sync.log                 # Sync operation logs
│   ├── tracking.json            # File change tracking
│   ├── sync_stdout.log          # LaunchAgent output
│   └── sync_stderr.log          # LaunchAgent errors
└── package.json                 # Dependencies
```

## Integration with Existing Systems

### Petra Mind Integration
The HOP tracker data can be queried alongside other Petra Mind data:
```javascript
// Example: Get HOP sales data for a product
const hopSales = await supabase
  .from('hop_tracker')
  .select('*')
  .eq('sku', productSku);

// Combine with other Petra Mind metrics
// ...
```

### Dashboard Integration
Use the data in your HOP dashboards:
- Query Supabase directly from JavaScript
- Use the pre-built views for aggregated data
- Real-time updates via Supabase subscriptions

## Support

For issues:
1. Check logs: `tail -f logs/sync.log`
2. Verify configuration: `cat automation/.env`
3. Test manually: `node automation/sync-hop-tracker.js`
4. Review tracking: `cat logs/tracking.json`
