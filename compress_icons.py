#!/usr/bin/env python3
"""
26Home SolidGlass High-Fidelity Icon Compressor
Maximizes PNG compression while keeping 100% PRISTINE visual quality (ZERO grain, ZERO dithering, silky-smooth gradients).
"""

import os
import io
import sys
import time
import argparse
from concurrent.futures import ProcessPoolExecutor
from PIL import Image
import numpy as np

BASE_DIR = "/home/ngkhoi/26Home/layout/Library/Application Support/26Home/SolidGlass"
TARGET_FOLDERS = ["ClearLight", "ClearDark", "Dark", "Light"]

def compress_single_icon(args_tuple):
    """
    Compresses a single icon with high-fidelity TrueColor algorithms.
    modes:
      - 'lossless' (default): 100% bit-exact for visible pixels + dirty alpha zeroing.
      - 'truecolor-7': 7-bit TrueColor RGBA (2.1 million colors, 0% noise/dithering).
      - 'truecolor-6': 6-bit TrueColor RGBA (262k colors, 0% noise/dithering).
    """
    file_path, mode = args_tuple
    try:
        orig_size = os.path.getsize(file_path)
        if orig_size == 0:
            return (file_path, orig_size, orig_size, "EMPTY_SKIPPED")
            
        with Image.open(file_path) as im:
            im_rgba = im.convert("RGBA")
            arr = np.array(im_rgba)
            
            # Step 1: Zero out RGB for fully transparent pixels (Alpha == 0)
            # This is 100% lossless (invisible pixels) and dramatically improves Deflate compression
            transparent_mask = (arr[:, :, 3] == 0)
            arr[transparent_mask, :3] = 0
            
            # Step 2: Mode handling
            if mode == "truecolor-7":
                # Mask out the single least-significant bit (2.1M colors, no grain)
                arr[:, :, :3] = (arr[:, :, :3] & 0xFE) | ((arr[:, :, :3] >> 7) & 0x01)
            elif mode == "truecolor-6":
                # Mask out 2 least-significant bits (262k colors, no grain)
                arr[:, :, :3] = (arr[:, :, :3] & 0xFC) | ((arr[:, :, :3] >> 6) & 0x03)
            # else: 'lossless' keeps 100% exact RGB for all alpha > 0 pixels
            
            im_clean = Image.fromarray(arr, "RGBA")
            
            # Save with maximum scanline optimization and level 9 deflate
            buf = io.BytesIO()
            im_clean.save(buf, format="PNG", optimize=True, compress_level=9)
            compressed_data = buf.getvalue()
            new_size = len(compressed_data)
            
            if new_size < orig_size:
                with open(file_path, "wb") as f:
                    f.write(compressed_data)
                return (file_path, orig_size, new_size, "COMPRESSED")
            else:
                return (file_path, orig_size, orig_size, "ALREADY_OPTIMAL")
                
    except Exception as e:
        return (file_path, orig_size, orig_size, f"ERROR: {e}")

def main():
    parser = argparse.ArgumentParser(description="High-Fidelity 26Home SolidGlass Icon Compressor")
    parser.add_argument("--mode", choices=["lossless", "truecolor-7", "truecolor-6"], default="lossless",
                        help="Compression mode: 'lossless' (100%% exact, 0 loss), 'truecolor-7' (2.1M colors, no grain), 'truecolor-6' (262k colors, no grain)")
    args = parser.parse_args()
    
    mode_names = {
        "lossless": "100% Pure Lossless (Dirty-Alpha Zeroing + Level 9 Deflate)",
        "truecolor-7": "7-Bit High-Fidelity TrueColor (2.1M Colors, Zero Grain)",
        "truecolor-6": "6-Bit High-Fidelity TrueColor (262k Colors, Zero Grain)"
    }
    
    print("=" * 66)
    print("  26Home SolidGlass High-Fidelity Icon Compressor")
    print(f"  Mode: [{mode_names[args.mode]}]")
    print("  Target Base: " + BASE_DIR)
    print("=" * 66)
    
    if not os.path.exists(BASE_DIR):
        print(f"Error: Directory not found: {BASE_DIR}")
        sys.exit(1)
        
    all_tasks = []
    folder_stats = {f: {"count": 0, "orig_bytes": 0, "new_bytes": 0, "reduced_files": 0} for f in TARGET_FOLDERS}
    
    for folder in TARGET_FOLDERS:
        folder_path = os.path.join(BASE_DIR, folder)
        if not os.path.isdir(folder_path):
            continue
            
        files = [os.path.join(folder_path, f) for f in os.listdir(folder_path) if f.lower().endswith(".png")]
        for fp in files:
            all_tasks.append((folder, fp))
            
    total_files = len(all_tasks)
    print(f"[*] Found {total_files} PNG icons across {len(TARGET_FOLDERS)} folders.")
    print(f"[*] Processing with {os.cpu_count() or 4} parallel worker threads...\n")
    
    start_time = time.time()
    completed = 0
    total_orig_bytes = 0
    total_new_bytes = 0
    
    task_args = [(fp, args.mode) for (folder, fp) in all_tasks]
    
    with ProcessPoolExecutor(max_workers=os.cpu_count()) as executor:
        results = executor.map(compress_single_icon, task_args)
        
        for i, (file_path, orig_sz, new_sz, status) in enumerate(results):
            folder = all_tasks[i][0]
            completed += 1
            total_orig_bytes += orig_sz
            total_new_bytes += new_sz
            
            stats = folder_stats[folder]
            stats["count"] += 1
            stats["orig_bytes"] += orig_sz
            stats["new_bytes"] += new_sz
            if status == "COMPRESSED":
                stats["reduced_files"] += 1
                
            pct = (completed / total_files) * 100
            savings_so_far = (total_orig_bytes - total_new_bytes) / (1024 * 1024)
            
            bar_len = 28
            filled_len = int(bar_len * completed // total_files)
            bar = "█" * filled_len + "░" * (bar_len - filled_len)
            
            sys.stdout.write(f"\r[{bar}] {pct:5.1f}% ({completed}/{total_files}) | Saved: {savings_so_far:6.2f} MB")
            sys.stdout.flush()
            
    elapsed = time.time() - start_time
    print("\n\n" + "=" * 66)
    print("  COMPRESSION SUMMARY")
    print("=" * 66)
    
    print(f"{'Folder':<14} | {'Files':<8} | {'Original':<10} | {'Compressed':<10} | {'Saved':<10} | {'Ratio'}")
    print("-" * 66)
    
    for folder in TARGET_FOLDERS:
        s = folder_stats[folder]
        orig_mb = s["orig_bytes"] / (1024 * 1024)
        new_mb = s["new_bytes"] / (1024 * 1024)
        saved_mb = (s["orig_bytes"] - s["new_bytes"]) / (1024 * 1024)
        ratio = ((s["orig_bytes"] - s["new_bytes"]) / s["orig_bytes"] * 100) if s["orig_bytes"] > 0 else 0
        print(f"{folder:<14} | {s['count']:<8} | {orig_mb:7.2f} MB | {new_mb:7.2f} MB | {saved_mb:7.2f} MB | {ratio:5.1f}%")
        
    print("-" * 66)
    total_orig_mb = total_orig_bytes / (1024 * 1024)
    total_new_mb = total_new_bytes / (1024 * 1024)
    total_saved_mb = (total_orig_bytes - total_new_bytes) / (1024 * 1024)
    total_ratio = ((total_orig_bytes - total_new_bytes) / total_orig_bytes * 100) if total_orig_bytes > 0 else 0
    print(f"{'TOTAL':<14} | {total_files:<8} | {total_orig_mb:7.2f} MB | {total_new_mb:7.2f} MB | {total_saved_mb:7.2f} MB | {total_ratio:5.1f}%")
    print("=" * 66)
    print(f"[✓] Finished in {elapsed:.2f} seconds.")
    print("=" * 66)

if __name__ == "__main__":
    main()
