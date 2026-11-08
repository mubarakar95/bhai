#!/usr/bin/env python3
"""
WordPress to Supabase Migration Runner for Bhai App.
Migrates:
1. Owners (auth.users + public.owners)
2. Camps (public.properties)
3. Rooms (public.rooms)
4. Guests (public.persons) + Photos download & upload to Supabase Storage
5. Stays (public.stays)
"""

import os
import sys
import csv
import json
import uuid
import re
import time
import urllib.request
import urllib.error
import urllib.parse
from concurrent.futures import ThreadPoolExecutor, as_completed
from datetime import datetime

# --- CONFIGURATION ---
SUPABASE_URL = "https://dsminsgahrnwzskmwsvn.supabase.co"
SERVICE_ROLE_KEY = "REDACTED_KEY"
STORAGE_BUCKET = "person-photos"

DATA_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "data")
USERS_CSV = os.path.join(DATA_DIR, "users.csv")
CAMPS_CSV = os.path.join(DATA_DIR, "camps.csv")
ROOMS_CSV = os.path.join(DATA_DIR, "rooms.csv")
GUESTS_CSV = os.path.join(DATA_DIR, "guests.csv")

MUBARAK_UUID = "5937c753-56a8-4731-a22a-bcd5a356cd3f"

def make_request(url, method="GET", headers=None, data=None):
    if headers is None:
        headers = {}
    headers["apikey"] = SERVICE_ROLE_KEY
    headers["Authorization"] = f"Bearer {SERVICE_ROLE_KEY}"
    
    body = None
    if data is not None:
        if isinstance(data, (dict, list)):
            body = json.dumps(data).encode("utf-8")
            headers["Content-Type"] = "application/json"
        elif isinstance(data, (bytes, bytearray)):
            body = data
        else:
            body = str(data).encode("utf-8")
            
    req = urllib.request.Request(url, data=body, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req, timeout=60) as resp:
            content_type = resp.headers.get("Content-Type", "")
            res_body = resp.read()
            if "application/json" in content_type:
                return json.loads(res_body.decode("utf-8"))
            return res_body
    except urllib.error.HTTPError as e:
        err_msg = e.read().decode("utf-8", errors="replace")
        raise RuntimeError(f"HTTP {e.code} on {method} {url}: {err_msg}")

def deduplicate_by_id(rows):
    seen = set()
    deduped = []
    for r in rows:
        rid = r["id"]
        if rid not in seen:
            seen.add(rid)
            deduped.append(r)
    return deduped

def execute_rest_batch(table, rows, batch_size=100):
    """Inserts deduplicated rows into Supabase table in batches via PostgREST."""
    rows = deduplicate_by_id(rows)
    url = f"{SUPABASE_URL}/rest/v1/{table}"
    headers = {
        "Prefer": "resolution=merge-duplicates"
    }
    total = len(rows)
    inserted = 0
    for i in range(0, total, batch_size):
        chunk = rows[i:i + batch_size]
        make_request(url, method="POST", headers=headers, data=chunk)
        inserted += len(chunk)
        print(f"  Inserted {inserted}/{total} into {table}")

def clean_phone(val):
    if not val:
        return ""
    digits = re.sub(r"\D", "", str(val))
    if len(digits) >= 10:
        return digits[-10:]
    return ""

def sanitize_date(d_str):
    if not d_str or d_str.strip() == "":
        return "1990-01-01"
    d_str = d_str.strip()
    if "T" in d_str:
        d_str = d_str.split("T")[0]
    match = re.match(r"^(\d{4})-(\d{1,2})-(\d{1,2})$", d_str)
    if match:
        year, month, day = int(match.group(1)), int(match.group(2)), int(match.group(3))
        if year < 1920 or year > 2020:
            year = 1990
        month = max(1, min(12, month))
        day = max(1, min(28, day))
        return f"{year:04d}-{month:02d}-{day:02d}"
    return "1990-01-01"

def sanitize_timestamp(ts_str):
    if not ts_str or ts_str.strip() == "":
        return datetime.utcnow().isoformat() + "Z"
    ts_str = ts_str.strip()
    if ts_str.endswith("Z"):
        return ts_str
    if "T" in ts_str:
        return ts_str + "Z"
    try:
        dt = datetime.strptime(ts_str, "%Y-%m-%d %H:%M:%S")
        return dt.isoformat() + "Z"
    except Exception:
        return datetime.utcnow().isoformat() + "Z"

def main():
    dry_run = "--dry-run" in sys.argv
    skip_images = "--skip-images" in sys.argv
    print(f"Starting Migration. dry_run={dry_run}, skip_images={skip_images}")
    
    # --- PHASE 1: OWNERS MIGRATION ---
    print("\n--- PHASE 1: OWNERS ---")
    with open(USERS_CSV, encoding="utf-8-sig") as f:
        wp_users = list(csv.DictReader(f))
        
    owner_map = {}
    owner_passwords = {}
    
    existing_auth = make_request(f"{SUPABASE_URL}/auth/v1/admin/users?per_page=100", method="GET")
    existing_emails = {}
    for u in existing_auth.get("users", []):
        existing_emails[u["email"].lower()] = u["id"]
        
    owners_to_insert = []
    
    for u in wp_users:
        uid = u["User ID"].strip()
        email = u["Email"].strip().lower()
        full_name = u["Name"].strip() or u["Username"].strip()
        username = u["Username"].strip()
        
        phone = clean_phone(username)
        if not phone:
            phone = f"90000000{int(uid):02d}"
            
        first_word = re.sub(r"[^A-Za-z]", "", full_name.split()[0]).capitalize() or "Owner"
        password = f"Bhai@{first_word}{uid}"
        owner_passwords[email] = password
        
        user_uuid = None
        if email in existing_emails:
            user_uuid = existing_emails[email]
            print(f"  Owner exists in Auth: {email} -> {user_uuid}")
        elif not dry_run:
            print(f"  Creating Auth User for: {email} (Password: {password})")
            res = make_request(
                f"{SUPABASE_URL}/auth/v1/admin/users",
                method="POST",
                data={
                    "email": email,
                    "password": password,
                    "email_confirm": True,
                    "user_metadata": {
                        "full_name": full_name,
                        "mobile_no": phone,
                        "wp_user_id": uid
                    }
                }
            )
            user_uuid = res["id"]
        else:
            user_uuid = str(uuid.uuid5(uuid.NAMESPACE_DNS, f"bhai.user.{uid}"))
            print(f"  [DRY-RUN] Would create Auth User: {email} ({password})")
            
        owner_map[uid] = user_uuid
        
        reg_date_str = u["Registered"].strip()
        try:
            reg_dt = datetime.strptime(reg_date_str, "%B %d, %Y, %I:%M %p")
            created_at = reg_dt.isoformat() + "Z"
        except Exception:
            created_at = datetime.utcnow().isoformat() + "Z"
            
        owners_to_insert.append({
            "id": user_uuid,
            "full_name": full_name,
            "business_name": f"{full_name}'s Camps",
            "mobile_no": phone,
            "email": email,
            "subscription_plan": "free",
            "created_at": created_at
        })
        
    default_admin_uuid = owner_map.get("83", MUBARAK_UUID)
    owner_map["1"] = default_admin_uuid
    owner_map["23"] = default_admin_uuid
    owner_map["0"] = default_admin_uuid
    owner_map[""] = default_admin_uuid
    
    if not dry_run:
        execute_rest_batch("owners", owners_to_insert)
        
    print(f"Owners phase completed: {len(owner_map)} owners mapped.")
    
    # --- PHASE 2: CAMPS (PROPERTIES) ---
    print("\n--- PHASE 2: CAMPS (PROPERTIES) ---")
    with open(CAMPS_CSV, encoding="utf-8-sig") as f:
        wp_camps = list(csv.DictReader(f))
    with open(ROOMS_CSV, encoding="utf-8-sig") as f:
        wp_rooms = list(csv.DictReader(f))
    with open(GUESTS_CSV, encoding="utf-8-sig") as f:
        wp_guests = list(csv.DictReader(f))
        
    camp_map = {}
    properties_to_insert = []
    
    # General fallback camp
    fallback_camp_uuid = str(uuid.uuid5(uuid.NAMESPACE_DNS, "bhai.camp.0"))
    camp_map["0"] = fallback_camp_uuid
    camp_map[""] = fallback_camp_uuid
    properties_to_insert.append({
        "id": fallback_camp_uuid,
        "owner_id": default_admin_uuid,
        "name": "General Camp (Unassigned)",
        "address": "Paippad, Kerala",
        "city": "Paippad",
        "state": "Kerala",
        "pincode": "686537",
        "property_type": "camp",
        "contact_no": "0000000000",
        "photos": [],
        "created_at": datetime.utcnow().isoformat() + "Z"
    })
    
    for c in wp_camps:
        cid = c["_ID"].strip()
        if not cid or cid == "0":
            continue
        name = c["camp_name"].strip() or f"Camp #{cid}"
        location = c["location"].strip() or "Paippad, Kerala"
        author_id = c["cct_author_id"].strip()
        owner_id = owner_map.get(author_id, default_admin_uuid)
        created_at = sanitize_timestamp(c["cct_created"])
        
        prop_uuid = str(uuid.uuid5(uuid.NAMESPACE_DNS, f"bhai.camp.{cid}"))
        camp_map[cid] = prop_uuid
        
        properties_to_insert.append({
            "id": prop_uuid,
            "owner_id": owner_id,
            "name": name,
            "address": location,
            "city": "Paippad",
            "state": "Kerala",
            "pincode": "686537",
            "property_type": "camp",
            "contact_no": "0000000000",
            "photos": [],
            "created_at": created_at
        })
        
    referenced_camps = set(r["camp_id"].strip() for r in wp_rooms if r["camp_id"].strip())
    referenced_camps.update(g["last_camp_id"].strip() for g in wp_guests if g["last_camp_id"].strip())
    missing_camps = referenced_camps - set(camp_map.keys())
    
    print(f"  Auto-generating {len(missing_camps)} placeholder properties for missing camps...")
    for cid in sorted(list(missing_camps)):
        if not cid or cid == "0":
            continue
        room_authors = [r["cct_author_id"].strip() for r in wp_rooms if r["camp_id"].strip() == cid]
        author_id = room_authors[0] if room_authors else "83"
        owner_id = owner_map.get(author_id, default_admin_uuid)
        
        prop_uuid = str(uuid.uuid5(uuid.NAMESPACE_DNS, f"bhai.camp.{cid}"))
        camp_map[cid] = prop_uuid
        
        properties_to_insert.append({
            "id": prop_uuid,
            "owner_id": owner_id,
            "name": f"Camp #{cid}",
            "address": "Paippad, Kerala (Archived)",
            "city": "Paippad",
            "state": "Kerala",
            "pincode": "686537",
            "property_type": "camp",
            "contact_no": "0000000000",
            "photos": [],
            "created_at": datetime.utcnow().isoformat() + "Z"
        })
        
    if not dry_run:
        execute_rest_batch("properties", properties_to_insert)
        
    print(f"Properties phase completed: {len(properties_to_insert)} properties ready.")
    
    # --- PHASE 3: ROOMS MIGRATION ---
    print("\n--- PHASE 3: ROOMS ---")
    room_map = {}
    rooms_to_insert = []
    
    fallback_room_uuid = str(uuid.uuid5(uuid.NAMESPACE_DNS, "bhai.room.0"))
    room_map["0"] = fallback_room_uuid
    room_map[""] = fallback_room_uuid
    rooms_to_insert.append({
        "id": fallback_room_uuid,
        "property_id": fallback_camp_uuid,
        "room_number": "General Room",
        "capacity": 50,
        "current_occupancy": 0,
        "rental_type": "monthly",
        "daily_rate": 0.0,
        "monthly_rate": 0.0,
        "hourly_rate": 0.0,
        "status": "available",
        "photos": [],
        "created_at": datetime.utcnow().isoformat() + "Z"
    })
    
    for r in wp_rooms:
        rid = r["_ID"].strip()
        if not rid or rid == "0":
            continue
        cid = r["camp_id"].strip()
        room_name = r["room_name"].strip() or f"Room {rid}"
        prop_uuid = camp_map.get(cid, fallback_camp_uuid)
        created_at = sanitize_timestamp(r["cct_created"])
        
        room_uuid = str(uuid.uuid5(uuid.NAMESPACE_DNS, f"bhai.room.{rid}"))
        room_map[rid] = room_uuid
        
        rooms_to_insert.append({
            "id": room_uuid,
            "property_id": prop_uuid,
            "room_number": room_name,
            "capacity": 4,
            "current_occupancy": 0,
            "rental_type": "monthly",
            "daily_rate": 0.0,
            "monthly_rate": 0.0,
            "hourly_rate": 0.0,
            "status": "available",
            "photos": [],
            "created_at": created_at
        })
        
    if not dry_run:
        execute_rest_batch("rooms", rooms_to_insert)
        
    print(f"Rooms phase completed: {len(rooms_to_insert)} rooms ready.")
    
    # --- PHASE 4: GUEST PROFILE PHOTOS ---
    print("\n--- PHASE 4: GUEST PROFILE PHOTOS ---")
    
    def process_photo(guest):
        gid = guest["_ID"].strip()
        url = guest["photo_url"].strip()
        if not url:
            return gid, None
            
        storage_path = f"guests/guest_{gid}.jpg"
        public_url = f"{SUPABASE_URL}/storage/v1/object/public/{STORAGE_BUCKET}/{storage_path}"
        
        if skip_images or dry_run:
            return gid, public_url
            
        # Download from WordPress with retry
        img_data = None
        for attempt in range(3):
            try:
                req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
                with urllib.request.urlopen(req, timeout=20) as resp:
                    img_data = resp.read()
                    break
            except Exception as e:
                if attempt == 2:
                    print(f"  [WARN] Failed download for guest #{gid} ({url}): {e}")
                time.sleep(0.5)
                
        if not img_data:
            return gid, url
            
        # Upload to Supabase Storage with retry
        for attempt in range(3):
            try:
                upload_url = f"{SUPABASE_URL}/storage/v1/object/{STORAGE_BUCKET}/{storage_path}"
                headers = {
                    "apikey": SERVICE_ROLE_KEY,
                    "Authorization": f"Bearer {SERVICE_ROLE_KEY}",
                    "Content-Type": "image/jpeg",
                    "x-upsert": "true"
                }
                up_req = urllib.request.Request(upload_url, data=img_data, headers=headers, method="POST")
                with urllib.request.urlopen(up_req, timeout=20) as up_resp:
                    return gid, public_url
            except Exception as e:
                if attempt == 2:
                    print(f"  [WARN] Failed storage upload for guest #{gid}: {e}")
                time.sleep(0.5)
                
        return gid, url
            
    guest_photo_map = {}
    print(f"Transferring {len(wp_guests)} guest photos using 20 concurrent workers...")
    
    start_time = time.time()
    completed = 0
    with ThreadPoolExecutor(max_workers=20) as executor:
        futures = {executor.submit(process_photo, g): g["_ID"].strip() for g in wp_guests}
        for fut in as_completed(futures):
            gid, final_url = fut.result()
            guest_photo_map[gid] = final_url
            completed += 1
            if completed % 200 == 0 or completed == len(wp_guests):
                elapsed = time.time() - start_time
                print(f"  Processed {completed}/{len(wp_guests)} photos ({elapsed:.1f}s)")
                
    # --- PHASE 5: PERSONS MIGRATION ---
    print("\n--- PHASE 5: PERSONS (GUESTS) ---")
    persons_to_insert = []
    
    for g in wp_guests:
        gid = g["_ID"].strip()
        fname = g["first_name"].strip()
        lname = g["last_name"].strip()
        name = f"{fname} {lname}".strip() or f"Guest #{gid}"
        mobile = g["mobile_no"].strip() or "0000000000"
        aadhaar = g["adhaar_no"].strip() or None
        address = g["address"].strip() or g["city"].strip() or "India"
        city = g["city"].strip() or "Unknown"
        state = g["state"].strip() or "West Bengal"
        dob = sanitize_date(g["date_of_birth"])
        author_id = g["cct_author_id"].strip()
        owner_id = owner_map.get(author_id, default_admin_uuid)
        created_at = sanitize_timestamp(g["cct_created"])
        photo_url = guest_photo_map.get(gid) or ""
        
        father_name = "Unknown"
        father_match = re.search(r"(?:[sS]/[oO]|[cC]/[oO]|Father|father)[,:\s]+([A-Za-z\s]+?)(?:,|$|\n)", address)
        if father_match:
            cand = father_match.group(1).strip()
            if len(cand) >= 2 and not cand.lower().startswith("near"):
                father_name = cand
                
        ps_circle = city
        ps_match = re.search(r"(?:[pP]\s*[sS]|Police\s*Station)[,:\s]+([A-Za-z\s]+?)(?:,|$|\n)", address)
        if ps_match:
            cand = ps_match.group(1).strip()
            if len(cand) >= 2:
                ps_circle = cand
                
        pincode = "000000"
        pin_match = re.search(r"\b\d{6}\b", address)
        if pin_match:
            pincode = pin_match.group(0)
            
        person_uuid = str(uuid.uuid5(uuid.NAMESPACE_DNS, f"bhai.person.{gid}"))
        
        persons_to_insert.append({
            "id": person_uuid,
            "name": name,
            "mobile_no": mobile,
            "aadhaar_no": aadhaar,
            "father_name": father_name,
            "mother_name": None,
            "wife_name": None,
            "wife_mobile_no": None,
            "police_station_circle": ps_circle,
            "aadhaar_card_photo": None,
            "person_photo": photo_url,
            "address": address,
            "city": city,
            "state": state,
            "pincode": pincode,
            "dob": dob,
            "is_blacklisted": False,
            "blacklist_reason": None,
            "blacklisted_by": None,
            "blacklisted_at": None,
            "created_by_owner_id": owner_id,
            "created_at": created_at
        })
        
    if not dry_run:
        execute_rest_batch("persons", persons_to_insert, batch_size=200)
        
    print(f"Persons phase completed: {len(persons_to_insert)} persons ready.")
    
    # --- PHASE 6: STAYS MIGRATION ---
    print("\n--- PHASE 6: STAYS (CHECK-IN HISTORY) ---")
    stays_to_insert = []
    room_occupancies = {}
    
    for g in wp_guests:
        gid = g["_ID"].strip()
        person_uuid = str(uuid.uuid5(uuid.NAMESPACE_DNS, f"bhai.person.{gid}"))
        
        cid = g["last_camp_id"].strip()
        rid = g["last_room_id"].strip()
        
        prop_uuid = camp_map.get(cid, fallback_camp_uuid)
        room_uuid = room_map.get(rid, fallback_room_uuid)
        
        author_id = g["cct_author_id"].strip()
        owner_id = owner_map.get(author_id, default_admin_uuid)
        
        is_active = (g["check_in_status"].strip().lower() == "true")
        status = "active" if is_active else "checked_out"
        
        check_in_str = g["last_checkin"].strip() or g["cct_created"].strip()
        check_in_date = sanitize_timestamp(check_in_str)
        
        check_out_date = None
        if not is_active and g["last_checkout"].strip():
            check_out_date = sanitize_timestamp(g["last_checkout"].strip())
            
        agreed_rate = 1000.0
        remarks = g["remarks"].strip()
        rate_match = re.search(r"\b(1000|1200|1500|2000|2500|3000|4000|5000|500|600)\b", remarks)
        if rate_match:
            agreed_rate = float(rate_match.group(0))
            
        stay_uuid = str(uuid.uuid5(uuid.NAMESPACE_DNS, f"bhai.stay.{gid}"))
        created_at = sanitize_timestamp(g["cct_created"])
        
        if is_active:
            room_occupancies[room_uuid] = room_occupancies.get(room_uuid, 0) + 1
            
        stays_to_insert.append({
            "id": stay_uuid,
            "person_id": person_uuid,
            "room_id": room_uuid,
            "property_id": prop_uuid,
            "owner_id": owner_id,
            "check_in_date": check_in_date,
            "check_out_date": check_out_date,
            "rental_type_used": "monthly",
            "agreed_rate": agreed_rate,
            "status": status,
            "created_at": created_at
        })
        
    if not dry_run:
        execute_rest_batch("stays", stays_to_insert, batch_size=200)
        
    print(f"Stays phase completed: {len(stays_to_insert)} stays ready.")
    
    if not dry_run and room_occupancies:
        print(f"Updating room occupancies for {len(room_occupancies)} active rooms...")
        for r_uuid, occ in room_occupancies.items():
            sql = f"UPDATE public.rooms SET current_occupancy = {occ}, status = CASE WHEN {occ} >= capacity THEN 'full' ELSE 'available' END WHERE id = '{r_uuid}';"
            try:
                make_request(
                    f"https://api.supabase.com/v1/projects/dsminsgahrnwzskmwsvn/database/query",
                    method="POST",
                    data={"query": sql}
                )
            except Exception as e:
                print(f"  Warning updating occupancy for room {r_uuid}: {e}")
                
    # --- PHASE 7: PRINT SUMMARY & CREDENTIALS ---
    print("\n=======================================================")
    print("MIGRATION COMPLETED SUCCESSFULLY!")
    print("=======================================================")
    print(f"Owners in DB:         {len(owner_map) - 3}")
    print(f"Properties in DB:     {len(properties_to_insert)}")
    print(f"Rooms in DB:          {len(rooms_to_insert)}")
    print(f"Guests in DB:         {len(persons_to_insert)}")
    print(f"Stays in DB:          {len(stays_to_insert)}")
    print(f"Active Stays:         {sum(1 for s in stays_to_insert if s['status'] == 'active')}")
    print("=======================================================\n")
    print("OWNER LOGIN CREDENTIALS:")
    for email, pwd in sorted(owner_passwords.items()):
        print(f"  {email} -> {pwd}")
    print("=======================================================\n")

if __name__ == "__main__":
    main()
