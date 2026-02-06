#!/bin/bash
# Setup automated daily sync for HOP Tracker

echo "🗓️  Setting up automated daily sync for HOP Tracker..."
echo ""

# Get the project directory
PROJECT_DIR="/Users/ali/clawd/hop-dashboards"
PLIST_FILE="$HOME/Library/LaunchAgents/com.hop.tracker.sync.plist"

# Create LaunchAgents directory if it doesn't exist
mkdir -p "$HOME/Library/LaunchAgents"

# Create the plist file
cat > "$PLIST_FILE" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.hop.tracker.sync</string>

    <key>ProgramArguments</key>
    <array>
        <string>/usr/local/bin/node</string>
        <string>$PROJECT_DIR/automation/sync-hop-tracker.js</string>
    </array>

    <key>WorkingDirectory</key>
    <string>$PROJECT_DIR</string>

    <key>StartCalendarInterval</key>
    <dict>
        <key>Hour</key>
        <integer>6</integer>
        <key>Minute</key>
        <integer>0</integer>
    </dict>

    <key>StandardOutPath</key>
    <string>$PROJECT_DIR/logs/sync_stdout.log</string>

    <key>StandardErrorPath</key>
    <string>$PROJECT_DIR/logs/sync_stderr.log</string>

    <key>RunAtLoad</key>
    <false/>
</dict>
</plist>
EOF

echo "✅ Created launch agent configuration"
echo "   Location: $PLIST_FILE"
echo ""

# Set correct permissions
chmod 644 "$PLIST_FILE"

# Load the launch agent
launchctl unload "$PLIST_FILE" 2>/dev/null
launchctl load "$PLIST_FILE"

if [ $? -eq 0 ]; then
    echo "✅ Launch agent loaded successfully"
    echo ""
    echo "📋 Configuration:"
    echo "   • Runs daily at 6:00 AM"
    echo "   • Syncs HOP Tracker from SharePoint to Supabase"
    echo "   • Only syncs when file changes are detected"
    echo "   • Logs to: $PROJECT_DIR/logs/"
    echo ""
    echo "🔧 Management commands:"
    echo "   • Test now:  launchctl start com.hop.tracker.sync"
    echo "   • View logs: tail -f $PROJECT_DIR/logs/sync.log"
    echo "   • Disable:   launchctl unload $PLIST_FILE"
    echo "   • Enable:    launchctl load $PLIST_FILE"
    echo ""
    echo "✅ Automated sync is now active!"
else
    echo "❌ Failed to load launch agent"
    echo "   Please check the plist file for errors"
    exit 1
fi
