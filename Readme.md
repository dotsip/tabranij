# Tabranij Pro v3.2 — TARI Extended

Visualizer interaktif spasial 3D & 2D modern untuk model analisis harga matematis **TABRANIJ (TARI)**.

---

## 📐 Model Matematis TARI

### Titik Inti (TARI)
| Kode | Input Tool | Deskripsi Pasar |
|:----:|:----------:|:----------------|
| **T** | **Tinggi** | High (Harga Tertinggi) |
| **A** | **Awal**   | Open (Titik Pembukaan / Konstanta Dasar) |
| **R** | **Rendah** | Low (Harga Terendah) |
| **I** | **Inti**   | Close / Harga Saat Ini |

### Rentang Kalkulasi Otomatis
| Komponen | Rumus Matematis | Arti |
|:---------|:----------------|:-----|
| **Atas**  | $T - \max(A, I)$ | Panjang wick / ekor atas (area rejection atas) |
| **Bawah** | $\min(A, I) - R$ | Panjang wick / ekor bawah (area rejection bawah) |
| **Neto**  | $\|I - A\|$      | Ketebalan body candle asli |
| **Julat** | $T - R$          | Range pergerakan penuh |

* **Identitas Julat:** $\text{Julat} = \text{Atas} + \text{Neto} + \text{Bawah}$ (diverifikasi otomatis di UI dengan tanda ✓).
* **Arah Bias:** 
  * 🟢 **BULLISH** jika $I \ge A$
  * 🔴 **BEARISH** jika $I < A$

---

## ⚡ Fitur Baru di v3.2

1. 📡 **Live Market Feed (Binance WebSocket + REST)**
   - Streaming candle real-time tanpa API key untuk pair: `BTCUSDT`, `ETHUSDT`, `PAXGUSDT` (Gold Token), dan `SOLUSDT`.
   - Update otomatis titik $T$, $A$, $R$, $I$ secara real-time tick-by-tick.
2. 🔍 **Deteksi Pola & Setup Rekomendasi Otomatis**
   - Klasifikasi pola otomatis berdasarkan rasio Atas, Neto, dan Bawah:
     - *Hammer / Rejection Bawah* (Sinyal BUY)
     - *Shooting Star / Rejection Atas* (Sinyal SELL)
     - *Bullish / Bearish Marubozu* (Super Momentum)
     - *Doji / Squeeze* (Konsolidasi / Keseimbangan)
     - *Spinning Top*
   - Kalkulasi otomatis Entry, Stop Loss (di luar Julat dengan buffer 8%), dan Take Profit (Risk:Reward 1:2).
3. 📐 **Dual Mode: 3D Spatial + 2D High-Def Chart**
   - Tombol toggle untuk beralih antara Three.js 3D WebGL (bisa diputar 360°, zoom, hover tooltip harga) dan Canvas 2D bergaya TradingView lengkap dengan garis level harga horizontal putus-putus.
4. ✈️ **Integrasi Telegram SurgaBot**
   - Mengirim laporan analisis dan sinyal TARI langsung ke bot Telegram `@ayahkayabot` melalui backend serverless `/api/submit` atau clipboard copy.
5. 📱 **Mobile Touch Gestures**
   - Dukungan swipe satu jari untuk rotasi 3D dan pinch dua jari untuk zoom in/out di smartphone atau tablet.
6. 📦 **Workflow Otomasi Packaging (`pack.py`)**
   - Source code utama kini tersimpan rapi dan dapat diedit di `app.html`.
   - Script `pack.py` secara otomatis mengompresi `app.html` menjadi chunk terenkapsulasi `p0.js` s/d `p3.js` untuk loader `index.html`.

---

## 🚀 Cara Menjalankan

### Opsi A: Langsung Buka File Development
Jalankan server HTTP lokal di folder `gt3`:
```bash
cd gt3
python -m http.server 8080
```
Buka browser di:
- `http://localhost:8080/app.html` (Master Source)
- `http://localhost:8080/index.html` (Compressed Loader)

---

## 🛠️ Alur Pengembangan & Re-Packaging

Jika Anda melakukan perubahan pada `app.html`, kemas kembali payload untuk produksi dengan:
```bash
python pack.py
```
Output script akan memvalidasi integritas dekompresi dan memperbarui chunk `p0.js` .. `p3.js` secara otomatis.

