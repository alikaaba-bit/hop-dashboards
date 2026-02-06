# HOP Dashboards - Project Context

## Project Overview

HOP Dashboards is a collection of analytics dashboards and automation tools for House of Party (HOP) retail sales tracking and product strategy. The project includes interactive HTML dashboards and a SharePoint-to-Supabase data sync automation.

## Dashboards

**IMPORTANT**: All dashboard files should be documented in this section of CLAUDE.md. Do not place dashboard files in arbitrary locations.

### Current Dashboards

1. **HOP Product Strategy Dashboard** (`hop-product-strategy-dashboard.html`)
   - Product portfolio analysis
   - Category performance metrics
   - Strategic planning visualizations

2. **HOP Trend Dashboard** (`hop-trend-dashboard.html`)
   - Sales trends over time
   - Product performance tracking
   - Market analysis

3. **HOP 2026 Product Roadmap Dashboard** (`hop-2026-product-roadmap-dashboard.html`)
   - Product launch timeline
   - Development pipeline
   - Strategic roadmap visualization

4. **Main Index** (`index.html`)
   - Landing page for all dashboards
   - Navigation between dashboards

5. **Retail Command Center Dashboard** (React App)
   - **Repo:** `alikaaba-bit/petra-retail-dashboard`
   - **Live URL:** https://alikaaba-bit.github.io/petra-retail-dashboard/
   - **Stack:** React 18 + Vite + Recharts
   - **Data source:** HOP_Retail_Sales___PO_Tracker_-_2025-2026.xlsx (parsed into embedded JSON)
   - **Last updated:** Feb 6, 2026

   **Brand Hierarchy:**
   - **House of Party** (parent brand)
     - Party Hero (HOP-PH prefix) — balloon & decor kits
     - Table Hero (HOP-TH prefix) — tableware & party supplies
     - Balloon Creations (HOP-BC prefix) — balloon garland sets
   - **PixlePop** (HOP-PXL prefix) — puzzles, stickers, coasters, 3D displays
   - **Muddies** (HOP-MUD prefix) — art & craft kits (magnets, frames, texture canvas)
   - **Threadies** — coming soon (not yet in data)

   **Dashboard Tabs:**
   1. Overview — KPIs, brand cards with sub-line drill-down, retailer bars + donut, monthly revenue/GP trend, YOY comparison, annual summary, payment terms
   2. Retailers — Full retailer breakdown with inline brand tags, stacked monthly chart, retailer×brand matrix table, brand-split horizontal bars
   3. SKU Intel — Sortable SKU table (revenue/units/margin), signal flags (🔥/✅/⚠️), Top 10 chart, pagination
   4. Forecast — Inventory velocity for high-volume SKUs, trend detection (📈/📉/→), reorder planning calculator with 8-week China lead time

   **Data Stats:**
   - 1,330 order line items from "All POs" + "Endcap C3" sheets
   - 88 SKUs with COG data mapped from Product List
   - 11 retailers (Target 84.8% dominant)
   - 42 unique POs
   - Revenue: $2.06M (2025), $46.7K (2026 Jan-Feb)

   **Filters:**
   - Brand: House of Party / PixlePop / Muddies (clickable cards)
   - HOP Sub-line: Party Hero / Table Hero / Balloon Creations (nested inside HOP card)
   - Retailer: dropdown
   - Year: All / 2025 / 2026
   - Status: All / Confirmed / Cancelled

   **To Update Data:**
   1. Export new PO tracker Excel
   2. Run the Python data parser (or update the embedded JSON in App.jsx)
   3. Push to main — auto-deploys via GitHub Actions

   **Known Limitations:**
   - Endcap C3 Target POs (~1,100 items) lack COG data — margin shows "—"
   - Threadies not yet in tracker
   - No Amazon/DTC data — retail only

### Dashboard Guidelines

- All dashboard HTML files should be in the project root
- Dashboards should be self-contained (embedded CSS/JS when possible)
- Use consistent styling and branding across dashboards
- Document new dashboards in this CLAUDE.md file
- Update the index.html when adding new dashboards

## Automation

### SharePoint to Supabase Sync

Automated daily sync of "HOP Retail Sales & PO Tracker" Excel file from SharePoint to Supabase.

**Key Files:**
- `automation/sync-hop-tracker.js` - Main sync script
- `automation/supabase-schema.sql` - Database schema
- `automation/setup-scheduler.sh` - Daily scheduler setup
- `automation/.env` - Configuration (private)

**Features:**
- Smart change detection (only syncs when file changes)
- Batch upsert to Supabase (500 records per batch)
- Comprehensive logging and tracking
- Scheduled daily at 6:00 AM via LaunchAgent

**Quick Start:**
```bash
# Test sync
node automation/sync-hop-tracker.js

# View logs
tail -f logs/sync.log

# Install scheduler
./automation/setup-scheduler.sh
```

See `automation/README.md` for full documentation.

### AR Aging Report Sync

Automated daily sync of Petra Brands AR Aging Report from SharePoint to Supabase.

**Key Files:**
- `automation/aging/sync_aging.py` - Python sync script
- `automation/aging/schema.sql` - Database schema (3 tables + views)
- `automation/aging/requirements.txt` - Python dependencies
- `automation/aging/find_sharepoint_files.py` - Helper to locate files
- `.github/workflows/sync-aging.yml` - GitHub Actions workflow

**Data Source:**
- **File:** `Aging_Dashboard.xlsx` (in Maira's OneDrive: maira@petrabrands.com)
- **Sheet:** "Detailed Invoices" with invoice-level detail
- **Location:** swiftstartagency-my.sharepoint.com personal drive
- **Last Synced:** Feb 6, 2026 - 362 unique invoices

**Features:**
- Downloads AR Aging Excel from Maira's OneDrive via Microsoft Graph API
- Parses detailed invoice data (brand, retailer, PO#, invoice#, invoice date, due date, amounts, aging buckets, status)
- Normalizes brand names (FOMIN → Fomin, HOP → House of Party)
- Deduplicates invoices by (brand, invoice_number) before upserting
- Upserts to 3 tables: invoices, summary, snapshots
- Creates daily snapshots for trend tracking
- Scheduled daily at 7 AM UTC via GitHub Actions

**Tables:**
- `retail_aging_invoices` - Invoice-level detail (362 unique invoices)
- `retail_aging_summary` - Brand/retailer summaries (not yet populated)
- `retail_aging_snapshots` - Daily snapshots for trends (4 brands tracked)
- `vw_aging_overview` - View for brand-level overview
- `vw_aging_by_retailer` - View for retailer breakdown

**Current Data (Last Sync: Feb 6, 2026):**
- 362 unique invoices across 4 brands
- Brands: Fomin, House of Party, Roofus, EveryMood
- Retailers: KeHe, TJX, Target, CVS, Bealls, and more
- Automatic deduplication removes ~109 duplicate entries

**Quick Start:**
```bash
# Install dependencies
pip install -r automation/aging/requirements.txt

# Create Supabase tables (one-time setup)
cat automation/aging/schema.sql
# → Copy to Supabase SQL Editor and run

# Test sync locally
cd automation/aging
python3 sync_aging.py

# View logs
tail -f ../../logs/aging_sync.log

# Trigger GitHub Actions manually
gh workflow run sync-aging.yml
```

**Status:** ✅ Fully operational - syncing daily at 7 AM UTC

See `automation/aging/README.md` for full documentation.

## Project Structure

```
hop-dashboards/
├── CLAUDE.md                               # This file - project context
├── SETUP.md                                # Quick start guide
├── *.html                                  # Dashboard files
├── .github/workflows/
│   └── sync-aging.yml                      # AR Aging daily sync workflow
├── automation/
│   ├── sync-hop-tracker.js                 # PO Tracker sync (Node.js)
│   ├── supabase-schema.sql                 # PO Tracker schema
│   ├── setup-scheduler.sh                  # Scheduler installer
│   ├── .env                                # Configuration (private)
│   ├── README.md                           # Full automation docs
│   └── aging/
│       ├── sync_aging.py                   # AR Aging sync (Python)
│       ├── schema.sql                      # AR Aging schema
│       ├── requirements.txt                # Python dependencies
│       └── README.md                       # Aging sync docs
├── logs/
│   ├── sync.log                            # PO Tracker logs
│   ├── aging_sync.log                      # AR Aging logs
│   └── tracking.json                       # File change tracking
└── package.json                            # Node.js dependencies
```

## Technology Stack

### Dashboards
- Static HTML with embedded JavaScript
- D3.js / Chart.js for visualizations
- Responsive design for desktop/mobile

### Automation
- **Node.js** - PO Tracker sync runtime
- **Python 3.11** - AR Aging sync runtime
- **@azure/identity** - Azure AD authentication
- **@microsoft/microsoft-graph-client** - SharePoint API
- **@supabase/supabase-js** - Database operations
- **openpyxl** - Python Excel parsing
- **xlsx** - Node.js Excel parsing
- **macOS LaunchAgent** - Local scheduling
- **GitHub Actions** - Cloud scheduling

## Environment Configuration

Required environment variables in `automation/.env`:

```bash
# Azure SharePoint
AZURE_TENANT_ID=<from_petra_mind_env>
AZURE_CLIENT_ID=<from_petra_mind_env>
AZURE_CLIENT_SECRET=<from_petra_mind_env>

# SharePoint Configuration
SHAREPOINT_SITE_ID=your_site_id_here
TRACKER_FILE_NAME=HOP Retail Sales & PO Tracker.xlsx

# Supabase
SUPABASE_URL=https://jrlfcntftckbeqnabtqk.supabase.co
SUPABASE_KEY=sb_publishable_tLLBpa5_NFhtoyPfWOCyHQ_5K-jEDME
```

## Data Flow

```
SharePoint Excel File
    ↓ (Microsoft Graph API)
sync-hop-tracker.js
    ↓ (Parse & Transform)
Supabase hop_tracker table
    ↓ (Query)
Dashboards & Analytics
```

## Common Tasks

### Adding a New Dashboard

1. Create HTML file in project root (e.g., `hop-new-dashboard.html`)
2. Document it in this CLAUDE.md under "Dashboards" section
3. Add link to `index.html`
4. Commit to git with descriptive message

### Updating Sync Configuration

1. Edit `automation/.env` for settings
2. Modify `transformData()` in `sync-hop-tracker.js` for column mapping
3. Test with: `node automation/sync-hop-tracker.js`
4. Check logs: `tail -f logs/sync.log`

### Monitoring Automation

```bash
# View real-time logs
tail -f logs/sync.log

# Check last sync status
cat logs/tracking.json

# Test sync manually
node automation/sync-hop-tracker.js

# Check scheduler status
launchctl list | grep com.hop.tracker.sync
```

## Supabase Database

### Tables

- **hop_tracker** - Main sales and PO data
  - Primary key: `id`
  - Unique constraint: `(sku, transaction_date)`
  - Indexes: sku, date, retailer, po_number

### Views

- **vw_hop_sales_by_sku** - Aggregated sales by product
- **vw_hop_sales_by_retailer** - Sales summary by retailer
- **vw_hop_po_status** - Purchase order tracking

### Query Examples

```javascript
// Get sales for a SKU
const { data } = await supabase
  .from('hop_tracker')
  .select('*')
  .eq('sku', 'SKU-12345');

// Top retailers by revenue
const { data } = await supabase
  .from('vw_hop_sales_by_retailer')
  .select('*')
  .order('total_sales', { ascending: false });
```

## Development Workflow

### Using GSD (Get Shit Done)

This project uses the GSD workflow system. Available commands:

```bash
/gsd:help              # Show all commands
/gsd:new-project       # Initialize new project structure
/gsd:spec              # Create project specification
/gsd:build             # Build from specification
```

See GSD documentation: `~/.claude/commands/gsd/` or run `/gsd:help`

### Git Workflow

```bash
# Make changes
git add .
git commit -m "Description of changes"
git push origin main

# Create feature branch
git checkout -b feature/dashboard-name
# ... work ...
git push origin feature/dashboard-name
```

## Troubleshooting

### Sync Issues

**"File not found"**
- Verify `SHAREPOINT_SITE_ID` in `.env`
- Check `TRACKER_FILE_NAME` matches exactly

**"Table not found"**
- Run SQL schema: `automation/supabase-schema.sql` in Supabase

**"No changes detected"**
- Normal behavior when file unchanged
- Force sync: `rm logs/tracking.json && node automation/sync-hop-tracker.js`

### Dashboard Issues

**Dashboard not loading**
- Check browser console for errors
- Verify all asset paths are correct
- Test locally: `python -m http.server 8000`

## Resources

- **GSD Documentation**: Run `/gsd:help` in Claude Code
- **Automation Docs**: `automation/README.md`
- **Quick Start**: `SETUP.md`
- **Supabase Dashboard**: https://jrlfcntftckbeqnabtqk.supabase.co

## Notes for AI Assistants

When working on this project:

- **Dashboards MUST be documented in the "Dashboards" section of CLAUDE.md**
- All dashboard HTML files go in project root
- Update index.html when adding dashboards
- Test sync script before committing changes
- Follow existing patterns from petra-mind project
- Use GSD workflow for structured development
- Keep documentation up-to-date in CLAUDE.md
