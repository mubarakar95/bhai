#!/usr/bin/env python3
"""
Store Screenshot Preview Generator for Bhai App
Generates professional, high-converting marketing screenshot suites for:
- Google Play Store (1080 x 1920)
- Apple App Store (1290 x 2796 - 6.7" Super Retina Display)
"""

import os
from PIL import Image, ImageDraw, ImageFont, ImageFilter

PLAY_W, PLAY_H = 1080, 1920
IOS_W, IOS_H = 1290, 2796

FONT_FILE = '/System/Library/Fonts/HelveticaNeue.ttc'

def get_font(size, weight='bold'):
    idx = 1 if weight == 'bold' else (10 if weight == 'medium' else (7 if weight == 'light' else 0))
    try:
        return ImageFont.truetype(FONT_FILE, size, index=idx)
    except:
        return ImageFont.load_default()

def draw_gradient(draw, width, height, start_color, end_color):
    for y in range(height):
        t = y / float(height)
        r = int(start_color[0] + (end_color[0] - start_color[0]) * t)
        g = int(start_color[1] + (end_color[1] - start_color[1]) * t)
        b = int(start_color[2] + (end_color[2] - start_color[2]) * t)
        draw.line([(0, y), (width, y)], fill=(r, g, b))

def draw_device_mockup(base_img, phone_x, phone_y, phone_w, phone_h, render_ui_func):
    screen_corner = int(phone_w * 0.08)
    screen_img = Image.new('RGBA', (phone_w, phone_h), (255, 255, 255, 255))
    screen_draw = ImageDraw.Draw(screen_img)

    status_h = int(phone_h * 0.052)
    render_ui_func(screen_draw, phone_w, phone_h, status_h)

    # Dynamic Island overlay
    di_w, di_h = int(phone_w * 0.28), int(status_h * 0.60)
    di_x = (phone_w - di_w) // 2
    screen_draw.rounded_rectangle([di_x, int(status_h * 0.22), di_x + di_w, int(status_h * 0.22) + di_h], radius=di_h//2, fill=(10, 10, 10, 255))
    
    # Time (white)
    time_font = get_font(int(status_h * 0.38), 'bold')
    screen_draw.text((int(phone_w * 0.08), int(status_h * 0.26)), "9:41", font=time_font, fill=(255, 255, 255, 255))
    
    # Battery & Wifi icons
    screen_draw.rounded_rectangle([phone_w - int(phone_w * 0.13), int(status_h * 0.35), phone_w - int(phone_w * 0.07), int(status_h * 0.68)], radius=3, outline=(255, 255, 255, 255), width=1)
    screen_draw.rectangle([phone_w - int(phone_w * 0.12), int(status_h * 0.40), phone_w - int(phone_w * 0.08), int(status_h * 0.63)], fill=(255, 255, 255, 255))
    screen_draw.rectangle([phone_w - int(phone_w * 0.065), int(status_h * 0.44), phone_w - int(phone_w * 0.06), int(status_h * 0.58)], fill=(255, 255, 255, 255))

    mask = Image.new('L', (phone_w, phone_h), 0)
    mask_draw = ImageDraw.Draw(mask)
    mask_draw.rounded_rectangle([0, 0, phone_w, phone_h], radius=screen_corner, fill=255)

    bezel_pad = int(phone_w * 0.02)
    outer_w = phone_w + bezel_pad * 2
    outer_h = phone_h + bezel_pad * 2
    
    shadow_img = Image.new('RGBA', (outer_w + 60, outer_h + 80), (0, 0, 0, 0))
    shadow_draw = ImageDraw.Draw(shadow_img)
    shadow_draw.rounded_rectangle([30, 40, outer_w + 30, outer_h + 40], radius=screen_corner + bezel_pad, fill=(0, 0, 0, 95))
    shadow_img = shadow_img.filter(ImageFilter.GaussianBlur(25))

    frame_img = Image.new('RGBA', (outer_w, outer_h), (15, 23, 42, 255))
    frame_draw = ImageDraw.Draw(frame_img)
    frame_draw.rounded_rectangle([0, 0, outer_w, outer_h], radius=screen_corner + bezel_pad, fill=(30, 41, 59, 255), outline=(71, 85, 105, 255), width=bezel_pad)

    frame_img.paste(screen_img, (bezel_pad, bezel_pad), mask=mask)

    base_img.paste(shadow_img, (phone_x - bezel_pad - 30, phone_y - bezel_pad - 20), mask=shadow_img)
    base_img.paste(frame_img, (phone_x - bezel_pad, phone_y - bezel_pad), mask=frame_img)

# --- High Fidelity UI Renderers with Exact Vertical Spacing ---

def render_dashboard(draw, w, h, top_inset):
    draw.rectangle([0, 0, w, h], fill=(248, 250, 252))
    appbar_h = int(h * 0.08)
    draw.rectangle([0, 0, w, top_inset + appbar_h], fill=(37, 99, 235))
    
    f_title = get_font(int(appbar_h * 0.34), 'bold')
    f_sub = get_font(int(appbar_h * 0.20), 'medium')
    draw.text((int(w * 0.06), top_inset + int(appbar_h * 0.18)), "Bhai App", font=f_title, fill=(255, 255, 255))
    draw.text((int(w * 0.06), top_inset + int(appbar_h * 0.60)), "Green Valley PG - Bangalore", font=f_sub, fill=(219, 234, 254))

    card_y = top_inset + appbar_h + int(h * 0.02)
    card_w = int(w * 0.42)
    card_h = int(h * 0.10)
    gap = int(w * 0.04)

    metrics = [
        ("OCCUPANCY", "95.2%", "38 / 40 Beds", (37, 99, 235), (239, 246, 255)),
        ("AVAILABLE", "2 Beds", "Ready to move in", (16, 185, 129), (236, 253, 245)),
        ("MONTHLY RENT", "₹ 2,47,000", "98% Collected", (139, 92, 246), (245, 243, 255)),
        ("DUE BALANCE", "₹ 5,000", "1 Pending tenant", (239, 68, 68), (254, 242, 242))
    ]
    f_lbl = get_font(int(card_h * 0.14), 'bold')
    f_val = get_font(int(card_h * 0.28), 'bold')
    f_desc = get_font(int(card_h * 0.13), 'medium')

    for i, (lbl, val, desc, tc, bg) in enumerate(metrics):
        cx = int(w * 0.06) + (i % 2) * (card_w + gap)
        cy = card_y + (i // 2) * (card_h + int(h * 0.015))
        draw.rounded_rectangle([cx, cy, cx + card_w, cy + card_h], radius=16, fill=bg, outline=(226, 232, 240), width=1)
        draw.text((cx + 16, cy + 12), lbl, font=f_lbl, fill=tc)
        draw.text((cx + 16, cy + 34), val, font=f_val, fill=(15, 23, 42))
        draw.text((cx + 16, cy + 70), desc, font=f_desc, fill=(100, 116, 139))

    action_y = card_y + card_h * 2 + int(h * 0.03)
    draw.text((int(w * 0.06), action_y), "Quick Actions", font=get_font(int(h * 0.020), 'bold'), fill=(15, 23, 42))
    
    actions = [("Add Guest", (37, 99, 235)), ("Collect Rent", (16, 185, 129)), ("Police Report", (245, 158, 11)), ("Room Map", (79, 70, 229))]
    btn_w = int(w * 0.20)
    btn_y = action_y + int(h * 0.028)
    f_btn = get_font(int(h * 0.013), 'bold')
    for i, (act, col) in enumerate(actions):
        bx = int(w * 0.06) + i * (btn_w + int(w * 0.027))
        draw.rounded_rectangle([bx, btn_y, bx + btn_w, btn_y + int(h * 0.048)], radius=12, fill=col)
        draw.text((bx + 12, btn_y + int(h * 0.015)), act, font=f_btn, fill=(255, 255, 255))

    list_y = btn_y + int(h * 0.068)
    draw.text((int(w * 0.06), list_y), "Active Tenants", font=get_font(int(h * 0.020), 'bold'), fill=(15, 23, 42))
    tenants = [
        ("Rahul Sharma", "Room 102 - Bed B", "₹ 6,500/mo", "PAID", (16, 185, 129)),
        ("Mohammed Zeeshan", "Room 105 - Bed A", "₹ 7,000/mo", "PAID", (16, 185, 129)),
        ("Anand Verma", "Room 201 - Bed C", "₹ 5,000/mo", "DUE", (239, 68, 68)),
        ("Deepak Patel", "Room 204 - Bed A", "₹ 6,500/mo", "PAID", (16, 185, 129))
    ]
    f_tname = get_font(int(h * 0.017), 'bold')
    f_tdet = get_font(int(h * 0.013), 'medium')
    f_tag = get_font(int(h * 0.011), 'bold')

    item_y = list_y + int(h * 0.032)
    for name, rm, rent, st, col in tenants:
        draw.rounded_rectangle([int(w * 0.06), item_y, int(w * 0.94), item_y + int(h * 0.070)], radius=14, fill=(255, 255, 255), outline=(226, 232, 240), width=1)
        draw.ellipse([int(w * 0.09), item_y + 12, int(w * 0.09) + int(h * 0.045), item_y + 12 + int(h * 0.045)], fill=(224, 231, 255))
        draw.text((int(w * 0.11), item_y + 16), name[0], font=f_tname, fill=(37, 99, 235))
        draw.text((int(w * 0.22), item_y + 14), name, font=f_tname, fill=(15, 23, 42))
        draw.text((int(w * 0.22), item_y + 38), f"{rm} • {rent}", font=f_tdet, fill=(100, 116, 139))
        draw.rounded_rectangle([int(w * 0.78), item_y + 18, int(w * 0.91), item_y + 44], radius=6, fill=col)
        draw.text((int(w * 0.81), item_y + 22), st, font=f_tag, fill=(255, 255, 255))
        item_y += int(h * 0.082)


def render_guest_profile(draw, w, h, top_inset):
    draw.rectangle([0, 0, w, h], fill=(248, 250, 252))
    appbar_h = int(h * 0.08)
    draw.rectangle([0, 0, w, top_inset + appbar_h], fill=(37, 99, 235))
    draw.text((int(w * 0.06), top_inset + int(appbar_h * 0.35)), "Tenant ID & Verification", font=get_font(int(appbar_h * 0.32), 'bold'), fill=(255, 255, 255))

    card_y = top_inset + appbar_h + int(h * 0.02)
    card_h = int(h * 0.26)
    draw.rounded_rectangle([int(w * 0.06), card_y, int(w * 0.94), card_y + card_h], radius=18, fill=(255, 255, 255), outline=(226, 232, 240), width=1)
    
    avatar_size = int(h * 0.09)
    draw.ellipse([int(w * 0.10), card_y + 22, int(w * 0.10) + avatar_size, card_y + 22 + avatar_size], fill=(219, 234, 254), outline=(37, 99, 235), width=2)
    draw.text((int(w * 0.14), card_y + 30), "A", font=get_font(int(h * 0.040), 'bold'), fill=(37, 99, 235))
    
    draw.text((int(w * 0.32), card_y + 20), "Arjun Nambiar", font=get_font(int(h * 0.024), 'bold'), fill=(15, 23, 42))
    draw.text((int(w * 0.32), card_y + 65), "+91 98471 20045", font=get_font(int(h * 0.015), 'medium'), fill=(100, 116, 139))
    draw.text((int(w * 0.32), card_y + 95), "Room 203 (Bed A) • Green Valley PG", font=get_font(int(h * 0.014), 'medium'), fill=(71, 85, 105))

    draw.rounded_rectangle([int(w * 0.32), card_y + 130, int(w * 0.88), card_y + 168], radius=8, fill=(236, 253, 245), outline=(16, 185, 129), width=1)
    draw.text((int(w * 0.35), card_y + 140), "✓ AADHAAR VERIFIED & RECORDED", font=get_font(int(h * 0.012), 'bold'), fill=(5, 150, 105))

    aadh_y = card_y + card_h + int(h * 0.025)
    draw.text((int(w * 0.06), aadh_y), "Government Identity Card Scan", font=get_font(int(h * 0.019), 'bold'), fill=(15, 23, 42))

    box_y = aadh_y + int(h * 0.03)
    box_h = int(h * 0.22)
    draw.rounded_rectangle([int(w * 0.06), box_y, int(w * 0.94), box_y + box_h], radius=16, fill=(241, 245, 249), outline=(148, 163, 184), width=1)
    
    acard_x, acard_y = int(w * 0.10), box_y + int(box_h * 0.08)
    acard_w, acard_h = int(w * 0.80), int(box_h * 0.84)
    draw.rounded_rectangle([acard_x, acard_y, acard_x + acard_w, acard_y + acard_h], radius=10, fill=(255, 255, 255), outline=(203, 213, 225), width=1)
    draw.rectangle([acard_x, acard_y, acard_x + acard_w, acard_y + 6], fill=(249, 115, 22))
    draw.rectangle([acard_x, acard_y + acard_h - 6, acard_x + acard_w, acard_y + acard_h], fill=(34, 197, 94))
    
    draw.text((acard_x + 16, acard_y + 16), "Unique Identification Authority of India (UIDAI)", font=get_font(int(h * 0.012), 'bold'), fill=(71, 85, 105))
    
    # Photo box
    draw.rectangle([acard_x + 16, acard_y + 40, acard_x + 80, acard_y + 112], fill=(226, 232, 240), outline=(148, 163, 184))
    draw.text((acard_x + 98, acard_y + 42), "Arjun Nambiar", font=get_font(int(h * 0.017), 'bold'), fill=(15, 23, 42))
    draw.text((acard_x + 98, acard_y + 70), "DOB: 14/08/1997 | Gender: Male", font=get_font(int(h * 0.013), 'medium'), fill=(100, 116, 139))
    draw.text((acard_x + 98, acard_y + 96), "XXXX XXXX 8924", font=get_font(int(h * 0.018), 'bold'), fill=(37, 99, 235))

    det_y = box_y + box_h + int(h * 0.03)
    draw.text((int(w * 0.06), det_y), "Police Verification Data", font=get_font(int(h * 0.019), 'bold'), fill=(15, 23, 42))
    
    table_y = det_y + int(h * 0.03)
    items = [
        ("Father's Name", "R. Nambiar"),
        ("Permanent Address", "Kozhikode, Kerala - 673001"),
        ("Police Station Circle", "Central Police Station - Kozhikode"),
        ("Emergency Contact", "+91 94470 11223 (Father)")
    ]
    for label, val in items:
        draw.text((int(w * 0.06), table_y), label, font=get_font(int(h * 0.013), 'medium'), fill=(100, 116, 139))
        draw.text((int(w * 0.45), table_y), val, font=get_font(int(h * 0.013), 'bold'), fill=(15, 23, 42))
        draw.line([(int(w * 0.06), table_y + 24), (int(w * 0.94), table_y + 24)], fill=(241, 245, 249))
        table_y += int(h * 0.038)


def render_payment_sheet(draw, w, h, top_inset):
    draw.rectangle([0, 0, w, h], fill=(15, 23, 42))
    
    sheet_y = top_inset + int(h * 0.14)
    draw.rounded_rectangle([0, sheet_y, w, h], radius=32, fill=(255, 255, 255))
    
    # Handle bar
    draw.rounded_rectangle([(w - 80) // 2, sheet_y + 14, (w + 80) // 2, sheet_y + 20], radius=3, fill=(203, 213, 225))
    
    draw.text((int(w * 0.08), sheet_y + 36), "Collect Rent via UPI", font=get_font(int(h * 0.026), 'bold'), fill=(15, 23, 42))
    draw.text((int(w * 0.08), sheet_y + 78), "Zero gateway fee • Direct bank settlement", font=get_font(int(h * 0.014), 'medium'), fill=(100, 116, 139))

    # Amount Card
    amt_y = sheet_y + int(h * 0.09)
    amt_h = int(h * 0.16)
    draw.rounded_rectangle([int(w * 0.08), amt_y, int(w * 0.92), amt_y + amt_h], radius=16, fill=(239, 246, 255), outline=(191, 219, 254), width=1)
    draw.text((int(w * 0.12), amt_y + 16), "PAYMENT DUE FOR MAY 2026", font=get_font(int(h * 0.013), 'bold'), fill=(37, 99, 235))
    draw.text((int(w * 0.12), amt_y + 50), "₹ 6,500.00", font=get_font(int(h * 0.038), 'bold'), fill=(30, 58, 138))
    draw.text((int(w * 0.12), amt_y + 120), "Tenant: Rahul Sharma (Room 102 - Bed B)", font=get_font(int(h * 0.014), 'medium'), fill=(71, 85, 105))

    # Dynamic QR Code Container
    qr_y = amt_y + amt_h + int(h * 0.025)
    qr_size = int(w * 0.44)
    qr_x = (w - qr_size) // 2
    draw.rounded_rectangle([qr_x, qr_y, qr_x + qr_size, qr_y + qr_size], radius=16, fill=(255, 255, 255), outline=(226, 232, 240), width=2)
    
    # Realistic QR Pattern
    inner_pad = 20
    draw.rectangle([qr_x + inner_pad, qr_y + inner_pad, qr_x + qr_size - inner_pad, qr_y + qr_size - inner_pad], fill=(241, 245, 249))
    
    for mx, my in [(qr_x + 28, qr_y + 28), (qr_x + qr_size - 68, qr_y + 28), (qr_x + 28, qr_y + qr_size - 68)]:
        draw.rectangle([mx, my, mx + 40, my + 40], fill=(15, 23, 42))
        draw.rectangle([mx + 8, my + 8, mx + 32, my + 32], fill=(255, 255, 255))
        draw.rectangle([mx + 14, my + 14, mx + 26, my + 26], fill=(37, 99, 235))
    
    # Additional QR Matrix dots
    for rx in range(4):
        for ry in range(4):
            dx = qr_x + 85 + rx * 24
            dy = qr_y + 85 + ry * 24
            if (rx + ry) % 2 == 0:
                draw.rectangle([dx, dy, dx + 12, dy + 12], fill=(30, 41, 59))
    
    draw.text((qr_x + 36, qr_y + qr_size - 28), "SCAN TO PAY BHAI PG", font=get_font(int(h * 0.011), 'bold'), fill=(100, 116, 139))

    # Direct UPI App buttons
    upi_y = qr_y + qr_size + int(h * 0.035)
    draw.text((int(w * 0.08), upi_y), "Or Pay Directly Via Installed UPI App", font=get_font(int(h * 0.016), 'bold'), fill=(15, 23, 42))
    
    apps = [("Google Pay", (59, 130, 246)), ("PhonePe", (124, 58, 237)), ("Paytm", (14, 165, 233)), ("BHIM UPI", (234, 88, 12))]
    app_btn_w = int(w * 0.40)
    app_btn_h = int(h * 0.055)
    
    btn_start_y = upi_y + int(h * 0.028)
    for i, (name, col) in enumerate(apps):
        bx = int(w * 0.08) if i % 2 == 0 else int(w * 0.52)
        by = btn_start_y + (i // 2) * (app_btn_h + 12)
        draw.rounded_rectangle([bx, by, bx + app_btn_w, by + app_btn_h], radius=12, fill=(248, 250, 252), outline=(226, 232, 240), width=1)
        draw.ellipse([bx + 14, by + 12, bx + 14 + 28, by + 12 + 28], fill=col)
        draw.text((bx + 52, by + 16), name, font=get_font(int(h * 0.015), 'bold'), fill=(30, 41, 59))


def render_rooms_screen(draw, w, h, top_inset):
    draw.rectangle([0, 0, w, h], fill=(248, 250, 252))
    appbar_h = int(h * 0.08)
    draw.rectangle([0, 0, w, top_inset + appbar_h], fill=(37, 99, 235))
    draw.text((int(w * 0.06), top_inset + int(appbar_h * 0.35)), "Room Capacity & Allocation", font=get_font(int(appbar_h * 0.32), 'bold'), fill=(255, 255, 255))

    ban_y = top_inset + appbar_h + int(h * 0.02)
    ban_h = int(h * 0.075)
    draw.rounded_rectangle([int(w * 0.06), ban_y, int(w * 0.94), ban_y + ban_h], radius=14, fill=(236, 253, 245), outline=(16, 185, 129), width=1)
    draw.text((int(w * 0.10), ban_y + 14), "14 Total Rooms • 38 Occupied Beds • 2 Vacant", font=get_font(int(h * 0.016), 'bold'), fill=(5, 150, 105))
    draw.text((int(w * 0.10), ban_y + 40), "Tap any room to view bed slots or check in a guest", font=get_font(int(h * 0.013), 'medium'), fill=(71, 85, 105))

    rooms = [
        ("Room 101 (Triple Sharing)", "Floor 1 • Attached Bath", "3 / 3 Beds Full", "FULL", (239, 68, 68), ["A: Rahul S.", "B: Anand V.", "C: Kevin P."]),
        ("Room 102 (Double Sharing)", "Floor 1 • Balcony View", "1 / 2 Beds (1 Vacant)", "1 VACANT", (16, 185, 129), ["A: Deepak M.", "B: [Available Bed]"]),
        ("Room 201 (Single Deluxe)", "Floor 2 • AC Deluxe", "0 / 1 Bed (Vacant)", "VACANT", (16, 185, 129), ["A: [Available Bed]"]),
        ("Room 202 (Four Sharing)", "Floor 2 • Standard", "4 / 4 Beds Full", "FULL", (239, 68, 68), ["A: Imran K.", "B: Suresh T.", "C: Danish R.", "D: Amit N."])
    ]
    card_y = ban_y + ban_h + int(h * 0.02)
    for title, subtitle, cap, status, st_col, beds in rooms:
        ch = int(h * 0.14)
        draw.rounded_rectangle([int(w * 0.06), card_y, int(w * 0.94), card_y + ch], radius=16, fill=(255, 255, 255), outline=(226, 232, 240), width=1)
        draw.text((int(w * 0.10), card_y + 14), title, font=get_font(int(h * 0.017), 'bold'), fill=(15, 23, 42))
        draw.text((int(w * 0.10), card_y + 44), subtitle, font=get_font(int(h * 0.013), 'medium'), fill=(100, 116, 139))
        
        draw.rounded_rectangle([int(w * 0.74), card_y + 14, int(w * 0.90), card_y + 38], radius=6, fill=st_col)
        draw.text((int(w * 0.76), card_y + 18), status, font=get_font(int(h * 0.011), 'bold'), fill=(255, 255, 255))
        
        pill_y = card_y + int(h * 0.075)
        px = int(w * 0.10)
        for bed in beds:
            bg_col = (241, 245, 249) if "Available" not in bed else (236, 253, 245)
            txt_col = (51, 65, 85) if "Available" not in bed else (5, 150, 105)
            bw = int(len(bed) * w * 0.018) + 16
            draw.rounded_rectangle([px, pill_y, px + bw, pill_y + 26], radius=6, fill=bg_col)
            draw.text((px + 8, pill_y + 5), bed, font=get_font(int(h * 0.011), 'medium'), fill=txt_col)
            px += bw + 8
        card_y += ch + int(h * 0.016)


def render_police_report(draw, w, h, top_inset):
    draw.rectangle([0, 0, w, h], fill=(248, 250, 252))
    appbar_h = int(h * 0.08)
    draw.rectangle([0, 0, w, top_inset + appbar_h], fill=(37, 99, 235))
    draw.text((int(w * 0.06), top_inset + int(appbar_h * 0.35)), "Police Verification Report", font=get_font(int(appbar_h * 0.32), 'bold'), fill=(255, 255, 255))

    doc_y = top_inset + appbar_h + int(h * 0.02)
    doc_h = int(h * 0.65)
    draw.rounded_rectangle([int(w * 0.06), doc_y, int(w * 0.94), doc_y + doc_h], radius=12, fill=(255, 255, 255), outline=(203, 213, 225), width=2)
    
    draw.text((int(w * 0.16), doc_y + 20), "OFFICIAL TENANT / GUEST VERIFICATION RECORD", font=get_font(int(h * 0.013), 'bold'), fill=(15, 23, 42))
    draw.text((int(w * 0.24), doc_y + 44), "Submitted Under State Police Circular 2026", font=get_font(int(h * 0.012), 'medium'), fill=(71, 85, 105))
    draw.line([(int(w * 0.10), doc_y + 68), (int(w * 0.90), doc_y + 68)], fill=(30, 41, 59), width=1)

    rows = [
        ("Full Name of Tenant:", "Mohammed Zeeshan"),
        ("Father's Name:", "Abdul Hameed"),
        ("Aadhaar Number:", "XXXX-XXXX-4091 (Verified)"),
        ("Mobile Number:", "+91 99450 18320"),
        ("Police Station Circle:", "Kadavanthra PS, Kochi"),
        ("Permanent Address:", "Calicut, Kerala - 673004"),
        ("Property / PG:", "Green Valley PG (Room 105)"),
        ("Check-In Date:", "01 November 2026"),
        ("Authorized Owner:", "Mubarak Tech Accommodations")
    ]
    dy = doc_y + 84
    for lbl, val in rows:
        draw.text((int(w * 0.10), dy), lbl, font=get_font(int(h * 0.013), 'bold'), fill=(51, 65, 85))
        draw.text((int(w * 0.48), dy), val, font=get_font(int(h * 0.013), 'medium'), fill=(15, 23, 42))
        dy += int(h * 0.040)

    stamp_y = doc_y + doc_h - int(h * 0.14)
    draw.rectangle([int(w * 0.68), stamp_y, int(w * 0.88), stamp_y + int(h * 0.11)], fill=(248, 250, 252), outline=(148, 163, 184), width=1)
    draw.text((int(w * 0.72), stamp_y + 35), "PHOTO", font=get_font(int(h * 0.013), 'bold'), fill=(148, 163, 184))

    draw.ellipse([int(w * 0.14), stamp_y + 10, int(w * 0.14) + 80, stamp_y + 90], outline=(37, 99, 235), width=2)
    draw.text((int(w * 0.165), stamp_y + 35), "VERIFIED", font=get_font(int(h * 0.011), 'bold'), fill=(37, 99, 235))

    btn_y = doc_y + doc_h + int(h * 0.02)
    draw.rounded_rectangle([int(w * 0.06), btn_y, int(w * 0.94), btn_y + int(h * 0.065)], radius=14, fill=(37, 99, 235))
    draw.text((int(w * 0.28), btn_y + 16), "Export Official PDF (Share / Print)", font=get_font(int(h * 0.017), 'bold'), fill=(255, 255, 255))


def render_analytics_screen(draw, w, h, top_inset):
    draw.rectangle([0, 0, w, h], fill=(248, 250, 252))
    appbar_h = int(h * 0.08)
    draw.rectangle([0, 0, w, top_inset + appbar_h], fill=(37, 99, 235))
    draw.text((int(w * 0.06), top_inset + int(appbar_h * 0.35)), "Revenue & Financial Analytics", font=get_font(int(appbar_h * 0.32), 'bold'), fill=(255, 255, 255))

    rev_y = top_inset + appbar_h + int(h * 0.02)
    rev_h = int(h * 0.16)
    draw.rounded_rectangle([int(w * 0.06), rev_y, int(w * 0.94), rev_y + rev_h], radius=16, fill=(30, 58, 138))
    draw.text((int(w * 0.10), rev_y + 18), "OCTOBER 2026 TOTAL REVENUE", font=get_font(int(h * 0.013), 'bold'), fill=(191, 219, 254))
    draw.text((int(w * 0.10), rev_y + 52), "₹ 2,47,000", font=get_font(int(h * 0.038), 'bold'), fill=(255, 255, 255))
    draw.text((int(w * 0.10), rev_y + 118), "+14% higher than September • 98% Collection rate", font=get_font(int(h * 0.013), 'medium'), fill=(147, 197, 253))

    chart_y = rev_y + rev_h + int(h * 0.025)
    chart_h = int(h * 0.21)
    draw.rounded_rectangle([int(w * 0.06), chart_y, int(w * 0.94), chart_y + chart_h], radius=16, fill=(255, 255, 255), outline=(226, 232, 240), width=1)
    draw.text((int(w * 0.10), chart_y + 16), "Monthly Collection Breakdown", font=get_font(int(h * 0.016), 'bold'), fill=(15, 23, 42))
    
    months = [("Jun", 0.65), ("Jul", 0.72), ("Aug", 0.80), ("Sep", 0.88), ("Oct", 0.98), ("Nov (Est)", 0.92)]
    bw = int(w * 0.08)
    base_line = chart_y + chart_h - 40
    max_bar_h = int(chart_h * 0.54)
    
    for i, (m, ratio) in enumerate(months):
        bx = int(w * 0.12) + i * int(w * 0.13)
        bh = int(max_bar_h * ratio)
        col = (37, 99, 235) if i == 4 else (147, 197, 253)
        draw.rounded_rectangle([bx, base_line - bh, bx + bw, base_line], radius=6, fill=col)
        draw.text((bx + 2, base_line + 8), m, font=get_font(int(h * 0.011), 'bold'), fill=(100, 116, 139))

    log_y = chart_y + chart_h + int(h * 0.025)
    draw.text((int(w * 0.06), log_y), "Recent Collections (Zero Fee)", font=get_font(int(h * 0.018), 'bold'), fill=(15, 23, 42))

    log_items = [
        ("Rahul Sharma", "₹ 6,500", "Google Pay UPI • Ref #8920", "28 Oct 2026"),
        ("Deepak Patel", "₹ 6,500", "PhonePe UPI • Ref #4419", "27 Oct 2026"),
        ("Imran Khan", "₹ 4,000", "Paytm UPI • Ref #1029", "26 Oct 2026")
    ]
    ly = log_y + int(h * 0.034)
    for name, amt, ref, dt in log_items:
        draw.rounded_rectangle([int(w * 0.06), ly, int(w * 0.94), ly + int(h * 0.072)], radius=12, fill=(255, 255, 255), outline=(226, 232, 240), width=1)
        draw.text((int(w * 0.10), ly + 14), name, font=get_font(int(h * 0.016), 'bold'), fill=(15, 23, 42))
        draw.text((int(w * 0.10), ly + 40), f"{ref} • {dt}", font=get_font(int(h * 0.012), 'medium'), fill=(100, 116, 139))
        draw.text((int(w * 0.74), ly + 22), amt, font=get_font(int(h * 0.020), 'bold'), fill=(16, 185, 129))
        ly += int(h * 0.084)


# --- Master Slide Builder ---

SLIDES = [
    {
        "tag": "COMPLETE PG & ROOM RENTAL SOLUTION",
        "title": "Smart PG & Property\nManagement",
        "subtitle": "Real-time occupancy tracking, bed slots & active tenant records",
        "renderer": render_dashboard
    },
    {
        "tag": "GOVT COMPLIANCE & VERIFICATION",
        "title": "Instant Tenant &\nAadhaar Verification",
        "subtitle": "Secure document storage, identity lightbox & compliance tracking",
        "renderer": render_guest_profile
    },
    {
        "tag": "ZERO COMMISSION RENT COLLECTION",
        "title": "Automated Due Tracking\n& Direct UPI Payments",
        "subtitle": "Collect rent instantly with dynamic QR codes & instant receipts",
        "renderer": render_payment_sheet
    },
    {
        "tag": "LIVE CAPACITY MONITORING",
        "title": "Visual Room & Bed\nCapacity Allocation",
        "subtitle": "Monitor occupied beds, vacancies & quick check-ins across properties",
        "renderer": render_rooms_screen
    },
    {
        "tag": "OFFICIAL POLICE COMPLIANCE",
        "title": "One-Tap Official\nPolice Verification PDF",
        "subtitle": "Export compliant verification reports ready for local police stations",
        "renderer": render_police_report
    },
    {
        "tag": "COLLECTION & REVENUE ANALYTICS",
        "title": "Comprehensive Financial\n& Revenue Analytics",
        "subtitle": "Track monthly collection growth, overdue balances & payment histories",
        "renderer": render_analytics_screen
    }
]

def build_slide(slide_info, width, height, is_ios=False):
    img = Image.new('RGB', (width, height), (15, 23, 42))
    draw = ImageDraw.Draw(img)

    draw_gradient(draw, width, height, (15, 23, 42), (30, 41, 59))

    glow_w = int(width * 0.8)
    glow_img = Image.new('RGBA', (glow_w, glow_w), (0, 0, 0, 0))
    glow_draw = ImageDraw.Draw(glow_img)
    glow_draw.ellipse([0, 0, glow_w, glow_w], fill=(37, 99, 235, 45))
    glow_img = glow_img.filter(ImageFilter.GaussianBlur(80))
    img.paste(glow_img, ((width - glow_w)//2, -100), mask=glow_img)

    top_margin = int(height * 0.055)
    f_tag = get_font(int(height * 0.013), 'bold')
    draw.text((int(width * 0.08), top_margin), slide_info["tag"], font=f_tag, fill=(96, 165, 250))

    f_title = get_font(int(height * 0.038), 'bold')
    title_y = top_margin + int(height * 0.024)
    draw.text((int(width * 0.08), title_y), slide_info["title"], font=f_title, fill=(255, 255, 255), spacing=int(height * 0.008))

    lines_in_title = slide_info["title"].count('\n') + 1
    sub_y = title_y + lines_in_title * int(height * 0.046) + int(height * 0.005)
    f_sub = get_font(int(height * 0.016), 'medium')
    draw.text((int(width * 0.08), sub_y), slide_info["subtitle"], font=f_sub, fill=(148, 163, 184))

    phone_w = int(width * 0.84)
    phone_h = int(height * 0.76)
    phone_x = (width - phone_w) // 2
    phone_y = sub_y + int(height * 0.038)

    draw_device_mockup(img, phone_x, phone_y, phone_w, phone_h, slide_info["renderer"])

    return img


def main():
    print("Generating Store Marketing Screenshots...")
    out_play = "store_assets/play_store"
    out_ios = "store_assets/app_store"
    os.makedirs(out_play, exist_ok=True)
    os.makedirs(out_ios, exist_ok=True)

    for i, slide in enumerate(SLIDES):
        num = i + 1
        print(f"Rendering Slide {num}: {slide['tag']}...")
        
        # 1. Google Play Store (1080 x 1920)
        img_play = build_slide(slide, PLAY_W, PLAY_H, is_ios=False)
        play_path = f"{out_play}/screenshot_{num}.png"
        img_play.save(play_path, format="PNG", optimize=True)

        # 2. Apple App Store (1290 x 2796)
        img_ios = build_slide(slide, IOS_W, IOS_H, is_ios=True)
        ios_path = f"{out_ios}/screenshot_{num}.png"
        img_ios.save(ios_path, format="PNG", optimize=True)

    print(f"\n✓ Generated {len(SLIDES)} Google Play screenshots at: {out_play}")
    print(f"✓ Generated {len(SLIDES)} Apple App Store screenshots at: {out_ios}")


if __name__ == "__main__":
    main()
