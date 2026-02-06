#!/usr/bin/env python3
"""
List all Excel files in SharePoint to find the aging report
"""

import os
import sys
from pathlib import Path
import requests
from dotenv import load_dotenv
from azure.identity import ClientSecretCredential

# Load environment variables
load_dotenv(Path(__file__).parent.parent / '.env')

CONFIG = {
    'tenant_id': os.getenv('AZURE_TENANT_ID'),
    'client_id': os.getenv('AZURE_CLIENT_ID'),
    'client_secret': os.getenv('AZURE_CLIENT_SECRET'),
    'sharepoint_site': 'swiftstartagency.sharepoint.com',
    'site_path': '/sites/PetraBrands',
}

def get_access_token():
    credential = ClientSecretCredential(
        CONFIG['tenant_id'],
        CONFIG['client_id'],
        CONFIG['client_secret']
    )
    token = credential.get_token('https://graph.microsoft.com/.default')
    return token.token

def get_site_id(access_token):
    url = f"https://graph.microsoft.com/v1.0/sites/{CONFIG['sharepoint_site']}:{CONFIG['site_path']}"
    headers = {'Authorization': f'Bearer {access_token}'}
    response = requests.get(url, headers=headers)
    response.raise_for_status()
    return response.json()['id']

def list_excel_files(access_token, site_id):
    drives_url = f"https://graph.microsoft.com/v1.0/sites/{site_id}/drives"
    headers = {'Authorization': f'Bearer {access_token}'}

    drives_response = requests.get(drives_url, headers=headers)
    drives_response.raise_for_status()
    drives = drives_response.json().get('value', [])

    print("\n" + "="*60)
    print("📁 Excel Files in SharePoint:")
    print("="*60 + "\n")

    found_files = []

    for drive in drives:
        drive_id = drive['id']
        drive_name = drive.get('name', 'Unknown')

        # Search for Excel files
        search_url = f"https://graph.microsoft.com/v1.0/drives/{drive_id}/root/search(q='.xlsx')"
        search_response = requests.get(search_url, headers=headers)
        search_response.raise_for_status()
        items = search_response.json().get('value', [])

        for item in items:
            if item.get('name', '').endswith('.xlsx'):
                found_files.append({
                    'name': item['name'],
                    'drive': drive_name,
                    'size': item.get('size', 0),
                    'modified': item.get('lastModifiedDateTime', '')
                })

    # Sort by name
    found_files.sort(key=lambda x: x['name'])

    # Print all files
    for i, file in enumerate(found_files, 1):
        size_kb = file['size'] / 1024
        print(f"{i}. {file['name']}")
        print(f"   Drive: {file['drive']}")
        print(f"   Size: {size_kb:.1f} KB")
        print(f"   Modified: {file['modified']}")
        print()

    # Highlight likely candidates
    print("="*60)
    print("🎯 Likely Aging Report Files:")
    print("="*60 + "\n")

    keywords = ['aging', 'ar ', 'receivable', 'invoice', 'hop retail', 'tracker', 'sales']
    for file in found_files:
        name_lower = file['name'].lower()
        if any(keyword in name_lower for keyword in keywords):
            print(f"✓ {file['name']}")

    print("\n" + "="*60)
    print(f"Total Excel files found: {len(found_files)}")
    print("="*60 + "\n")

def main():
    try:
        print("Connecting to SharePoint...")
        access_token = get_access_token()

        print("Getting site ID...")
        site_id = get_site_id(access_token)

        list_excel_files(access_token, site_id)

    except Exception as e:
        print(f"\n❌ Error: {str(e)}")
        import traceback
        traceback.print_exc()
        sys.exit(1)

if __name__ == '__main__':
    main()
