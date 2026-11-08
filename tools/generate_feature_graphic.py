#!/usr/bin/env python3
"""
Generate Google Play Store Feature Graphic (1024 x 500)
Follows Google Play Console store listing specifications.
"""

import os
from PIL import Image, ImageDraw, ImageFont, ImageFilter

W, H = 1024, 500
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

def main():
    img = Image.new('RGB', (W, H), (15, 23, 42))
    draw = ImageDraw.Draw(img)

    # 1. Background gradient
    draw_gradient(draw, W, H, (15, 23, 42), (8, 12, 22))

    # 2. Aurora glow beams
    glow = Image.new('RGBA', (600, 600), (0, 0, 0, 0))
    g_draw = ImageDraw.Draw(glow)
    g_draw.ellipse([50, 50, 550, 550], fill=(13, 148, 136, 45)) # Teal glow
    glow = glow.filter(ImageFilter.GaussianBlur(80))
    img.paste(glow, (-100, -150), mask=glow)

    glow2 = Image.new('RGBA', (600, 600), (0, 0, 0, 0))
    g_draw2 = ImageDraw.Draw(glow2)
    g_draw2.ellipse([50, 50, 550, 550], fill=(99, 102, 241, 35)) # Indigo glow
    glow2 = glow2.filter(ImageFilter.GaussianBlur(90))
    img.paste(glow2, (500, -100), mask=glow2)

    # 3. App Icon
    icon_path = 'macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_1024.png'
    if os.path.exists(icon_path):
        icon = Image.open(icon_path).convert('RGBA')
        icon_size = 110
        icon = icon.resize((icon_size, icon_size), Image.Resampling.LANCZOS)
        
        # Rounded mask for icon
        icon_mask = Image.new('L', (icon_size, icon_size), 0)
        im_draw = ImageDraw.Draw(icon_mask)
        im_draw.rounded_rectangle([0, 0, icon_size, icon_size], radius=24, fill=255)
        
        # Icon shadow
        icon_shadow = Image.new('RGBA', (icon_size + 24, icon_size + 24), (0, 0, 0, 0))
        is_draw = ImageDraw.Draw(icon_shadow)
        is_draw.rounded_rectangle([6, 6, icon_size + 18, icon_size + 18], radius=24, fill=(0, 0, 0, 120))
        icon_shadow = icon_shadow.filter(ImageFilter.GaussianBlur(10))

        icon_x = 70
        icon_y = 65
        img.paste(icon_shadow, (icon_x - 12, icon_y - 8), mask=icon_shadow)
        img.paste(icon, (icon_x, icon_y), mask=icon_mask)

    # 4. Brand Typography
    f_title = get_font(48, 'bold')
    f_tag = get_font(18, 'bold')
    f_sub = get_font(22, 'medium')
    f_pills = get_font(13, 'bold')

    # Eyebrow Pill
    eyebrow = "SMART PROPERTY & PG SUITE"
    eb_bbox = draw.textbbox((0, 0), eyebrow, font=f_pills)
    eb_w = eb_bbox[2] - eb_bbox[0]
    draw.rounded_rectangle([205, 65, 205 + eb_w + 24, 65 + 26], radius=13, fill=(13, 148, 136, 60), outline=(13, 148, 136, 180), width=1)
    draw.text((217, 70), eyebrow, font=f_pills, fill=(204, 251, 241))

    # App Title
    draw.text((205, 100), "Bhai App", font=f_title, fill=(255, 255, 255))

    # Subtitle
    draw.text((70, 205), "All-in-One PG, Hostel & Camp Management", font=f_sub, fill=(226, 232, 240))

    # Bullets / Badges
    features = [
        "✓ Real-Time Occupancy & Rooms",
        "✓ Aadhaar KYC & Tenant Records",
        "✓ Police Verification Form 2",
        "✓ Instant UPI Rent Collection"
    ]
    f_bullet = get_font(15, 'medium')
    for idx, feat in enumerate(features):
        by = 260 + (idx * 34)
        draw.text((70, by), feat, font=f_bullet, fill=(148, 163, 184))

    # 5. Right-side Device Mockup Card
    screen_path = 'store_assets/simulator_raw/01_dashboard.png'
    if os.path.exists(screen_path):
        screen = Image.open(screen_path).convert('RGBA')
        card_w = 340
        card_h = int(card_w * (screen.height / screen.width))
        screen_scaled = screen.resize((card_w, card_h), Image.Resampling.LANCZOS)
        
        # Crop upper portion
        crop_h = 420
        screen_cropped = screen_scaled.crop((0, 0, card_w, crop_h))

        # Device frame & mask
        mask = Image.new('L', (card_w, crop_h), 0)
        m_draw = ImageDraw.Draw(mask)
        m_draw.rounded_rectangle([0, 0, card_w, crop_h], radius=32, fill=255)

        # Shadow
        dev_shadow = Image.new('RGBA', (card_w + 60, crop_h + 60), (0, 0, 0, 0))
        ds_draw = ImageDraw.Draw(dev_shadow)
        ds_draw.rounded_rectangle([20, 25, card_w + 40, crop_h + 45], radius=32, fill=(0, 0, 0, 180))
        dev_shadow = dev_shadow.filter(ImageFilter.GaussianBlur(25))

        dev_x = 610
        dev_y = 55
        img.paste(dev_shadow, (dev_x - 30, dev_y - 20), mask=dev_shadow)
        
        # Border
        frame = Image.new('RGBA', (card_w + 12, crop_h + 12), (0, 0, 0, 0))
        f_draw = ImageDraw.Draw(frame)
        f_draw.rounded_rectangle([0, 0, card_w + 12, crop_h + 12], radius=36, fill=(30, 41, 59, 255), outline=(71, 85, 105, 255), width=6)
        frame.paste(screen_cropped, (6, 6), mask=mask)
        img.paste(frame, (dev_x - 6, dev_y - 6), mask=frame)

    out_path = 'store_assets/play_store/feature_graphic.png'
    img.save(out_path, format='PNG', optimize=True)
    print(f"Feature graphic successfully created at {out_path} ({W}x{H})!")

if __name__ == '__main__':
    main()
