#!/usr/bin/env python3
"""
Full App Store Connect Screenshot Deployer for Bhai App (v1.2.0)
Uploads 100% genuine simulator-captured screenshots to:
- APP_IPHONE_67 (6.7" Super Retina XDR: 1290 x 2796)
- APP_IPHONE_65 (6.5" Super Retina XDR: 1242 x 2688)
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

def resize_set(source_dir, target_dir, target_w, target_h):
    os.makedirs(target_dir, exist_ok=True)
    for i in range(1, 6):
        src_path = os.path.join(source_dir, f"screenshot_{i}.png")
        tgt_path = os.path.join(target_dir, f"screenshot_{i}.png")
        if os.path.exists(src_path):
            im = Image.open(src_path).convert('RGB')
            resized = im.resize((target_w, target_h), Image.Resampling.LANCZOS)
            resized.save(tgt_path, format='PNG', optimize=True)

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
    # Query existing sets
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
    print("Preparing 6.7\" and 6.5\" screenshot assets...")
    resize_set('store_assets/app_store', 'store_assets/app_store/6.7', 1290, 2796)
    resize_set('store_assets/app_store', 'store_assets/app_store/6.5', 1242, 2688)

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

        # 1. APP_IPHONE_67 (6.7" Super Retina)
        print("\n--- Updating APP_IPHONE_67 (6.7\" Super Retina) ---")
        set_67_id = get_or_create_set(api, loc_id, 'APP_IPHONE_67')
        if set_67_id:
            clear_existing_screenshots(api, set_67_id)
            for i in range(1, 6):
                fn = f"screenshot_{i}.png"
                fp = f"store_assets/app_store/6.7/{fn}"
                print(f"  Uploading {fn} to 6.7\" set...")
                upload_screenshot_file(api, set_67_id, fp, fn)
                time.sleep(1)

        # 2. APP_IPHONE_65 (6.5" Super Retina)
        print("\n--- Updating APP_IPHONE_65 (6.5\" Super Retina) ---")
        set_65_id = get_or_create_set(api, loc_id, 'APP_IPHONE_65')
        if set_65_id:
            clear_existing_screenshots(api, set_65_id)
            for i in range(1, 6):
                fn = f"screenshot_{i}.png"
                fp = f"store_assets/app_store/6.5/{fn}"
                print(f"  Uploading {fn} to 6.5\" set...")
                upload_screenshot_file(api, set_65_id, fp, fn)
                time.sleep(1)

    print("\n✅ All App Store Connect screenshot sets successfully updated and committed!")

if __name__ == '__main__':
    main()
