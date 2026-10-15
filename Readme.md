# TABRANIJ Pro v3.2 — TARI Extended
### Genesis Riwayat Angka Faktual Informasi Keuangan
**Visualizer Interaktif Spasial 3D/2D & Ontologi Candlestick Faktual untuk Manusia, Algoritma, dan Superintelligence**

[![Live Web App](https://img.shields.io/badge/Live%20App-surgas.github.io%2Ftabranij-blue?style=for-the-badge)](https://surgas.github.io/tabranij/)
[![Documentation](https://img.shields.io/badge/Docs-Genesis%20%26%20Formula-gold?style=for-the-badge)](docs/)
[![License MIT](https://img.shields.io/badge/License-MIT-green?style=for-the-badge)](LICENSE)

---

## 🌐 Akses Langsung (Live Demo)

Aplikasi visualizer dapat langsung diakses secara instan di peramban tanpa instalasi apa pun:
👉 **[https://surgas.github.io/tabranij/](https://surgas.github.io/tabranij/)**

---

## 📐 1. Model Matematis TABRANIJ (TARI)

Pasar keuangan adalah entitas faktual yang digerakkan oleh transaksi riil, bukan istilah metaforis barat (*"real body"*, *"shadows"*). TABRANIJ mendekonstruksi setiap satuan waktu pasar menjadi **8 Variabel Faktual Objektif**:

$$\mathbf{T} \cdot \mathbf{A} \cdot \mathbf{B} \cdot \mathbf{R} \cdot \mathbf{A} \cdot \mathbf{N} \cdot \mathbf{I} \cdot \mathbf{J}$$
**T**inggi · **A**tas · **B**awah · **R**endah · **A**wal · **N**eto · **I**nti · **J**ulat

### A. Empat Titik Bebas (TARI - Data Faktual Primer)
| Kode | Nama | Simbol | Deskripsi Pasar |
|:----:|:----------:|:------:|:----------------|
| **T** | **Tinggi** | $T$ | *High* — Harga tertinggi absolut periode (Puncak Likuiditas Penjual). |
| **A** | **Awal**   | $A_0$ | *Open* — Titik pembukaan transaksi saat periode dimulai ($t_0$). |
| **R** | **Rendah** | $R$ | *Low* — Harga terendah absolut periode (Dasar Likuiditas Pembeli). |
| **I** | **Inti**   | $I$ | *Close / Live* — Harga kini dan harga penutupan. **Pusat gravitasi kesepakatan valuasi**. |

### B. Empat Rentang Turunan (Entitas Matematis Sekunder)
| Komponen | Rumus Matematis | Arti Faktual |
|:---------|:----------------|:-----|
| **Atas**  | $T - \max(A_0, I)$ | Panjang wick / ekor atas (area penolakan penjual). |
| **Bawah** | $\min(A_0, I) - R$ | Panjang wick / ekor bawah (area penyerapan pembeli). |
| **Neto**  | $\|I - A_0\|$      | **Tubuh kristal lilin asli**. Wilayah teritori bersih yang berhasil dipertahankan. |
| **Julat** | $T - R$          | Total luas medan jelajah pergerakan harga kotor (*Gross Volatility*). |

---

## ⚖️ 2. Hukum Kekekalan Volatilitas (Identitas Julat)

Dalam kerangka Tabranij, seluruh pergerakan harga terikat dalam satu hukum konservasi geometris mutlak:

$$\mathbf{Julat} = \mathbf{Atas} + \mathbf{Neto} + \mathbf{Bawah}$$

$$\mathbf{J} = (\mathbf{T} - \max(\mathbf{A_0}, \mathbf{I})) + \|\mathbf{I} - \mathbf{A_0}\| + (\min(\mathbf{A_0}, \mathbf{I}) - \mathbf{R}) = \mathbf{T} - \mathbf{R}$$

* Di antarmuka aplikasi `app.html` / `index.html`, identitas konservasi ini diverifikasi secara otomatis pada setiap tick dengan indikator validasi centang hijau (**✓**).
* **Arah Bias Pasar**:
  * 🟢 **BULLISH (Ekspansi Naik)** jika $I \ge A_0$
  * 🔴 **BEARISH (Ekspansi Turun)** jika $I < A_0$

📖 **Pelajari Teori Lebih Mendalam**:
* [**docs/genesis.md**](docs/genesis.md): Latar belakang, filosofi dekonstruksi istilah barat, serta hakikat fungsional Neto dan Inti.
* [**docs/formula.md**](docs/formula.md): Pembuktian aljabar hukum konservasi dan formulasi rasio kuantitatif AI.

---

## 🤖 3. Metrik Kuantitatif untuk AI & Algoritma

Model kuantitatif dan kecerdasan buatan (*superintelligence*) dapat membaca dinamika pasar secara instan tanpa indikator *lagging* melalui 3 metrik murni Tabranij:

### 1. Rasio Efisiensi Neto ($E_N$)
$$E_N = \frac{\text{Neto}}{\text{Julat}} \quad (0.0 \le E_N \le 1.0)$$
* **$E_N \ge 0.65$ (Impuls / Breakout)**: Teritori bersih sangat tebal, minim ekor. Momentum tren kuat.
* **$E_N \le 0.20$ (Kompresi / Doji)**: Pasar berada dalam keraguan total atau volume transaksi rendah.

### 2. Rasio Penolakan Ekstrem Atas ($R_{\text{atas}}$) & Bawah ($R_{\text{bawah}}$)
$$R_{\text{atas}} = \frac{\text{Atas}}{\text{Julat}}, \quad R_{\text{bawah}} = \frac{\text{Bawah}}{\text{Julat}}$$
* **$R_{\text{atas}} \ge 0.50$ dan $E_N \le 0.30$**: Penolakan ekstrem atas $\rightarrow$ Sinyal **Reversal SELL** berprobabilitas tinggi.
* **$R_{\text{bawah}} \ge 0.50$ dan $E_N \le 0.30$**: Penyerapan ekstrem bawah $\rightarrow$ Sinyal **Reversal BUY** berprobabilitas tinggi.

### 3. Vektor Asimetri Tekanan ($S_{\text{skew}}$)
$$S_{\text{skew}} = \frac{\text{Atas} - \text{Bawah}}{\text{Julat}}$$
* $S_{\text{skew}} > 0$: Penjual menekan dari atas lebih agresif daripada pembeli di bawah.
* $S_{\text{skew}} < 0$: Pembeli menekan dari bawah lebih agresif daripada penjual di atas.

---

## ⚡ 4. Fitur Aplikasi Visualizer (v3.2)

1. 📡 **Live Market Feed (Binance WebSocket + REST)**:
   * Streaming tick real-time tanpa API key untuk pair: `PAXGUSDT` (Token Emas / Pax Gold), `BTCUSDT`, `ETHUSDT`, dan `SOLUSDT`.
   * Update otomatis titik $T$, $A$, $R$, $I$ secara real-time tick-by-tick.
2. 🔍 **Deteksi Pola & Setup Rekomendasi Otomatis**:
   * Klasifikasi pola otomatis berdasarkan rasio Atas, Neto, dan Bawah:
     * *Hammer / Penolakan Bawah* (Sinyal BUY)
     * *Shooting Star / Penolakan Atas* (Sinyal SELL)
     * *Bullish / Bearish Marubozu* (Super Momentum)
     * *Doji / Squeeze* (Konsolidasi / Keseimbangan)
     * *Spinning Top*
   * Kalkulasi otomatis Entry, Stop Loss (di luar Julat dengan buffer 8%), dan Take Profit (Risk:Reward 1:2).
3. 📐 **Dual Mode View: 3D Spatial + 2D High-Def Chart**:
   * **3D Spasial (Three.js WebGL)**: Objek kristal lilin harga yang bisa diputar 360°, dizoom, dan memiliki hover tooltip harga.
   * **2D Canvas Chart**: Tampilan grafik 2D datar bergaya TradingView lengkap dengan garis horizontal putus-putus untuk setiap level harga $T, A, R, I$.
4. ✈️ **Integrasi Telegram SurgaBot**:
   * Mengirim laporan analisis dan sinyal TARI langsung ke bot Telegram `@ayahkayabot` melalui backend serverless `/api/submit` atau clipboard copy.
5. 📱 **Mobile Touch Gestures**:
   * Dukungan swipe satu jari untuk rotasi 3D dan pinch dua jari untuk zoom in/out di smartphone atau tablet.
6. 📦 **Workflow Otomasi Packaging (`pack.py`)**:
   * Source code utama tersimpan rapi dan dapat diedit di `app.html`.
   * Script `pack.py` secara otomatis mengompresi `app.html` menjadi chunk terenkapsulasi `p0.js` s/d `p3.js` untuk loader `index.html`.

---

## 🚀 5. Cara Menjalankan Secara Lokal

### Menjalankan Server Lokal
```bash
python -m http.server 8080
```
Buka peramban di:
* `http://localhost:8080/app.html` (Master Source)
* `http://localhost:8080/index.html` (Compressed Loader)

### Alur Pengembangan & Re-Packaging
Jika Anda melakukan perubahan pada `app.html`, kemas kembali payload untuk produksi dengan:
```bash
python pack.py
```
Output script akan memvalidasi integritas dekompresi dan memperbarui chunk `p0.js` .. `p3.js` secara otomatis.

---

## 📜 Lisensi & Hak Cipta

© 2026 **Surgas (Penemu & Penulis Grafik Tabranij)**. Dilisensikan di bawah [Lisensi MIT](LICENSE) — bebas digunakan, dikembangkan, dan diintegrasikan ke dalam ekosistem kuantitatif global.
