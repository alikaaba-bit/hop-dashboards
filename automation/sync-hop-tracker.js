#!/usr/bin/env node

/**
 * HOP Retail Sales & PO Tracker Sync Script
 *
 * Syncs Excel file from SharePoint to Supabase daily
 * Only syncs when there are changes (tracks eTag/lastModified)
 *
 * Usage:
 *   node automation/sync-hop-tracker.js
 */

require('dotenv').config({ path: __dirname + '/.env' });
const fs = require('fs');
const path = require('path');
const { ClientSecretCredential } = require('@azure/identity');
const { Client } = require('@microsoft/microsoft-graph-client');
const { TokenCredentialAuthenticationProvider } = require('@microsoft/microsoft-graph-client/authProviders/azureTokenCredentials');
const { createClient } = require('@supabase/supabase-js');
const XLSX = require('xlsx');

// Configuration
const CONFIG = {
  tenantId: process.env.AZURE_TENANT_ID,
  clientId: process.env.AZURE_CLIENT_ID,
  clientSecret: process.env.AZURE_CLIENT_SECRET,
  siteId: process.env.SHAREPOINT_SITE_ID,
  fileName: process.env.TRACKER_FILE_NAME,
  supabaseUrl: process.env.SUPABASE_URL,
  supabaseKey: process.env.SUPABASE_KEY,
  trackingFile: path.join(__dirname, '../logs/tracking.json'),
  tempFile: path.join(__dirname, '../logs/temp-tracker.xlsx'),
  logFile: path.join(__dirname, '../logs/sync.log'),
};

// Logging function
function log(message, level = 'INFO') {
  const timestamp = new Date().toISOString();
  const logMessage = `[${timestamp}] [${level}] ${message}`;
  console.log(logMessage);

  // Append to log file
  fs.appendFileSync(CONFIG.logFile, logMessage + '\n');
}

// Load tracking data
function loadTracking() {
  if (fs.existsSync(CONFIG.trackingFile)) {
    try {
      return JSON.parse(fs.readFileSync(CONFIG.trackingFile, 'utf8'));
    } catch (error) {
      log(`Error loading tracking file: ${error.message}`, 'WARN');
      return {};
    }
  }
  return {};
}

// Save tracking data
function saveTracking(data) {
  fs.writeFileSync(CONFIG.trackingFile, JSON.stringify(data, null, 2));
}

// Initialize Microsoft Graph client
function getGraphClient() {
  const credential = new ClientSecretCredential(
    CONFIG.tenantId,
    CONFIG.clientId,
    CONFIG.clientSecret
  );

  const authProvider = new TokenCredentialAuthenticationProvider(credential, {
    scopes: ['https://graph.microsoft.com/.default']
  });

  return Client.initWithMiddleware({ authProvider });
}

// Find file in SharePoint
async function findFile(client) {
  log(`Searching for file: ${CONFIG.fileName}`);

  try {
    // Get drives for the site
    const drives = await client.api(`/sites/${CONFIG.siteId}/drives`).get();

    for (const drive of drives.value) {
      // Search in each drive
      const searchUrl = `/drives/${drive.id}/root/search(q='${CONFIG.fileName}')`;
      const results = await client.api(searchUrl).get();

      for (const item of results.value) {
        if (item.name === CONFIG.fileName) {
          log(`Found file: ${item.name} (ID: ${item.id})`);
          return {
            driveId: drive.id,
            itemId: item.id,
            name: item.name,
            lastModified: item.lastModifiedDateTime,
            eTag: item.eTag,
            size: item.size
          };
        }
      }
    }

    throw new Error(`File not found: ${CONFIG.fileName}`);
  } catch (error) {
    log(`Error finding file: ${error.message}`, 'ERROR');
    throw error;
  }
}

// Check if file needs update
function needsUpdate(fileInfo, tracking) {
  if (!tracking.lastModified || !tracking.eTag) {
    log('No previous sync found - file will be downloaded', 'INFO');
    return true;
  }

  if (tracking.eTag !== fileInfo.eTag) {
    log(`File changed - eTag mismatch (old: ${tracking.eTag}, new: ${fileInfo.eTag})`, 'INFO');
    return true;
  }

  if (tracking.lastModified !== fileInfo.lastModified) {
    log(`File changed - lastModified mismatch`, 'INFO');
    return true;
  }

  log('File unchanged - skipping sync', 'INFO');
  return false;
}

// Download file from SharePoint
async function downloadFile(client, fileInfo) {
  log(`Downloading file (${(fileInfo.size / 1024).toFixed(2)} KB)...`);

  try {
    const stream = await client.api(`/drives/${fileInfo.driveId}/items/${fileInfo.itemId}/content`).getStream();

    return new Promise((resolve, reject) => {
      const writeStream = fs.createWriteStream(CONFIG.tempFile);
      stream.pipe(writeStream);

      writeStream.on('finish', () => {
        log('Download complete');
        resolve(CONFIG.tempFile);
      });

      writeStream.on('error', reject);
    });
  } catch (error) {
    log(`Error downloading file: ${error.message}`, 'ERROR');
    throw error;
  }
}

// Parse Excel file
function parseExcel(filePath) {
  log('Parsing Excel file...');

  try {
    const workbook = XLSX.readFile(filePath);
    const sheetName = workbook.SheetNames[0];
    const worksheet = workbook.Sheets[sheetName];
    const data = XLSX.utils.sheet_to_json(worksheet);

    log(`Parsed ${data.length} rows from Excel`);
    return data;
  } catch (error) {
    log(`Error parsing Excel: ${error.message}`, 'ERROR');
    throw error;
  }
}

// Transform Excel data to Supabase format
function transformData(rows) {
  log('Transforming data...');

  return rows.map(row => {
    // Map Excel columns to database columns
    // This needs to be customized based on actual Excel structure
    return {
      transaction_date: row['Date'] || row['Transaction Date'] || null,
      sku: row['SKU'] || row['Product SKU'] || null,
      product_name: row['Product Name'] || row['Product'] || null,
      retailer: row['Retailer'] || row['Customer'] || null,
      units_sold: parseInt(row['Units Sold'] || row['Quantity'] || 0),
      sales_amount: parseFloat(row['Sales Amount'] || row['Revenue'] || 0),
      po_number: row['PO Number'] || row['PO#'] || null,
      po_status: row['PO Status'] || row['Status'] || null,
      synced_at: new Date().toISOString()
    };
  }).filter(row => row.sku); // Filter out rows without SKU
}

// Batch upsert to Supabase
async function syncToSupabase(data) {
  log('Connecting to Supabase...');

  const supabase = createClient(CONFIG.supabaseUrl, CONFIG.supabaseKey);

  // Test connection
  const { error: testError } = await supabase.from('hop_tracker').select('count').limit(1);
  if (testError && testError.code === '42P01') {
    log('Table "hop_tracker" does not exist. Please create it first.', 'ERROR');
    log('See schema documentation for table structure', 'ERROR');
    throw new Error('Table not found: hop_tracker');
  }

  log(`Upserting ${data.length} records to Supabase...`);

  const batchSize = 500;
  let inserted = 0;
  let errors = 0;

  for (let i = 0; i < data.length; i += batchSize) {
    const batch = data.slice(i, i + batchSize);

    try {
      const { error } = await supabase
        .from('hop_tracker')
        .upsert(batch, {
          onConflict: 'sku,transaction_date',
          ignoreDuplicates: false
        });

      if (error) throw error;

      inserted += batch.length;
      log(`Batch ${Math.floor(i / batchSize) + 1}: ${inserted}/${data.length} records`, 'INFO');
    } catch (error) {
      errors += batch.length;
      log(`Error in batch ${Math.floor(i / batchSize) + 1}: ${error.message}`, 'ERROR');
    }
  }

  return { inserted, errors };
}

// Main sync function
async function sync() {
  log('='.repeat(60));
  log('Starting HOP Tracker Sync');
  log('='.repeat(60));

  try {
    // Validate configuration
    if (!CONFIG.tenantId || !CONFIG.clientId || !CONFIG.clientSecret) {
      throw new Error('Missing Azure credentials in .env file');
    }
    if (!CONFIG.siteId) {
      throw new Error('Missing SHAREPOINT_SITE_ID in .env file');
    }
    if (!CONFIG.supabaseUrl || !CONFIG.supabaseKey) {
      throw new Error('Missing Supabase credentials in .env file');
    }

    // Initialize Graph client
    const client = getGraphClient();

    // Find file in SharePoint
    const fileInfo = await findFile(client);

    // Load tracking data
    const tracking = loadTracking();

    // Check if update needed
    if (!needsUpdate(fileInfo, tracking)) {
      log('='.repeat(60));
      log('Sync Complete - No changes detected');
      log('='.repeat(60));
      return;
    }

    // Download file
    const filePath = await downloadFile(client, fileInfo);

    // Parse Excel
    const rows = parseExcel(filePath);

    // Transform data
    const data = transformData(rows);

    // Sync to Supabase
    const result = await syncToSupabase(data);

    // Update tracking
    saveTracking({
      lastModified: fileInfo.lastModified,
      eTag: fileInfo.eTag,
      lastSynced: new Date().toISOString(),
      recordsProcessed: data.length,
      recordsInserted: result.inserted,
      recordsErrors: result.errors
    });

    // Clean up temp file
    if (fs.existsSync(CONFIG.tempFile)) {
      fs.unlinkSync(CONFIG.tempFile);
    }

    log('='.repeat(60));
    log('Sync Complete');
    log(`  Records processed: ${data.length}`);
    log(`  Records inserted: ${result.inserted}`);
    log(`  Errors: ${result.errors}`);
    log('='.repeat(60));

  } catch (error) {
    log(`Sync failed: ${error.message}`, 'ERROR');
    log(error.stack, 'ERROR');
    process.exit(1);
  }
}

// Run sync
if (require.main === module) {
  sync().catch(error => {
    log(`Fatal error: ${error.message}`, 'ERROR');
    process.exit(1);
  });
}

module.exports = { sync };
