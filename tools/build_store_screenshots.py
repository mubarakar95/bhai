#!/usr/bin/env python3
"""
Professional App Store and Google Play Store Screenshot Builder
Uses REAL simulator captures from Bhai App running on iPhone 17 Simulator.
Produces:
1. Framed marketing screenshot suites with feature highlights.
2. Direct 1:1 full-screen captures sized to store specifications.
"""

import os
from PIL import Image, ImageDraw, ImageFont, ImageFilter

RAW_DIR = "store_assets/simulator_raw"
PLAY_DIR = "store_assets/play_store"
IOS_DIR = "store_assets/app_store"

os.makedirs(PLAY_DIR, exist_ok=True)
os.makedirs(IOS_DIR, exist_ok=True)
os.makedirs(f"{PLAY_DIR}/raw", exist_ok=True)
os.makedirs(f"{IOS_DIR}/raw_6.7", exist_ok=True)
os.makedirs(f"{IOS_DIR}/raw_6.9", exist_ok=True)

# Screens specification
SCREENS = [
    {
        "file": "01_dashboard.png",
        "tag": "ALL-IN-ONE PG MANAGEMENT",
        "title": "Real-Time Occupancy & Rent Tracking",
        "subtitle": "Instant overview of bed availability, check-ins, and collections",
        "accent": (13, 148, 136), # Teal
    },
    {
        "file": "02_guests.png",
        "tag": "TENANT DIRECTORY & KYC",
        "title": "Aadhaar Verified Guest Records",
        "subtitle": "Complete KYC, police circle tags, and blacklist protection",
        "accent": (37, 99, 235), # Blue
    },
    {
        "file": "03_rooms.png",
        "tag": "PROPERTY & ROOM MATRIX",
        "title": "Smart Bed & Room Allocation",
        "subtitle": "Manage capacities, tariffs, and live vacancy status per room",
        "accent": (124, 58, 237), # Purple
    },
    {
        "file": "04_police_reports.png",
        "tag": "POLICE VERIFICATION REPORTS",
        "title": "One-Click Official Form 2 & Ledgers",
        "subtitle": "Generate and print verified guest ledgers for local authorities",
        "accent": (217, 119, 6), # Amber
    },
    {
        "file": "05_payments.png",
        "tag": "RENT & UPI ACCOUNTING",
        "title": "Automated Rent & Payment Ledger",
        "subtitle": "Record UPI deposits, advances, dues, and transaction histories",
        "accent": (16, 185, 129), # Emerald
    },
]

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

def build_direct_raw(raw_path, target_w, target_h, out_path):
    """Creates direct pixel-perfect full-screen capture for store requirements."""
    im = Image.open(raw_path).convert('RGB')
    resized = im.resize((target_w, target_h), Image.Resampling.LANCZOS)
    resized.save(out_path, format='PNG', optimize=True)

def build_framed_screenshot(info, target_w, target_h, is_play_store=False):
    """
    Renders real screenshot inside a refined device mockup with marketing headlines.
    """
    base = Image.new('RGB', (target_w, target_h), (15, 23, 42))
    draw = ImageDraw.Draw(base)

    # 1. Background gradient (Deep slate to obsidian)
    start_c = (15, 23, 42)
    end_c = (10, 15, 29)
    draw_gradient(draw, target_w, target_h, start_c, end_c)

    # Subtle ambient glow in accent color at the top center
    glow_size = int(target_w * 0.8)
    glow_img = Image.new('RGBA', (glow_size, glow_size), (0, 0, 0, 0))
    glow_draw = ImageDraw.Draw(glow_img)
    glow_draw.ellipse([0, 0, glow_size, glow_size], fill=(*info['accent'], 35))
    glow_img = glow_img.filter(ImageFilter.GaussianBlur(int(glow_size * 0.35)))
    base.paste(glow_img, ((target_w - glow_size) // 2, -int(glow_size * 0.2)), mask=glow_img)

    # 2. Typography Header
    top_margin = int(target_h * 0.045)
    
    # Tag Pill
    tag_font = get_font(int(target_w * 0.026), 'bold')
    tag_text = info['tag']
    tag_bbox = draw.textbbox((0, 0), tag_text, font=tag_font)
    tag_w = tag_bbox[2] - tag_bbox[0]
    tag_h = tag_bbox[3] - tag_bbox[1]
    
    pill_pad_x = int(target_w * 0.035)
    pill_pad_y = int(target_h * 0.007)
    pill_w = tag_w + pill_pad_x * 2
    pill_h = tag_h + pill_pad_y * 2
    pill_x = (target_w - pill_w) // 2
    pill_y = top_margin

    draw.rounded_rectangle(
        [pill_x, pill_y, pill_x + pill_w, pill_y + pill_h],
        radius=pill_h // 2,
        fill=(*info['accent'], 45),
        outline=(*info['accent'], 180),
        width=2
    )
    draw.text((pill_x + pill_pad_x, pill_y + pill_pad_y - 2), tag_text, font=tag_font, fill=(240, 253, 250))

    # Main Title
    title_font = get_font(int(target_w * 0.052), 'bold')
    title_text = info['title']
    title_bbox = draw.textbbox((0, 0), title_text, font=title_font)
    title_w = title_bbox[2] - title_bbox[0]
    title_y = pill_y + pill_h + int(target_h * 0.016)
    draw.text(((target_w - title_w) // 2, title_y), title_text, font=title_font, fill=(255, 255, 255))

    # Subtitle
    sub_font = get_font(int(target_w * 0.032), 'medium')
    sub_text = info['subtitle']
    sub_bbox = draw.textbbox((0, 0), sub_text, font=sub_font)
    sub_w = sub_bbox[2] - sub_bbox[0]
    sub_y = title_y + (title_bbox[3] - title_bbox[1]) + int(target_h * 0.010)
    draw.text(((target_w - sub_w) // 2, sub_y), sub_text, font=sub_font, fill=(148, 163, 184))

    # 3. Device Mockup with REAL Screen
    device_y = sub_y + (sub_bbox[3] - sub_bbox[1]) + int(target_h * 0.032)
    device_w = int(target_w * 0.86)
    device_h = int(target_h - device_y + int(target_h * 0.08)) # extend slightly below viewport for bleed effect
    screen_corner = int(device_w * 0.09)

    # Load real screenshot
    raw_path = os.path.join(RAW_DIR, info['file'])
    real_screen = Image.open(raw_path).convert('RGBA')
    screen_scaled = real_screen.resize((device_w, int(device_w * (real_screen.height / real_screen.width))), Image.Resampling.LANCZOS)
    
    # Clip to device screen height
    cropped_screen = screen_scaled.crop((0, 0, device_w, device_h))

    # Rounded mask for screen
    mask = Image.new('L', (device_w, device_h), 0)
    mask_draw = ImageDraw.Draw(mask)
    mask_draw.rounded_rectangle([0, 0, device_w, device_h], radius=screen_corner, fill=255)

    # Outer bezel & shadow
    bezel_pad = int(device_w * 0.022)
    outer_w = device_w + bezel_pad * 2
    outer_h = device_h + bezel_pad * 2

    shadow_img = Image.new('RGBA', (outer_w + 80, outer_h + 100), (0, 0, 0, 0))
    shadow_draw = ImageDraw.Draw(shadow_img)
    shadow_draw.rounded_rectangle([40, 50, outer_w + 40, outer_h + 50], radius=screen_corner + bezel_pad, fill=(0, 0, 0, 140))
    shadow_img = shadow_img.filter(ImageFilter.GaussianBlur(32))

    device_frame = Image.new('RGBA', (outer_w, outer_h), (0, 0, 0, 0))
    frame_draw = ImageDraw.Draw(device_frame)
    frame_draw.rounded_rectangle(
        [0, 0, outer_w, outer_h],
        radius=screen_corner + bezel_pad,
        fill=(15, 23, 42, 255),
        outline=(51, 65, 85, 255),
        width=bezel_pad
    )

    device_frame.paste(cropped_screen, (bezel_pad, bezel_pad), mask=mask)

    device_x = (target_w - outer_w) // 2
    base.paste(shadow_img, (device_x - 40, device_y - 30), mask=shadow_img)
    base.paste(device_frame, (device_x, device_y), mask=device_frame)

    return base

def main():
    print("Generating Store Screenshot Previews with REAL simulator captures...")

    for i, info in enumerate(SCREENS, 1):
        raw_path = os.path.join(RAW_DIR, info['file'])
        
        # 1. Direct raw captures (for standard 1:1 submission)
        # Google Play: 1080 x 2400
        build_direct_raw(raw_path, 1080, 2400, f"{PLAY_DIR}/raw/screenshot_{i}.png")
        # App Store 6.7": 1290 x 2796
        build_direct_raw(raw_path, 1290, 2796, f"{IOS_DIR}/raw_6.7/screenshot_{i}.png")
        # App Store 6.9": 1320 x 2868
        build_direct_raw(raw_path, 1320, 2868, f"{IOS_DIR}/raw_6.9/screenshot_{i}.png")

        # 2. Branded Marketing Showcase Cards (High conversion)
        # Google Play: 1080 x 2400
        play_card = build_framed_screenshot(info, 1080, 2400, is_play_store=True)
        play_out = f"{PLAY_DIR}/screenshot_{i}.png"
        play_card.save(play_out, format='PNG', optimize=True)

        # App Store 6.7": 1290 x 2796
        ios_card_67 = build_framed_screenshot(info, 1290, 2796, is_play_store=False)
        ios_out_67 = f"{IOS_DIR}/screenshot_{i}.png"
        ios_card_67.save(ios_out_67, format='PNG', optimize=True)

        print(f"[{i}/5] Completed {info['title']}")

    print("\nAll Play Store & App Store screenshot previews successfully generated!")

if __name__ == '__main__':
    main()
