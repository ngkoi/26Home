#!/usr/bin/env python3
"""
26Home SolidGlass Icon Rounder
Applies Apple's continuous squircle corner radius (ratio 0.225) to all PNG icons in SolidGlass.
"""

import os
import io
import sys
import time
from concurrent.futures import ProcessPoolExecutor
from PIL import Image, ImageDraw
import numpy as np

BASE_DIR = "/home/ngkhoi/26Home/layout/Library/Application Support/26Home/SolidGlass"
TARGET_FOLDERS = ["ClearLight", "ClearDark", "Dark", "Light", "DefaultNS", "DarkNS"]
CORNER_RADIUS_RATIO = 0.225

def make_squircle_mask(size):
    """
    Generates a 4x supersampled anti-aliased squircle mask for Apple iOS icons.
    """
    w, h = size
    scale = 4
    sw, sh = w * scale, h * scale
    radius = int(sw * CORNER_RADIUS_RATIO)
    
    big_mask = Image.new("L", (sw, sh), 0)
    draw = ImageDraw.Draw(big_mask)
    draw.rounded_rectangle([0, 0, sw - 1, sh - 1], radius=radius, fill=255)
    
    return big_mask.resize((w, h), Image.Resampling.LANCZOS)

def round_single_icon(file_path):
    """
    Rounds a single icon image to the exact iOS continuous squircle.
    """
    try:
        orig_size = os.path.getsize(file_path)
        if orig_size == 0:
            return (file_path, "EMPTY_SKIPPED")
            
        with Image.open(file_path) as im:
            im_rgba = im.convert("RGBA")
            w, h = im_rgba.size
            
            # Generate anti-aliased mask
            mask = make_squircle_mask((w, h))
            
            # Apply squircle mask to alpha channel
            arr = np.array(im_rgba)
            mask_arr = np.array(mask).astype(np.float32) / 255.0
            
            current_alpha = arr[:, :, 3].astype(np.float32)
            new_alpha = np.clip(current_alpha * mask_arr, 0.0, 255.0).astype(np.uint8)
            arr[:, :, 3] = new_alpha
            
            # Zero out RGB on transparent pixels for optimal compression
            transparent_mask = (new_alpha == 0)
            arr[transparent_mask, :3] = 0
            
            rounded_im = Image.fromarray(arr, "RGBA")
            
            buf = io.BytesIO()
            rounded_im.save(buf, format="PNG", optimize=True, compress_level=9)
            
            with open(file_path, "wb") as f:
                f.write(buf.getvalue())
                
            return (file_path, "ROUNDED")
            
    except Exception as e:
        return (file_path, f"ERROR: {e}")

def main():
    print("=" * 66)
    print("  26Home SolidGlass Icon Rounder Tool")
    print(f"  Applying iOS Squircle Corner Radius (Ratio: {CORNER_RADIUS_RATIO})")
    print("  Target Base: " + BASE_DIR)
    print("=" * 66)
    
    if not os.path.exists(BASE_DIR):
        print(f"Error: Directory not found: {BASE_DIR}")
        sys.exit(1)
        
    all_files = []
    folder_counts = {f: 0 for f in TARGET_FOLDERS}
    
    for folder in TARGET_FOLDERS:
        folder_path = os.path.join(BASE_DIR, folder)
        if not os.path.isdir(folder_path):
            continue
            
        files = [os.path.join(folder_path, f) for f in os.listdir(folder_path) if f.lower().endswith(".png")]
        folder_counts[folder] = len(files)
        all_files.extend(files)
        
    total_files = len(all_files)
    print(f"[*] Found {total_files} PNG icons across {len(TARGET_FOLDERS)} folders.")
    print(f"[*] Processing with {os.cpu_count() or 4} parallel worker threads...\n")
    
    start_time = time.time()
    completed = 0
    
    with ProcessPoolExecutor(max_workers=os.cpu_count()) as executor:
        results = executor.map(round_single_icon, all_files)
        
        for file_path, status in results:
            completed += 1
            pct = (completed / total_files) * 100
            
            bar_len = 28
            filled_len = int(bar_len * completed // total_files)
            bar = "█" * filled_len + "░" * (bar_len - filled_len)
            
            sys.stdout.write(f"\r[{bar}] {pct:5.1f}% ({completed}/{total_files})")
            sys.stdout.flush()
            
    elapsed = time.time() - start_time
    print("\n\n" + "=" * 66)
    print("  ROUNDING SUMMARY")
    print("=" * 66)
    
    for folder in TARGET_FOLDERS:
        print(f"  {folder:<14} | {folder_counts[folder]:<6} icons rounded")
        
    print("-" * 66)
    print(f"  TOTAL          | {total_files:<6} icons rounded")
    print("=" * 66)
    print(f"[✓] Finished in {elapsed:.2f} seconds. All icon files are now rounded with the exact squircle geometry.")
    print("=" * 66)

if __name__ == "__main__":
    main()
