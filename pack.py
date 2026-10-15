#!/usr/bin/env python3
"""
TABRANIJ Pro Packaging Utility
Mengemas app.html menjadi 4 chunk terkompresi gzip + base64 (p0.js .. p3.js)
dan memverifikasi integritas dekompresi.
"""

import gzip
import base64
import os
import sys

def pack():
    base_dir = os.path.dirname(os.path.abspath(__file__))
    source_file = os.path.join(base_dir, "app.html")
    
    if not os.path.exists(source_file):
        print(f"[ERROR] File sumber tidak ditemukan: {source_file}")
        sys.exit(1)
        
    print(f"[*] Membaca {source_file}...")
    with open(source_file, "rb") as f:
        raw_data = f.read()
        
    print(f"[*] Ukuran sumber asli: {len(raw_data):,} bytes")
    
    # 1. Gzip compression level 9
    compressed = gzip.compress(raw_data, compresslevel=9)
    print(f"[*] Ukuran setelah gzip: {len(compressed):,} bytes (Rasio: {len(compressed)/len(raw_data)*100:.1f}%)")
    
    # 2. Base64 encoding
    b64 = base64.b64encode(compressed).decode("ascii")
    print(f"[*] Ukuran Base64: {len(b64):,} karakter")
    
    # 3. Split into 4 chunks
    total_len = len(b64)
    chunk_size = (total_len + 3) // 4
    chunks = [b64[i:i + chunk_size] for i in range(0, total_len, chunk_size)]
    
    while len(chunks) < 4:
        chunks.append("")
        
    for i in range(4):
        target_js = os.path.join(base_dir, f"p{i}.js")
        with open(target_js, "w", encoding="utf-8") as f:
            f.write(f'window.__P{i}="{chunks[i]}";\n')
        print(f"  -> Ditulis: p{i}.js ({len(chunks[i]):,} chars)")
        
    # 4. Verification
    rebuilt_b64 = "".join(chunks)
    assert rebuilt_b64 == b64, "Integritas chunk gagal!"
    decompressed = gzip.decompress(base64.b64decode(rebuilt_b64))
    assert decompressed == raw_data, "Hasil dekompresi tidak cocok dengan sumber!"
    
    print("\n[SUCCESS] Packaging selesai dan terverifikasi 100% identik!")
    print(f"File p0.js s/d p3.js siap digunakan oleh index.html.")

if __name__ == "__main__":
    pack()
