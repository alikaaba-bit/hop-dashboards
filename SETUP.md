# HOP Tracker Sync - Quick Start Guide

## Prerequisites
- ✅ Node.js installed
- ✅ Access to HOP SharePoint site
- ✅ Supabase account and project

## Quick Setup (5 minutes)

### Step 1: Find Your SharePoint Site ID
```javascript
// In SharePoint site, open browser console (F12) and run:
_spPageContextInfo.siteId
// Copy the GUID that appears
```

### Step 2: Update Configuration
```bash
# Edit the .env file
nano automation/.env

# Update this line with your Site ID:
SHAREPOINT_SITE_ID=paste-your-site-id-here
```

### Step 3: Create Supabase Table
```bash
# 1. Copy the schema
cat automation/supabase-schema.sql

# 2. Go to Supabase Dashboard → SQL Editor
# 3. Create new query, paste the schema, and run it
```

### Step 4: Test the Sync
```bash
# Run a test sync
node automation/sync-hop-tracker.js
```

If successful, you'll see:
```
[INFO] Starting HOP Tracker Sync
[INFO] Found file: HOP Retail Sales & PO Tracker.xlsx
[INFO] Parsing Excel file...
[INFO] Sync Complete
```

### Step 5: Install Scheduler (Optional)
```bash
# Set up daily automatic sync at 6 AM
./automation/setup-scheduler.sh
```

## That's It!

Your HOP tracker will now sync automatically every day at 6 AM.

### Monitoring
```bash
# View logs
tail -f logs/sync.log

# Check last sync status
cat logs/tracking.json

# Run manual sync anytime
node automation/sync-hop-tracker.js
```

## Common Issues

**"File not found"**
- Double-check your `SHAREPOINT_SITE_ID` is correct
- Verify the file name in `.env` matches exactly

**"Table not found"**
- Make sure you ran the SQL schema in Supabase

**"No changes detected"**
- This is normal! It means the file hasn't changed since last sync
- To force a sync: `rm logs/tracking.json` then run again

## Need Help?

See the full documentation: [automation/README.md](automation/README.md)
