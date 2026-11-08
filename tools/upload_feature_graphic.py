#!/usr/bin/env python3
"""
Uploads the updated Bhai App feature graphic to Google Play Console and commits for review.
"""

import sys
import os
import json
import urllib.request
import urllib.error

sys.path.append(os.path.expanduser('~/.gemini/config/skills/store-publish/scripts'))
from play_upload import get_access_token_from_service_account

PACKAGE_NAME = 'com.bhaiapp.bhaiapp'
SERVICE_ACCOUNT_PATH = os.path.expanduser('~/.config/store-publish/service-account.json')
LANGUAGE = 'en-IN'
FG_PATH = 'store_assets/play_store/feature_graphic.png'

def main():
    print(f"==> Updating Feature Graphic for {PACKAGE_NAME} ({LANGUAGE})")
    token = get_access_token_from_service_account(SERVICE_ACCOUNT_PATH)
    headers = {'Authorization': f'Bearer {token}'}

    # 1. Create Edit Session
    create_url = f'https://androidpublisher.googleapis.com/androidpublisher/v3/applications/{PACKAGE_NAME}/edits'
    req = urllib.request.Request(create_url, data=b'', headers=headers, method='POST')
    try:
        with urllib.request.urlopen(req) as resp:
            edit_id = json.loads(resp.read().decode('utf-8'))['id']
            print(f"✓ Created edit session: {edit_id}")
    except urllib.error.HTTPError as e:
        print(f"Error creating edit session: {e.code} - {e.read().decode('utf-8')}")
        sys.exit(1)

    try:
        # 2. Delete old feature graphic
        print(f"🗑️ Deleting old feature graphic for {LANGUAGE}...")
        del_fg_url = f'https://androidpublisher.googleapis.com/androidpublisher/v3/applications/{PACKAGE_NAME}/edits/{edit_id}/listings/{LANGUAGE}/featureGraphic'
        req_del_fg = urllib.request.Request(del_fg_url, headers=headers, method='DELETE')
        try:
            with urllib.request.urlopen(req_del_fg) as resp:
                print("✓ Cleared old feature graphic")
        except Exception as e:
            print(f"Note on delete: {e}")

        # 3. Upload new feature graphic
        print(f"🎨 Uploading updated Feature Graphic (Bhai App heading)...")
        with open(FG_PATH, 'rb') as f:
            fg_data = f.read()

        upload_fg_url = f'https://androidpublisher.googleapis.com/upload/androidpublisher/v3/applications/{PACKAGE_NAME}/edits/{edit_id}/listings/{LANGUAGE}/featureGraphic?uploadType=media'
        req_upload_fg = urllib.request.Request(
            upload_fg_url,
            data=fg_data,
            headers={
                'Authorization': f'Bearer {token}',
                'Content-Type': 'image/png'
            },
            method='POST'
        )
        with urllib.request.urlopen(req_upload_fg) as resp:
            print(f"✓ Uploaded new feature graphic successfully!")

        # 4. Commit edit session (submits for review)
        print(f"\n🚀 Committing changes and sending to Google Play review...")
        commit_url = f'https://androidpublisher.googleapis.com/androidpublisher/v3/applications/{PACKAGE_NAME}/edits/{edit_id}:commit'
        req_commit = urllib.request.Request(commit_url, data=b'', headers=headers, method='POST')
        with urllib.request.urlopen(req_commit) as resp:
            commit_res = json.loads(resp.read().decode('utf-8'))
            print(f"✓ Edit committed successfully! Result: {commit_res}")
            print(f"\n🎉 SUCCESS: Feature graphic updated with 'Bhai App' and submitted to Google Play Review!")

    except Exception as e:
        print(f"❌ Error during update: {e}")
        try:
            del_url = f'https://androidpublisher.googleapis.com/androidpublisher/v3/applications/{PACKAGE_NAME}/edits/{edit_id}'
            urllib.request.urlopen(urllib.request.Request(del_url, headers=headers, method='DELETE'))
        except Exception:
            pass
        sys.exit(1)

if __name__ == '__main__':
    main()
