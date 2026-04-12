#!/usr/bin/env python3
"""
convert_skybox.py — Convert equirectangular skybox images to 6-face cubemap PNGs.

Supports: .exr, .hdr, .png, .jpg, .tiff

Usage:
    python3 convert_skybox.py <input_file> [output_folder_name] [face_size]

    input_file         Path to equirectangular panorama (.exr, .hdr, etc.)
    output_folder_name Optional. Defaults to input filename without extension.
    face_size          Optional. Pixel size of each face. Default: 1024.

Output:
    media/skyboxes/<output_folder_name>/px.png  (FRONT)
    media/skyboxes/<output_folder_name>/nx.png  (BACK)
    media/skyboxes/<output_folder_name>/pz.png  (RIGHT)
    media/skyboxes/<output_folder_name>/nz.png  (LEFT)
    media/skyboxes/<output_folder_name>/py.png  (UP)
    media/skyboxes/<output_folder_name>/ny.png  (DOWN)

Face naming convention (what our Skybox.pde class expects):
    px=FRONT, nx=BACK, pz=RIGHT, nz=LEFT, py=UP, ny=DOWN

Examples:
    python3 convert_skybox.py my_hdri.exr
    python3 convert_skybox.py my_hdri.exr space_station 512
    python3 convert_skybox.py ~/Downloads/urban_night_4k.hdr city_night 1024
"""

import sys
import os
import subprocess
import tempfile
import shutil
import numpy as np
from PIL import Image
import py360convert

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
OUTPUT_BASE = SCRIPT_DIR  # media/skyboxes/


def exr_hdr_to_png(input_path, output_path):
    """Convert HDR/EXR to tone-mapped 8-bit PNG using ffmpeg."""
    result = subprocess.run([
        "ffmpeg", "-y",
        "-i", input_path,
        "-vf", "tonemap=hable,format=rgb24",
        "-update", "1", "-frames:v", "1",
        output_path
    ], capture_output=True, text=True)

    if result.returncode != 0 or not os.path.exists(output_path):
        # Try without tone mapping (e.g. for .hdr with already-linear content)
        result2 = subprocess.run([
            "ffmpeg", "-y",
            "-i", input_path,
            "-vf", "format=rgb24",
            "-update", "1", "-frames:v", "1",
            output_path
        ], capture_output=True, text=True)
        if result2.returncode != 0:
            print("ffmpeg error:", result2.stderr[-500:])
            sys.exit(1)

    print(f"  Tone-mapped equirectangular: {output_path}")


def equirect_to_cubemap(equirect_path, out_dir, face_size):
    """Split equirectangular PNG into 6 cubemap face PNGs."""

    img = Image.open(equirect_path).convert("RGB")
    arr = np.array(img, dtype=np.float32) / 255.0

    # py360convert face order: F R B L U D
    # Our convention:          px nz nx pz py ny
    py360_to_ours = {
        "F": "px",  # FRONT
        "R": "pz",  # RIGHT
        "B": "nx",  # BACK
        "L": "nz",  # LEFT
        "U": "py",  # UP
        "D": "ny",  # DOWN
    }

    print(f"  Splitting into {face_size}x{face_size} cubemap faces...")
    os.makedirs(out_dir, exist_ok=True)

    faces = py360convert.e2c(arr, face_w=face_size, mode="bilinear", cube_format="dict")
    labels = {"F": "FRONT", "R": "RIGHT", "B": "BACK", "L": "LEFT", "U": "UP", "D": "DOWN"}
    for py_key, our_name in py360_to_ours.items():
        face = faces[py_key]
        face_img = Image.fromarray((face * 255).clip(0, 255).astype(np.uint8))
        out_path = os.path.join(out_dir, f"{our_name}.png")
        face_img.save(out_path)
        print(f"    {our_name}.png  ({py_key} = {labels[py_key]})")


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)

    input_path = os.path.abspath(sys.argv[1])
    if not os.path.exists(input_path):
        print(f"Error: file not found: {input_path}")
        sys.exit(1)

    base_name = os.path.splitext(os.path.basename(input_path))[0]
    out_name = sys.argv[2] if len(sys.argv) > 2 else base_name
    face_size = int(sys.argv[3]) if len(sys.argv) > 3 else 1024

    out_dir = os.path.join(OUTPUT_BASE, out_name)

    print(f"\nConverting: {os.path.basename(input_path)}")
    print(f"Output:     {out_dir}/")
    print(f"Face size:  {face_size}x{face_size}px\n")

    ext = os.path.splitext(input_path)[1].lower()

    with tempfile.TemporaryDirectory() as tmp:
        if ext in (".exr", ".hdr"):
            equirect_png = os.path.join(tmp, "equirect.png")
            print("Step 1: Tone-mapping HDR/EXR to 8-bit PNG...")
            exr_hdr_to_png(input_path, equirect_png)
        else:
            equirect_png = input_path
            print("Step 1: Using image directly (not HDR)")

        print("Step 2: Converting equirectangular → 6 cubemap faces...")
        equirect_to_cubemap(equirect_png, out_dir, face_size)

    print(f"\nDone! Load in Processing with:")
    print(f'  skybox.load(sketchPath("../../media/skyboxes/{out_name}"));')


if __name__ == "__main__":
    main()
