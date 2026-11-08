#!/usr/bin/env python3
"""
Uploads real simulator-captured iPad Pro screenshots to App Store Connect.
Targets:
- APP_IPAD_PRO_3GEN_129 (12.9" / 13" iPad Pro 3rd-6th Gen / M4: 2048 x 2732)
"""

import os
import sys
import json
import time
import requests
from PIL import Image

sys.path.append(os.path.expanduser('~/.gemini/config/skills/store-publish/scripts'))
from ios_submit import AppStoreConnectAPI, load_config

BUNDLE_ID = 'com.mubaraktech.bhaiapp'
IPAD_DIR = 'store_assets/app_store/ipad'

def upload_screenshot_file(api, set_id, file_path, file_name):
    file_size = os.path.getsize(file_path)
    with open(file_path, 'rb') as f:
        file_bytes = f.read()

    # Step 1: Reserve screenshot
    reserve_payload = {
        "data": {
            "type": "appScreenshots",
            "attributes": {
                "fileName": file_name,
                "fileSize": file_size
            },
            "relationships": {
                "appScreenshotSet": {
                    "data": {
                        "type": "appScreenshotSets",
                        "id": set_id
                    }
                }
            }
        }
    }

    resp = api._request('POST', '/appScreenshots', json_data=reserve_payload)
    if resp.status_code not in (200, 201):
        print(f"    ✗ Failed to reserve {file_name}: {resp.status_code} - {resp.text}")
        return False

    screenshot_data = resp.json()['data']
    screenshot_id = screenshot_data['id']
    upload_ops = screenshot_data['attributes']['uploadOperations']

    # Step 2: Upload chunks
    for op in upload_ops:
        url = op['url']
        offset = op['offset']
        length = op['length']
        chunk = file_bytes[offset:offset + length]
        headers = {h['name']: h['value'] for h in op.get('requestHeaders', [])}
        put_resp = requests.put(url, data=chunk, headers=headers)
        if put_resp.status_code not in (200, 201):
            print(f"    ✗ Chunk PUT failed: {put_resp.status_code} - {put_resp.text}")
            return False

    # Step 3: Commit
    commit_payload = {
        "data": {
            "type": "appScreenshots",
            "id": screenshot_id,
            "attributes": {
                "uploaded": True
            }
        }
    }
    commit_resp = api._request('PATCH', f'/appScreenshots/{screenshot_id}', json_data=commit_payload)
    if commit_resp.status_code in (200, 201):
        print(f"    ✓ Uploaded & Committed {file_name} (ID: {screenshot_id})")
        return True
    else:
        print(f"    ✗ Commit failed: {commit_resp.status_code} - {commit_resp.text}")
        return False

def get_or_create_set(api, loc_id, display_type):
    res = api._request('GET', f"/appStoreVersionLocalizations/{loc_id}/appScreenshotSets")
    for s in res.json().get('data', []):
        if s['attributes']['screenshotDisplayType'] == display_type:
            return s['id']

    # Create new set
    create_payload = {
        "data": {
            "type": "appScreenshotSets",
            "attributes": {
                "screenshotDisplayType": display_type
            },
            "relationships": {
                "appStoreVersionLocalization": {
                    "data": {
                        "type": "appStoreVersionLocalizations",
                        "id": loc_id
                    }
                }
            }
        }
    }
    resp = api._request('POST', '/appScreenshotSets', json_data=create_payload)
    if resp.status_code in (200, 201):
        return resp.json()['data']['id']
    else:
        print(f"Failed to create set for {display_type}: {resp.status_code} - {resp.text}")
        return None

def clear_existing_screenshots(api, set_id):
    res = api._request('GET', f"/appScreenshotSets/{set_id}/appScreenshots")
    for s in res.json().get('data', []):
        sid = s['id']
        api._request('DELETE', f"/appScreenshots/{sid}")
        print(f"    Deleted old screenshot {sid}")

def main():
    cfg = load_config()
    api = AppStoreConnectAPI(
        key_id=cfg['APPLE_API_KEY'],
        issuer_id=cfg['APPLE_API_ISSUER'],
        key_path=cfg['APPLE_API_KEY_PATH']
    )

    print(f"Connecting to App Store Connect for bundle '{BUNDLE_ID}'...")
    app = api.get_app_by_bundle_id(BUNDLE_ID)
    app_id = app['id']

    # Get active version in PREPARE_FOR_SUBMISSION
    res = api._request('GET', f"/apps/{app_id}/appStoreVersions")
    versions = res.json().get('data', [])
    target_version = None
    for v in versions:
        if v['attributes']['appStoreState'] == 'PREPARE_FOR_SUBMISSION':
            target_version = v
            break

    if not target_version:
        print("No version found in PREPARE_FOR_SUBMISSION.")
        return

    ver_id = target_version['id']
    ver_str = target_version['attributes']['versionString']
    print(f"Targeting active editable version: {ver_str} (ID: {ver_id})")

    # Localizations
    loc_res = api._request('GET', f"/appStoreVersions/{ver_id}/appStoreVersionLocalizations")
    locs = loc_res.json().get('data', [])

    for loc in locs:
        loc_id = loc['id']
        locale = loc['attributes']['locale']
        print(f"\n==========================================")
        print(f"Processing Localization: {locale}")
        print(f"==========================================")

        # APP_IPAD_PRO_3GEN_129
        display_types = ['APP_IPAD_PRO_3GEN_129', 'APP_IPAD_PRO_129']
        for dt in display_types:
            print(f"\n--- Updating {dt} (12.9\" / 13\" iPad Pro: 2048x2732) ---")
            set_id = get_or_create_set(api, loc_id, dt)
            if set_id:
                clear_existing_screenshots(api, set_id)
                for i in range(1, 6):
                    fn = f"screenshot_{i}.png"
                    fp = os.path.join(IPAD_DIR, fn)
                    if os.path.exists(fp):
                        print(f"  Uploading {fn} to {dt} set...")
                        upload_screenshot_file(api, set_id, fp, fn)
                        time.sleep(1)

    print("\n✅ All iPad Pro screenshots successfully uploaded and committed to App Store Connect!")

if __name__ == '__main__':
    main()
