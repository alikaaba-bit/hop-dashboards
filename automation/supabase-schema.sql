-- HOP Retail Sales & PO Tracker Table Schema
-- Run this in your Supabase SQL Editor to create the table

-- Create table for HOP tracker data
CREATE TABLE IF NOT EXISTS hop_tracker (
  id BIGSERIAL PRIMARY KEY,

  -- Transaction information
  transaction_date DATE,
  sku TEXT,
  product_name TEXT,
  retailer TEXT,

  -- Sales data
  units_sold INTEGER DEFAULT 0,
  sales_amount NUMERIC(10, 2) DEFAULT 0,

  -- Purchase order information
  po_number TEXT,
  po_status TEXT,

  -- Metadata
  synced_at TIMESTAMPTZ DEFAULT NOW(),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),

  -- Unique constraint on SKU + transaction date
  CONSTRAINT hop_tracker_unique_sku_date UNIQUE (sku, transaction_date)
);

-- Create indexes for common queries
CREATE INDEX IF NOT EXISTS idx_hop_tracker_sku ON hop_tracker(sku);
CREATE INDEX IF NOT EXISTS idx_hop_tracker_date ON hop_tracker(transaction_date);
CREATE INDEX IF NOT EXISTS idx_hop_tracker_retailer ON hop_tracker(retailer);
CREATE INDEX IF NOT EXISTS idx_hop_tracker_po_number ON hop_tracker(po_number);
CREATE INDEX IF NOT EXISTS idx_hop_tracker_synced_at ON hop_tracker(synced_at);

-- Create updated_at trigger
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_hop_tracker_updated_at
    BEFORE UPDATE ON hop_tracker
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Create view for sales summary by SKU
CREATE OR REPLACE VIEW vw_hop_sales_by_sku AS
SELECT
  sku,
  product_name,
  COUNT(*) as transaction_count,
  SUM(units_sold) as total_units,
  SUM(sales_amount) as total_sales,
  AVG(sales_amount) as avg_sale_amount,
  MIN(transaction_date) as first_sale,
  MAX(transaction_date) as last_sale
FROM hop_tracker
GROUP BY sku, product_name;

-- Create view for sales by retailer
CREATE OR REPLACE VIEW vw_hop_sales_by_retailer AS
SELECT
  retailer,
  COUNT(DISTINCT sku) as unique_skus,
  SUM(units_sold) as total_units,
  SUM(sales_amount) as total_sales,
  COUNT(*) as transaction_count
FROM hop_tracker
GROUP BY retailer;

-- Create view for PO status tracking
CREATE OR REPLACE VIEW vw_hop_po_status AS
SELECT
  po_number,
  po_status,
  COUNT(DISTINCT sku) as sku_count,
  SUM(units_sold) as total_units,
  SUM(sales_amount) as total_amount,
  MIN(transaction_date) as earliest_transaction,
  MAX(transaction_date) as latest_transaction
FROM hop_tracker
WHERE po_number IS NOT NULL
GROUP BY po_number, po_status;

-- Grant permissions (adjust as needed)
-- For service role (full access)
GRANT ALL ON hop_tracker TO service_role;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO service_role;

-- For authenticated users (read-only by default)
GRANT SELECT ON hop_tracker TO authenticated;
GRANT SELECT ON vw_hop_sales_by_sku TO authenticated;
GRANT SELECT ON vw_hop_sales_by_retailer TO authenticated;
GRANT SELECT ON vw_hop_po_status TO authenticated;

-- Enable Row Level Security (optional, customize as needed)
ALTER TABLE hop_tracker ENABLE ROW LEVEL SECURITY;

-- Create policy for service role (full access)
CREATE POLICY "Service role has full access"
  ON hop_tracker
  FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);

-- Create policy for authenticated users (read-only)
CREATE POLICY "Authenticated users can read"
  ON hop_tracker
  FOR SELECT
  TO authenticated
  USING (true);

COMMENT ON TABLE hop_tracker IS 'HOP Retail Sales & PO Tracker data synced from SharePoint';
COMMENT ON COLUMN hop_tracker.transaction_date IS 'Date of the transaction';
COMMENT ON COLUMN hop_tracker.sku IS 'Product SKU identifier';
COMMENT ON COLUMN hop_tracker.product_name IS 'Product name or description';
COMMENT ON COLUMN hop_tracker.retailer IS 'Retailer or customer name';
COMMENT ON COLUMN hop_tracker.units_sold IS 'Number of units sold in this transaction';
COMMENT ON COLUMN hop_tracker.sales_amount IS 'Total sales amount in USD';
COMMENT ON COLUMN hop_tracker.po_number IS 'Purchase order number';
COMMENT ON COLUMN hop_tracker.po_status IS 'Current status of the purchase order';
COMMENT ON COLUMN hop_tracker.synced_at IS 'When this record was last synced from SharePoint';
