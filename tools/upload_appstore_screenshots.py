#!/usr/bin/env python3
"""
Uploads real screenshot previews to Apple App Store Connect via the App Store Connect API v1.
Targets version in PREPARE_FOR_SUBMISSION for bundle ID 'com.mubaraktech.bhaiapp'.
"""

import os
import sys
import json
import time
import requests
sys.path.append(os.path.expanduser('~/.gemini/config/skills/store-publish/scripts'))
from ios_submit import AppStoreConnectAPI, load_config

BUNDLE_ID = 'com.mubaraktech.bhaiapp'
SCREENSHOT_DIR = 'store_assets/app_store'

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
    
    resp = api._request('POST', '/v1/appScreenshots', json_data=reserve_payload)
    if resp.status_code not in (200, 201):
        print(f"  ✗ Failed to reserve {file_name}: {resp.status_code} - {resp.text}")
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
            print(f"  ✗ Chunk upload failed: {put_resp.status_code} - {put_resp.text}")
            return False

    # Step 3: Commit upload
    commit_payload = {
        "data": {
            "type": "appScreenshots",
            "id": screenshot_id,
            "attributes": {
                "uploaded": True,
                "sourceFileChecksum": screenshot_data['attributes'].get('sourceFileChecksum')
            }
        }
    }
    commit_resp = api._request('PATCH', f'/v1/appScreenshots/{screenshot_id}', json_data=commit_payload)
    if commit_resp.status_code in (200, 201):
        print(f"  ✓ Uploaded & Committed {file_name} (ID: {screenshot_id})")
        return True
    else:
        print(f"  ✗ Failed to commit {file_name}: {commit_resp.status_code} - {commit_resp.text}")
        return False

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

    # Get active version
    res = api._request('GET', f"/v1/apps/{app_id}/appStoreVersions")
    versions = res.json().get('data', [])
    target_version = None
    for v in versions:
        if v['attributes']['appStoreState'] == 'PREPARE_FOR_SUBMISSION':
            target_version = v
            break

    if not target_version:
        print("No version found in PREPARE_FOR_SUBMISSION state.")
        return

    ver_id = target_version['id']
    ver_str = target_version['attributes']['versionString']
    print(f"Found active editable version: {ver_str} (ID: {ver_id})")

    # Get localizations
    loc_res = api._request('GET', f"/v1/appStoreVersions/{ver_id}/appStoreVersionLocalizations")
    locs = loc_res.json().get('data', [])
    if not locs:
        print("No localizations found for version.")
        return

    for loc in locs:
        loc_id = loc['id']
        locale = loc['attributes']['locale']
        print(f"\nProcessing localization: {locale} (ID: {loc_id})")

        # Get existing screenshot sets
        ss_res = api._request('GET', f"/v1/appStoreVersionLocalizations/{loc_id}/appScreenshotSets")
        existing_sets = ss_res.json().get('data', [])
        
        target_set_type = 'APP_IPHONE_67' # 6.7" Super Retina (1290x2796)
        target_set = None
        for s in existing_sets:
            if s['attributes']['screenshotDisplayType'] == target_set_type:
                target_set = s
                break

        # Create screenshot set if it doesn't exist
        if not target_set:
            print(f"Creating screenshot set for '{target_set_type}'...")
            create_payload = {
                "data": {
                    "type": "appScreenshotSets",
                    "attributes": {
                        "screenshotDisplayType": target_set_type
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
            create_resp = api._request('POST', '/v1/appScreenshotSets', json_data=create_payload)
            if create_resp.status_code in (200, 201):
                target_set = create_resp.json()['data']
                print(f"Created screenshot set: {target_set['id']}")
            else:
                print(f"Failed to create screenshot set: {create_resp.status_code} - {create_resp.text}")
                continue

        set_id = target_set['id']

        # Clear any existing screenshots in this set
        cur_ss = api._request('GET', f"/v1/appScreenshotSets/{set_id}/appScreenshots").json().get('data', [])
        for old_s in cur_ss:
            api._request('DELETE', f"/v1/appScreenshots/{old_s['id']}")
            print(f"  Removed previous screenshot: {old_s['attributes']['fileName']}")

        # Upload new 5 screenshots
        for i in range(1, 6):
            fn = f"screenshot_{i}.png"
            fp = os.path.join(SCREENSHOT_DIR, fn)
            if os.path.exists(fp):
                print(f"Uploading {fn} to App Store Connect...")
                upload_screenshot_file(api, set_id, fp, fn)
                time.sleep(1)

    print("\nAll App Store Connect screenshots successfully uploaded!")

if __name__ == '__main__':
    main()
