-- AR Aging Report Tables for Petra Brands
-- Run this in Supabase SQL Editor

-- Detailed invoice-level aging data
CREATE TABLE IF NOT EXISTS retail_aging_invoices (
  id BIGSERIAL PRIMARY KEY,
  brand TEXT NOT NULL,
  retailer TEXT NOT NULL,
  po_number TEXT,
  invoice_number TEXT,
  invoice_date DATE,
  due_date DATE,
  invoice_amount DECIMAL(12,2),
  received DECIMAL(12,2) DEFAULT 0,
  outstanding DECIMAL(12,2),
  days_overdue INTEGER DEFAULT 0,
  aging_bucket TEXT,
  status TEXT,
  delay_remarks TEXT,
  synced_at TIMESTAMPTZ DEFAULT NOW(),
  report_date DATE,
  UNIQUE(brand, invoice_number)
);

-- Brand-level aging summary
CREATE TABLE IF NOT EXISTS retail_aging_summary (
  id BIGSERIAL PRIMARY KEY,
  brand TEXT NOT NULL,
  retailer TEXT,
  total_outstanding DECIMAL(12,2),
  not_yet_due DECIMAL(12,2),
  days_1_30 DECIMAL(12,2),
  days_31_60 DECIMAL(12,2),
  days_61_90 DECIMAL(12,2),
  days_90_plus DECIMAL(12,2),
  invoice_count INTEGER,
  overdue_count INTEGER,
  synced_at TIMESTAMPTZ DEFAULT NOW(),
  report_date DATE,
  UNIQUE(brand, retailer, report_date)
);

-- Historical snapshots for trend tracking
CREATE TABLE IF NOT EXISTS retail_aging_snapshots (
  id BIGSERIAL PRIMARY KEY,
  snapshot_date DATE NOT NULL,
  brand TEXT NOT NULL,
  total_outstanding DECIMAL(12,2),
  not_yet_due DECIMAL(12,2),
  overdue_total DECIMAL(12,2),
  invoice_count INTEGER,
  overdue_count INTEGER,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(snapshot_date, brand)
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_aging_brand ON retail_aging_invoices(brand);
CREATE INDEX IF NOT EXISTS idx_aging_retailer ON retail_aging_invoices(retailer);
CREATE INDEX IF NOT EXISTS idx_aging_bucket ON retail_aging_invoices(aging_bucket);
CREATE INDEX IF NOT EXISTS idx_aging_status ON retail_aging_invoices(status);
CREATE INDEX IF NOT EXISTS idx_aging_due_date ON retail_aging_invoices(due_date);
CREATE INDEX IF NOT EXISTS idx_aging_report_date ON retail_aging_invoices(report_date);
CREATE INDEX IF NOT EXISTS idx_snapshots_date ON retail_aging_snapshots(snapshot_date);
CREATE INDEX IF NOT EXISTS idx_summary_brand ON retail_aging_summary(brand);

-- Views for easy querying
CREATE OR REPLACE VIEW vw_aging_overview AS
SELECT
  brand,
  COUNT(*) as total_invoices,
  SUM(invoice_amount) as total_invoiced,
  SUM(outstanding) as total_outstanding,
  SUM(CASE WHEN aging_bucket = 'Not Yet Due' THEN outstanding ELSE 0 END) as not_yet_due,
  SUM(CASE WHEN aging_bucket = '1-30 Days' THEN outstanding ELSE 0 END) as days_1_30,
  SUM(CASE WHEN aging_bucket = '31-60 Days' THEN outstanding ELSE 0 END) as days_31_60,
  SUM(CASE WHEN aging_bucket = '61-90 Days' THEN outstanding ELSE 0 END) as days_61_90,
  SUM(CASE WHEN aging_bucket = '90+ Days' THEN outstanding ELSE 0 END) as days_90_plus,
  COUNT(*) FILTER (WHERE status = 'Due') as overdue_count,
  MAX(report_date) as last_updated
FROM retail_aging_invoices
GROUP BY brand;

CREATE OR REPLACE VIEW vw_aging_by_retailer AS
SELECT
  retailer,
  brand,
  COUNT(*) as invoice_count,
  SUM(outstanding) as total_outstanding,
  AVG(days_overdue) as avg_days_overdue,
  MAX(days_overdue) as max_days_overdue
FROM retail_aging_invoices
WHERE outstanding > 0
GROUP BY retailer, brand
ORDER BY total_outstanding DESC;

COMMENT ON TABLE retail_aging_invoices IS 'Detailed AR aging data synced from SharePoint';
COMMENT ON TABLE retail_aging_summary IS 'Brand/retailer-level aging summaries';
COMMENT ON TABLE retail_aging_snapshots IS 'Daily snapshots for trend analysis';
