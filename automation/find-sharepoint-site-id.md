# How to Find Your SharePoint Site ID

There are three methods to find your SharePoint site ID:

## Method 1: Browser Console (Easiest)

1. Navigate to your SharePoint site in a web browser
2. Open browser developer tools:
   - **Chrome/Edge**: Press `F12` or `Ctrl+Shift+I` (Windows) / `Cmd+Option+I` (Mac)
   - **Firefox**: Press `F12` or `Ctrl+Shift+K` (Windows) / `Cmd+Option+K` (Mac)
3. Go to the **Console** tab
4. Type or paste this command:
   ```javascript
   _spPageContextInfo.siteId
   ```
5. Press Enter
6. Copy the GUID that appears (format: `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx`)

**Example output:**
```
"12345678-1234-1234-1234-123456789abc"
```

## Method 2: Using Microsoft Graph Explorer

1. Go to [Microsoft Graph Explorer](https://developer.microsoft.com/graph/graph-explorer)
2. Sign in with your Microsoft 365 account
3. Run this query (replace `yourdomain.sharepoint.com` with your domain and `sites/yoursite` with your site path):
   ```
   GET https://graph.microsoft.com/v1.0/sites/yourdomain.sharepoint.com:/sites/yoursite
   ```
4. Look for the `id` field in the response
5. Copy the site ID portion (after the comma)

**Example response:**
```json
{
  "id": "yourdomain.sharepoint.com,12345678-1234-1234-1234-123456789abc,87654321-4321-4321-4321-cba987654321"
}
```
The site ID is: `12345678-1234-1234-1234-123456789abc`

## Method 3: Using PowerShell (Requires PnP PowerShell)

1. Install PnP PowerShell if you haven't:
   ```powershell
   Install-Module -Name PnP.PowerShell
   ```

2. Connect to your SharePoint site:
   ```powershell
   Connect-PnPOnline -Url "https://yourdomain.sharepoint.com/sites/yoursite" -Interactive
   ```

3. Get the site ID:
   ```powershell
   (Get-PnPSite).Id
   ```

4. Copy the GUID that appears

## Troubleshooting

### Console shows "undefined" or error
- Make sure you're on a SharePoint site page (not the home page or a modern page)
- Try navigating to a document library first
- Ensure you're logged into SharePoint

### Graph Explorer returns 404
- Check your site URL is correct
- Verify you have permissions to access the site
- Try using the site's full path

### PowerShell connection fails
- Ensure you have the latest PnP PowerShell: `Update-Module PnP.PowerShell`
- Try using `-UseWebLogin` flag: `Connect-PnPOnline -Url "..." -UseWebLogin`
- Check your Microsoft 365 admin permissions

## Updating Your Configuration

Once you have your site ID:

1. Open `automation/.env`
2. Update the line:
   ```bash
   SHAREPOINT_SITE_ID=your-site-id-here
   ```
3. Replace `your-site-id-here` with the GUID you copied
4. Save the file

Example:
```bash
SHAREPOINT_SITE_ID=12345678-1234-1234-1234-123456789abc
```

## Verifying It Works

Test your configuration:
```bash
node automation/sync-hop-tracker.js
```

If the site ID is correct, you should see:
```
[INFO] Searching for file: HOP Retail Sales & PO Tracker.xlsx
[INFO] Found file: ...
```

If the site ID is wrong, you'll see:
```
[ERROR] Error finding file: The requested site could not be found
```
