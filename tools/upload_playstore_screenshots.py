#!/usr/bin/env python3
"""
Uploads new marketing screenshots and feature graphic to Google Play Console for com.bhaiapp.bhaiapp.
Commits the edit session so changes are submitted to Google Play review.
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
ASSETS_DIR = 'store_assets/play_store'

def main():
    print(f"==> Uploading Play Store Assets for {PACKAGE_NAME} ({LANGUAGE})")
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
        # 2. Clear old phone screenshots
        print(f"🗑️ Deleting old phone screenshots for {LANGUAGE}...")
        del_ss_url = f'https://androidpublisher.googleapis.com/androidpublisher/v3/applications/{PACKAGE_NAME}/edits/{edit_id}/listings/{LANGUAGE}/phoneScreenshots'
        req_del = urllib.request.Request(del_ss_url, headers=headers, method='DELETE')
        try:
            with urllib.request.urlopen(req_del) as resp:
                print(f"✓ Cleared old phone screenshots")
        except urllib.error.HTTPError as e:
            print(f"Note on deleting screenshots: {e.code} - {e.read().decode('utf-8')}")

        # 3. Upload new phone screenshots
        screenshot_files = [f"screenshot_{i}.png" for i in range(1, 6)]
        for sf in screenshot_files:
            file_path = os.path.join(ASSETS_DIR, sf)
            if not os.path.exists(file_path):
                print(f"❌ Missing file: {file_path}")
                continue

            with open(file_path, 'rb') as f:
                img_data = f.read()

            upload_url = f'https://androidpublisher.googleapis.com/upload/androidpublisher/v3/applications/{PACKAGE_NAME}/edits/{edit_id}/listings/{LANGUAGE}/phoneScreenshots?uploadType=media'
            req_upload = urllib.request.Request(
                upload_url,
                data=img_data,
                headers={
                    'Authorization': f'Bearer {token}',
                    'Content-Type': 'image/png'
                },
                method='POST'
            )
            with urllib.request.urlopen(req_upload) as resp:
                res_data = json.loads(resp.read().decode('utf-8'))
                img_id = res_data.get('image', {}).get('id') or res_data.get('id')
                print(f"  ✓ Uploaded {sf} (ID: {img_id})")

        # 4. Upload feature graphic if present
        fg_path = os.path.join(ASSETS_DIR, 'feature_graphic.png')
        if os.path.exists(fg_path):
            print(f"🗑️ Deleting old feature graphic for {LANGUAGE}...")
            del_fg_url = f'https://androidpublisher.googleapis.com/androidpublisher/v3/applications/{PACKAGE_NAME}/edits/{edit_id}/listings/{LANGUAGE}/featureGraphic'
            req_del_fg = urllib.request.Request(del_fg_url, headers=headers, method='DELETE')
            try:
                with urllib.request.urlopen(req_del_fg) as resp:
                    pass
            except Exception:
                pass

            print(f"🎨 Uploading new Feature Graphic (1024x500)...")
            with open(fg_path, 'rb') as f:
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
                print(f"  ✓ Uploaded feature_graphic.png")

        # 5. Commit edit session (submits for review)
        print(f"\n🚀 Committing changes and sending to Google Play review...")
        commit_url = f'https://androidpublisher.googleapis.com/androidpublisher/v3/applications/{PACKAGE_NAME}/edits/{edit_id}:commit'
        req_commit = urllib.request.Request(commit_url, data=b'', headers=headers, method='POST')
        with urllib.request.urlopen(req_commit) as resp:
            commit_res = json.loads(resp.read().decode('utf-8'))
            print(f"✓ Edit committed successfully! Result: {commit_res}")
            print(f"\n🎉 SUCCESS: All Play Store screenshots & Feature Graphic updated and submitted for Google Play review!")

    except Exception as e:
        print(f"❌ Error during update: {e}")
        # Clean up
        try:
            del_url = f'https://androidpublisher.googleapis.com/androidpublisher/v3/applications/{PACKAGE_NAME}/edits/{edit_id}'
            urllib.request.urlopen(urllib.request.Request(del_url, headers=headers, method='DELETE'))
        except Exception:
            pass
        sys.exit(1)

if __name__ == '__main__':
    main()
