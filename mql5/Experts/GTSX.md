# 📊 Grafik Tabranij Scalper XAUUSD (MQL5 Expert Advisor)

**Versi Saat Ini:** `v3.10` (All-Timeframe Edition)  
**File Utama:** `Grafik_Tabranij_Scalper_XAUUSD.mq5`  
**Arsitektur:** 100% Automated Trading — Standalone MQL5 (Tanpa Indikator Eksternal)  
**Konsep Dasar:** *Genesis Riwayat Angka Faktual Informasi Keuangan (GRAFIK TABRANIJ)*

---

## 1. Filosofi & Anatomi Grafik Tabranij (`T-A-B-R-A-N-I-J`)

Berbeda dengan bot standar yang hanya mengenal istilah `Open, High, Low, Close`, bot ini membaca setiap kotak waktu (*candlestick*) melalui **Anatomi Grafik Tabranij** yang membedah kekuatan dorongan badan dan tolakan ekor secara matematis:

| Simbol | Nama Variabel | Rumus / Definisi | Makna Anatomi |
| :--- | :--- | :--- | :--- |
| **T** | `T` (Tinggi) | `High` | Titik harga tertinggi yang dicapai pada kotak waktu |
| **A** | `A` (Atas) | `max(Awal, Inti)` | Batas atap badan (*body*) kotak |
| **B** | `B` (Bawah) | `min(Awal, Inti)` | Batas lantai badan (*body*) kotak |
| **R** | `R` (Rendah) | `Low` | Titik harga terendah yang dicapai pada kotak waktu |
| **Awal** | `Awal` | `Open` | Harga pembukaan saat kotak waktu dimulai |
| **I** | `I` (Inti) | `Close` / `Live Price` | Harga penutupan (atau harga berjalan saat ini pada Bar `0`) |
| **N** | `N` (Neto) | `|I - Awal|` | Panjang murni badan kotak (perpindahan bersih harga) |
| **J** | `J` (Julat) | `T - R` | Rentang total pergerakan kotak waktu |
| **eka** | `EkorAtas` | `T - A` | Panjang jarum/ekor atas |
| **ekb** | `EkorBawah` | `B - R` | Panjang jarum/ekor bawah |

### 3 Rasio Utama Tabranij:
1. **Efisiensi Neto (`neto %`):** `(N / J) * 100%` — Mengukur seberapa utuh tenaga dorongan badan dibanding total rentang gerak.
2. **Rasio Ekor Atas (`eka %`):** `(EkorAtas / J) * 100%` — Mengukur persentase panjang ekor atas pada kotak.
3. **Rasio Ekor Bawah (`ekb %`):** `(EkorBawah / J) * 100%` — Mengukur persentase panjang ekor bawah pada kotak.

> **Hukum Keseimbangan Anatomi Tabranij:**  
> `neto % + eka % + ekb % = 100%`

---

## 2. Arsitektur Fitur yang Telah Terealisasi (`v3.10`)

### A. Pilar 1 — 6 Mode Sinyal Tabranij & Pelabelan Komentar Otomatis
Setiap order yang dieksekusi oleh bot memiliki **komentar alasan spesifik (`Order Comment`)** yang tampil di tab *Trade / History* MT5:

1. **`MODE_FOLLOW_TREND`:** Mengikuti arah `Neto` candle (`Hijau = BUY`, `Merah = SELL`).
   - *Comment:* `GT Buy neto 80%`, `GT Sell neto 75%`
2. **`MODE_COUNTER_TREND`:** Melawan arah `Neto` candle untuk menangkap pantulan.
   - *Comment:* `GT Buy neto 80%`, `GT Sell neto 75%`
3. **`MODE_REJECTION_EKOR`:** Membaca dominasi `eka` (Ekor Atas) dan `ekb` (Ekor Bawah). Dilengkapi saklar `InpEkorDirection`:
   - `EKOR_EKA_BUY_EKB_SELL`: Ekor Atas dominan = **BUY**, Ekor Bawah dominan = **SELL**.
   - `EKOR_EKB_BUY_EKA_SELL`: Ekor Bawah dominan = **BUY**, Ekor Atas dominan = **SELL**.
   - *Comment:* `GT Buy eka 80%`, `GT Sell ekb 80%`, `GT Buy ekb 80%`, `GT Sell eka 80%`
4. **`MODE_BREAKOUT`:** Mendeteksi saat `Inti (I)` menembus atap `Tinggi (T)` atau lantai `Rendah (R)` dari N kotak sebelumnya.
   - *Comment:* `GT Buy breakout`, `GT Sell breakout`
5. **`MODE_REVERSAL`:** Mendeteksi *Liquidity Sweep* (harga menembus `T`/`R` lalu ditarik masuk kembali meninggalkan ekor panjang) atau *Engulfing Neto* (`N` menelan badan kotak sebelumnya).
   - *Comment:* `GT Buy reversal`, `GT Sell reversal`
6. **`MODE_SMART_HYBRID` (Default):** Menggabungkan keempat logika di atas secara berurutan tanpa celah kosong (*Zero Dead-Zone*):
   `Breakout -> Reversal -> Ekor Dominan (eka/ekb) -> Neto Dominan (neto)`

---

### B. Proyeksi Kotak Masa Depan (`+1, +2, +3`) & Pending Order (`Limit` / `Stop`)
Bot membaca sejumlah kotak historis ke belakang (`InpHistoryBarsToRead`, default `4` kotak) + kotak `Live (Bar 0)` untuk memproyeksikan kotak yang **akan terjadi ke depan** (`InpFutureBarsToProject`, default `3` kotak: `+1, +2, +3`) di **semua Timeframe (`M1, M5, M15, M30, H1, H4, D1`)**:

1. **Rumus Proyeksi Masa Depan (`CalculateFutureProjections`):**
   - Menghitung rata-rata terbobot (*Linear Weighted Average*) dari `VektorNeto`, `N`, `J`, `EkorAtas`, dan `EkorBawah` pada 4 kotak terakhir.
   - Menggabungkan kecepatan historis (65%) dengan kecepatan berjalan `Bar 0` (35%).
   - Menerapkan faktor redaman (*Damping Factor* `0.92^k`) untuk menentukan `Awal`, `Inti`, `Atas (A)`, `Bawah (B)`, `Tinggi (T)`, dan `Rendah (R)` pada kotak `+1, +2, +3`.
2. **Visualisasi Kotak Bayangan di Kanan Chart (`DrawFutureBoxesOnChart`):**
   - Menggambar bingkai luar Julat (`T` ke `R`), kotak blok badan Neto (`A` ke `B`), garis ekor vertikal, dan label waktu `+1, +2, +3` di sebelah kanan candle berjalan.
3. **Eksekusi Pending Order Masa Depan (`PlaceFuturePendingOrders`):**
   - **Saat Sinyal BUY:** Memasang `Buy Limit` di proyeksi **Rendah (`R+1, R+2, R+3`)** dan/atau `Buy Stop` di proyeksi **Tinggi (`T+1, T+2, T+3`)**.
   - **Saat Sinyal SELL:** Memasang `Sell Limit` di proyeksi **Tinggi (`T+1, T+2, T+3`)** dan/atau `Sell Stop` di proyeksi **Rendah (`R+1, R+2, R+3`)**.

---

### C. Pilar 2 — Kontrol Layer, Anti-Kunci (*Anti-Lock*), & *Auto-Overtake*
1. **Mode Arah Keranjang (`ENUM_BASKET_DIRECTION`):**
   - `BASKET_MIXED_ANTI_LOCK`: Mengizinkan posisi BUY & SELL bersamaan tetapi **mencegah `Lot BUY == Lot SELL`** (otomatis menambah `+0.01 lot` jika total lot akan terkunci `0.00` agar garis BEP/TP/SL tidak pernah hilang).
   - `BASKET_ONE_WAY`: Mengunci 1 arah saja sampai keranjang selesai panen TP/SL.
   - `BASKET_SEPARATE_BUY_SELL`: Memisahkan keranjang BUY dan keranjang SELL agar bisa panen TP masing-masing.
2. **Filter Jarak Antar Order (`ENUM_STEP_MODE`):**
   - `STEP_FREE` (Bebas tiap bar), `STEP_MIN_DISTANCE` (Jarak minimal X poin dari order terakhir), atau `STEP_AVERAGING_ONLY` (Hanya tambah layer saat harga minus sejauh X poin).
3. **Progresi Lot & *Auto-Overtake* (`CalculateNextLot`):**
   - Mendukung `LOT_FIXED`, `LOT_ADDER` (+), dan `LOT_MULTIPLIER` (x) dengan batas aman `InpMaxLotSize`.
   - **Fitur *Auto-Overtake*:** Saat muncul sinyal `Breakout` atau `Reversal` yang berlawanan dengan posisi yang sedang floating minus, bot otomatis membuka lot sebesar `Net Lot Lawan * InpOvertakeLotFactor` untuk langsung membalikkan arah eksposur keranjang.

---

### D. Visualisasi 6 Garis Real-Time di Chart (`UpdateChartLines`)
Setiap *tick* dan setiap 1 detik (`OnTimer`), bot menghitung ulang dan menggambar 6 garis horizontal beserta label informasinya di chart:

1. 🔵 **Garis `EXPOSURE BUY`:** Titik impas rata-rata (*weighted breakeven*) seluruh posisi BUY + info jumlah posisi, total lot BUY, floating BUY, dan lot *Auto-Overtake*.
2. 🔴 **Garis `EXPOSURE SELL`:** Titik impas rata-rata (*weighted breakeven*) seluruh posisi SELL + info jumlah posisi, total lot SELL, floating SELL, dan lot *Auto-Overtake*.
3. 🟡 **Garis `BEP ($0.00)`:** Titik harga di mana total profit bersih seluruh keranjang (BUY + SELL + Swap) tepat mencapai `$0.00`.
4. 🟢 **Garis `TARGET TP`:** Titik harga di mana keranjang akan otomatis ditutup sapu bersih karena mencapai target profit (`$ USD` atau `% Saldo`).
5. 🟠 **Garis `BATAS RUGI (SL)`:** Titik harga di mana keranjang akan otomatis *Cut Loss* darurat sesuai batas rugi (`$ USD` atau `% Saldo`).
6. 🟣 **Garis `STOP OUT (SO)`:** Titik harga peringatan ketahanan maksimal akun berdasarkan `Equity`, `Margin`, dan `Stop Out Level %` broker.

---

## 3. Peta Fungsi Kode (`Code Map`)

Gunakan peta fungsi ini sebagai panduan cepat ketika ingin memodifikasi atau menambahkan fitur baru di `Grafik_Tabranij_Scalper_XAUUSD.mq5`:

```text
Grafik_Tabranij_Scalper_XAUUSD.mq5
├── Struktur Data & Helper Dasar
│   ├── struct Tabranij                   -> Struktur anatomi T-A-B-R-A-N-I-J
│   ├── struct BasketExposure             -> Statistik posisi BUY, SELL, Net Lot, & Profit
│   ├── HitungTabranij()                  -> Kalkulasi anatomi candle pada TF & shift tertentu
│   ├── GetExtremeTR()                    -> Mencari Tinggi (T) & Rendah (R) ekstrem N bar ke belakang
│   ├── GetExecTF()                       -> Menentukan Timeframe aktif (otomatis ikuti _Period)
│   └── GetEffectiveTrendTF()             -> Menentukan Timeframe Kompas MTF secara dinamis
│
├── Modul Proyeksi Masa Depan (+1, +2, +3)
│   ├── CalculateFutureProjections()      -> Menghitung anatomi kotak masa depan (+1, +2, +3)
│   ├── DrawFutureBoxesOnChart()          -> Menggambar kotak bayangan masa depan di kanan chart
│   ├── DeleteFutureBoxObjects()          -> Membersihkan objek kotak bayangan saat ganti TF
│   └── PlaceFuturePendingOrders()        -> Memasang Buy/Sell Limit & Stop di proyeksi T dan R
│
├── Modul Sinyal & Filter (Pilar 1 & Pilar 2)
│   ├── EvaluateMTFCompass()              -> Evaluasi filter tren Timeframe Besar
│   ├── EvaluateTabranijSignal()          -> Otak sinyal 6 mode + pembuat komentar order spesifik
│   ├── CheckLayerAndStepPermission()     -> Validasi arah keranjang & jarak minimal antar order
│   └── CalculateNextLot()                -> Kalkulasi lot (Fixed/Adder/Multiplier + Auto-Overtake)
│
├── Modul Eksekusi & Manajemen Keranjang
│   ├── SafeExecute()                     -> Eksekusi Market Order anti-error 10030 (Auto-Filling)
│   ├── ClosePositionsBySide()            -> Sapu bersih posisi (Semua / Hanya BUY / Hanya SELL)
│   ├── DeleteAllPendingOrders()          -> Menghapus seluruh pending order saat keranjang selesai
│   ├── CalculateTargets()                -> Kalkulasi nominal USD untuk TP, SL, dan Stop Out
│   ├── UpdateChartLines()                -> Menggambar 6 garis harga (Exp Buy/Sell, BEP, TP, SL, SO)
│   └── ManageBasketProfitAndLoss()       -> Monitor real-time eksekusi TP/SL & Panel Dashboard
│
└── Siklus Utama Event MT5
    ├── RunTabranijCycle()                -> Orkestrator utama yang menyatukan seluruh modul
    ├── OnInit()                          -> Inisialisasi Chart Shift, Timer 1 detik, & gambar awal
    ├── OnTimer()                         -> Detak otomatis tiap 1 detik (aktif meski pasar lambat)
    ├── OnTick()                          -> Detak real-time setiap harga bergerak
    └── OnDeinit()                        -> Pembersihan objek chart saat EA dilepas
```

---

## 4. Roadmap Pengembangan Selanjutnya (Siap Dibangun)

Agar pengembangan berikutnya terarah dan modular, berikut adalah daftar fitur lanjutan (**Pilar 3, Pilar 4, dan Pilar 5**) yang sudah disiapkan tempatnya di dalam arsitektur kode:

### 🚀 Tahap Berikutnya: Pilar 3 — *Basket Trailing Profit / Lock Profit*
- **Tujuan:** Mengamankan profit yang sudah didapat agar tidak berbalik menjadi minus jika harga memantul beberapa sen sebelum menyentuh garis Target TP utama.
- **Mekanisme yang Akan Ditambahkan:**
  - `InpUseTrailingProfit`: Saklar pengunci profit keranjang.
  - `InpTrailStartUSD` / `%`: Titik aktivasi pengunci (misal: saat profit menyentuh `+$3.00`, kunci profit di `+$1.50`).
  - `InpTrailStepUSD`: Jarak geser pengunci saat profit terus naik ke `+$4.00`, `+$5.00`, dst.
  - **Garis Visual Ke-7 (`GARIS LOCK PROFIT`):** Garis berwarna *Cyan/Aqua* di chart yang bergerak naik/turun mengawal harga secara *live*.

### 🛡️ Pilar 4 — *Execution & Daily Risk Guard* (Pelindung Akun Harian)
- **Filter Spread Maksimal (`InpMaxSpreadPoints`):** Menahan pembukaan order baru jika spread XAUUSD sedang melebar ekstrem saat rilis berita/pergantian sesi.
- **Kalkulasi Komisi ECN Akurat:** Menambahkan perhitungan `DEAL_COMMISSION` ke dalam `CollectBasketExposure()` agar pada akun *Raw/Zero Spread*, garis `BEP` dan `TP` sudah memperhitungkan potongan komisi broker.
- **Target Profit & Batas Rugi Harian (`Daily Target & Daily Drawdown Stop`):** Otomatis menghentikan bot untuk sisa hari tersebut jika target keuntungan harian sudah tercapai.
- **Filter Jam Sesi Trading (`Asia / London / New York`).**

### ✂️ Pilar 5 — *Smart Partial Close (Cicil Tutup Posisi Terjauh)*
- Menutup otomatis posisi paling ujung yang sedang floating minus besar menggunakan sebagian profit dari posisi *overtake* atau layer terbaru yang sedang profit, sehingga beban lot keranjang selalu ringan.

---

## 5. Cara Pemasangan & Kompilasi di MetaTrader 5

1. Buka **MetaTrader 5** -> Tekan **`F4`** untuk membuka **MetaEditor**.
2. Buka atau buat file `Grafik_Tabranij_Scalper_XAUUSD.mq5` di dalam folder `MQL5/Experts/`.
3. Tempelkan (*Paste*) seluruh kode terbaru dan tekan **`F7` (Compile)** — pastikan `0 errors, 0 warnings`.
4. Pada jendela MT5, pastikan tombol **`Algo Trading`** di toolbar atas berwarna **Hijau**.
5. Pasang EA ke chart **XAUUSD** dan klik bebas tombol timeframe (**M1, M5, M15, M30, H1**) — kotak proyeksi masa depan `+1, +2, +3` serta 6 garis visual akan otomatis menyesuaikan dalam 1 detik.
