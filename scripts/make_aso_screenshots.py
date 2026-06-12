#!/usr/bin/env python3
"""
VetMap ASO Screenshot Generator
================================
Applies benefit-driven text overlays to raw simulator screenshots
following the ASO Screenshot Optimization framework.

Output: 6.7" (1290x2796) App Store ready PNGs with:
- Gradient header area with headline text
- Device screenshot below
- Consistent warm amber brand colors
"""

from PIL import Image, ImageDraw, ImageFont, ImageFilter
from pathlib import Path
import textwrap

# Paths
PROJECT = Path("/Users/sunnyyylai/Documents/VetMap")
SCREENSHOTS_DIR = PROJECT / "screenshots"
OUTPUT_DIR = PROJECT / "aso-screenshots"
OUTPUT_DIR.mkdir(exist_ok=True)

# ASO Screenshot Plan (based on Screenshot Optimization Skill framework)
# Slot 1: Hook — "What does this app do and why should I care?"
# Slot 2-3: Core Value
# Slot 4-6: Feature Showcase
SCREENSHOT_PLAN = [
    {
        "file": "MAP.png",
        "headline": "222間獸醫診所\n一圖盡覽",
        "subline": "台灣 + 香港 · 即時距離 · 一鍵導航",
        "output": "01_hook_map.png",
    },
    {
        "file": "Clinic List.png",
        "headline": "搜尋篩選\n精準搵診所",
        "subline": "地區 · 價格 · 已驗證 · 關鍵字搜尋",
        "output": "02_search_filter.png",
    },
    {
        "file": "Shops.png",
        "headline": "寵物商戶\n一站瀏覽",
        "subline": "美容 · 善終 · 用品 · 香港台灣覆蓋",
        "output": "03_products.png",
    },
    {
        "file": "Insurance.png",
        "headline": "寵物保險\n輕鬆比較",
        "subline": "6 間保險計劃 · 保費 · 保障範圍",
        "output": "04_insurance.png",
    },
    # 待補：Clinic Detail（真實評價/費用透明）+ Premium（會員解鎖）
]

# Design constants — Warm Clinical brand
CANVAS_W = 1290  # 6.7" width
CANVAS_H = 2796  # 6.7" height
HEADER_H = 680   # top gradient area for text
WARM_AMBER = (232, 168, 56)  # #E8A838
WARM_CREAM = (250, 245, 235)  # warm cream background
DARK_TEXT = (56, 46, 30)  # dark brown
LIGHT_TEXT = (255, 255, 255)


def find_font(size: int, bold: bool = True) -> ImageFont.FreeTypeFont:
    """Find a suitable CJK font for Chinese text."""
    # RoundedMplus1c 係日文字型，缺繁中 glyph（獸/圖/覽 等會消失）— 用 Heiti TC
    candidates = [
        "/System/Library/Fonts/STHeiti Medium.ttc" if bold
        else "/System/Library/Fonts/STHeiti Light.ttc",
        "/System/Library/Fonts/Supplemental/Arial Unicode.ttf",
    ]
    for path in candidates:
        try:
            return ImageFont.truetype(path, size)
        except (OSError, IOError):
            continue
    return ImageFont.load_default()


def create_aso_screenshot(plan: dict):
    """Create a single ASO-optimized screenshot."""
    src_path = SCREENSHOTS_DIR / plan["file"]
    if not src_path.exists():
        print(f"  ⚠️  Missing: {src_path}")
        return

    # Load source screenshot
    src = Image.open(src_path)

    # Create canvas
    canvas = Image.new("RGB", (CANVAS_W, CANVAS_H), WARM_CREAM)
    draw = ImageDraw.Draw(canvas)

    # Draw gradient header (warm amber → cream)
    for y in range(HEADER_H):
        ratio = y / HEADER_H
        # Gradient from amber at top to cream at bottom
        r = int(WARM_AMBER[0] * (1 - ratio) + WARM_CREAM[0] * ratio)
        g = int(WARM_AMBER[1] * (1 - ratio) + WARM_CREAM[1] * ratio)
        b = int(WARM_AMBER[2] * (1 - ratio) + WARM_CREAM[2] * ratio)
        draw.line([(0, y), (CANVAS_W, y)], fill=(r, g, b))

    # Draw headline text
    headline_font = find_font(88, bold=True)
    subline_font = find_font(42, bold=False)

    # Headline — centered, white text with shadow
    headline_lines = plan["headline"].split("\n")
    y_text = 160
    for line in headline_lines:
        bbox = draw.textbbox((0, 0), line, font=headline_font)
        tw = bbox[2] - bbox[0]
        x = (CANVAS_W - tw) // 2
        # Shadow
        draw.text((x + 3, y_text + 3), line, fill=(0, 0, 0, 60), font=headline_font)
        # Main text
        draw.text((x, y_text), line, fill=LIGHT_TEXT, font=headline_font)
        y_text += 110

    # Subline
    subline = plan["subline"]
    bbox = draw.textbbox((0, 0), subline, font=subline_font)
    tw = bbox[2] - bbox[0]
    x = (CANVAS_W - tw) // 2
    draw.text((x, y_text + 30), subline, fill=(125, 92, 40), font=subline_font)

    # Place screenshot below header with rounded corners and shadow
    # Scale screenshot to fit canvas width with padding
    padding = 60
    target_w = CANVAS_W - (padding * 2)
    scale = target_w / src.width
    target_h = int(src.height * scale)
    screenshot_resized = src.resize((target_w, target_h), Image.LANCZOS)

    # Add rounded corners to screenshot
    corner_radius = 40
    mask = Image.new("L", (target_w, target_h), 0)
    mask_draw = ImageDraw.Draw(mask)
    mask_draw.rounded_rectangle(
        [(0, 0), (target_w, target_h)],
        radius=corner_radius,
        fill=255,
    )

    # Paste screenshot with mask
    y_offset = HEADER_H + 30
    canvas.paste(screenshot_resized, (padding, y_offset), mask)

    # Draw thin border around screenshot
    border_draw = ImageDraw.Draw(canvas)
    border_draw.rounded_rectangle(
        [(padding, y_offset), (padding + target_w, y_offset + target_h)],
        radius=corner_radius,
        outline=(200, 180, 140),
        width=3,
    )

    # Save
    out_path = OUTPUT_DIR / plan["output"]
    canvas.save(out_path, "PNG", optimize=True)
    print(f"  ✅ {out_path.name} ({canvas.size[0]}x{canvas.size[1]})")


def main():
    print("🎨 VetMap ASO Screenshot Generator")
    print(f"   Output: {OUTPUT_DIR}")
    print(f"   Canvas: {CANVAS_W}x{CANVAS_H} (6.7\" iPhone)")
    print()

    for i, plan in enumerate(SCREENSHOT_PLAN, 1):
        print(f"[{i}/{len(SCREENSHOT_PLAN)}] {plan['headline'].split(chr(10))[0]}...")
        create_aso_screenshot(plan)

    print()
    print(f"✅ Done! {len(list(OUTPUT_DIR.glob('*.png')))} screenshots in {OUTPUT_DIR}")


if __name__ == "__main__":
    main()
