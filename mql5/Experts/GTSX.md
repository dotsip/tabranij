# 📊 Grafik Tabranij Scalper XAUUSD (MQL5 Expert Advisor)

**Versi Saat Ini:** `v3.20` (10s Micro-Cycle & 120-Box Memory Edition)  
**File Utama:** `Grafik_Tabranij_Scalper_XAUUSD.mq5`  
**Arsitektur:** 100% Automated Trading — Standalone MQL5 (Tanpa Indikator Eksternal)  
**Konsep Dasar:** *Genesis Riwayat Angka Faktual Informasi Keuangan (GRAFIK TABRANIJ)*

---

## 1. Filosofi & Anatomi Grafik Tabranij (`T-A-B-R-A-I-N-J`)

Berbeda dengan bot standar yang hanya mengenal istilah `Open, High, Low, Close`, bot ini membaca setiap kotak waktu (*candlestick*) melalui **Anatomi Murni Grafik Tabranij** yang membedah kekuatan dorongan badan (*Neto*) dan tolakan ekor (*Atas* & *Bawah*) secara matematis dan tanpa ambiguitas:

| Simbol | Nama Variabel | Rumus / Definisi | Makna Anatomi |
| :--- | :--- | :--- | :--- |
| **T** | `T` (Tinggi) | `High` | Titik harga tertinggi yang dicapai pada kotak waktu |
| **A** | `A` (Atas) | `T - max(Awal, Inti)` | Panjang jarum/ekor atas (penolakan atas) |
| **B** | `B` (Bawah) | `min(Awal, Inti) - R` | Panjang jarum/ekor bawah (penolakan bawah) |
| **R** | `R` (Rendah) | `Low` | Titik harga terendah yang dicapai pada kotak waktu |
| **A** | `A` (Awal) | `Open` | Harga pembukaan saat kotak waktu dimulai |
| **N** | `N` (Neto) | `|Inti - Awal|` | Panjang murni badan kotak (perpindahan bersih harga) |
| **I** | `I` (Inti) | `Close` / `Live Price` | Harga penutupan (atau harga berjalan saat ini pada Bar `0`) |
| **J** | `J` (Julat) | `T - R` | Rentang total pergerakan kotak waktu |

### 3 Rasio Utama Tabranij:
1. **Rasio Atas (`A %`):** `(A / J) * 100%` — Mengukur persentase panjang ekor atas (*upper rejection*) pada kotak.
2. **Efisiensi Neto (`N %`):** `(N / J) * 100%` — Mengukur seberapa utuh tenaga dorongan badan dibanding total rentang gerak.
3. **Rasio Bawah (`B %`):** `(B / J) * 100%` — Mengukur persentase panjang ekor bawah (*lower rejection*) pada kotak.

> **Hukum Keseimbangan Anatomi Tabranij:**  
> `A % + N % + B % = 100%`  
> *(Atas + Neto + Bawah = Julat / J)*

---

## 2. Arsitektur Fitur yang Telah Terealisasi (`v3.20`)

### A. Pilar Waktu: Mikro-Siklus 10 Detik & Memori 120 Kotak M1 (Fitur Terbaru `v3.20`)
1. **Memori 120 Kotak M1 (2 Jam Siklus Pasar):**
   - Bot membaca dan mengingat hingga **120 kotak M1 ke belakang** (`InpHistoryBarsToRead = 120`), mencakup tepat **2 jam penuh** dinamika harga emas.
   - Mengidentifikasi batas tertinggi ($T_{120}$) dan terendah ($R_{120}$) 2 jam sebagai dinding support & resistance alamiah tanpa membebani memori CPU/VPS.
2. **Mesin Pemicu Mikro 10 Detik (Ultra-High Frequency / 6x Entry per Menit):**
   - Lilin M1 (60 detik) dibagi menjadi **6 jendela mikro 10 detik**:
     - Detik `00–09` $->$ Eksekusi pada detik **10**
     - Detik `10–19` $->$ Eksekusi pada detik **20**
     - Detik `20–29` $->$ Eksekusi pada detik **30**
     - Detik `30–39` $->$ Eksekusi pada detik **40**
     - Detik `40–49` $->$ Eksekusi pada detik **50**
     - Detik `50–59` $->$ Eksekusi pada detik **00**
   - Menghitung aliran order real-time (`UpTicks` vs `DownTicks`) selama 10 detik berjalan.
3. **Sistem Tingkat Lot Dinamis (Opsi 1, Opsi 2, Opsi 3):**
   - **Tingkat 1 (Reguler - Lot Standar):** Di dalam range 6 kotak M1:
     - **Opsi 1 (Follow Tren M1):** Searah dengan warna candle GT M1 sebelumnya (Hijau + `UpTicks > DownTicks` $->$ **BUY**; Merah + `DownTicks > UpTicks` $->$ **SELL**).
     - **Opsi 2 (Pantulan Ekor M1):** Menangkap pembalikan arah saat harga menguji atap/lantai penolakan M1 sebelumnya ($A_1 / B_1$).
   - **Tingkat 2 (Super Booster - Lot Dinaikkan / Pengali):**
     - **Opsi 3 (Melampaui 6 Kotak M1 Sebelumnya):** Mengacu pada titik tertinggi ($T_6$) dan terendah ($R_6$) dari 6 menit terakhir:
       - **Breakout 6 Kotak:** Menembus ke atas $T_6$ + `UpTicks` $->$ **BUY BOOSTER** (Lot dikalikan `InpBoosterLotMultiplier`).
       - **Breakout 6 Kotak:** Menembus ke bawah $R_6$ + `DownTicks` $->$ **SELL BOOSTER** (Lot dikalikan `InpBoosterLotMultiplier`).
       - **Reversal Sweep 6 Kotak:** Menusuk keluar $T_6/R_6$ lalu ditarik mundur + tick berbalik $->$ **BOOSTER REVERSAL** dengan lot ditingkatkan untuk mempercepat panen keranjang.

---

### B. Pilar 1 — 6 Mode Sinyal Tabranij & Pelabelan Komentar Otomatis
Setiap order yang dieksekusi oleh bot memiliki **komentar alasan spesifik (`Order Comment`)** yang tampil di tab *Trade / History* MT5:

1. **`MODE_FOLLOW_TREND`:** Mengikuti arah `Neto` candle (`Hijau = BUY`, `Merah = SELL`).
2. **`MODE_COUNTER_TREND`:** Melawan arah `Neto` candle untuk menangkap pantulan.
3. **`MODE_REJECTION_EKOR`:** Membaca dominasi `A` (Atas) dan `B` (Bawah).
4. **`MODE_BREAKOUT`:** Mendeteksi saat `Inti (I)` menembus atap `Tinggi (T)` atau lantai `Rendah (R)`.
5. **`MODE_REVERSAL`:** Mendeteksi *Liquidity Sweep* atau *Engulfing Neto*.
6. **`MODE_SMART_HYBRID` (Default):** Menggabungkan keempat logika di atas secara berurutan (*Zero Dead-Zone*).

---

### C. Proyeksi Kotak Masa Depan (`+1, +2, +3`) & Pending Order (`Limit` / `Stop`)
Bot memproyeksikan kotak yang **akan terjadi ke depan** (`InpFutureBarsToProject`, default `3` kotak: `+1, +2, +3`) di **semua Timeframe (`M1, M5, M15, M30, H1, H4, D1`)**:
1. Menghitung rata-rata terbobot (*Linear Weighted Average*) dari `VektorNeto`, `N`, `J`, `A (Atas)`, dan `B (Bawah)` dengan faktor redaman $0.92^k$.
2. Menggambar visual kotak bayangan masa depan di sebelah kanan candle berjalan.
3. Memasang pending order `Limit` dan `Stop` di proyeksi level $T$ dan $R$.

---

### D. Pilar 2 — Kontrol Layer, Anti-Kunci (*Anti-Lock*), & *Auto-Overtake*
1. **Mode Arah Keranjang (`ENUM_BASKET_DIRECTION`):**
   - `BASKET_MIXED_ANTI_LOCK`: Mencegah `Lot BUY == Lot SELL` (otomatis menambah `+0.01 lot` jika total lot akan terkunci `0.00` agar garis BEP/TP/SL tidak hilang).
   - `BASKET_ONE_WAY`: Mengunci 1 arah saja sampai keranjang selesai panen TP/SL.
   - `BASKET_SEPARATE_BUY_SELL`: Memisahkan keranjang BUY dan SELL.
2. **Filter Jarak Antar Order (`ENUM_STEP_MODE`):**
   - `STEP_FREE` (Bebas tiap bar), `STEP_MIN_DISTANCE`, atau `STEP_AVERAGING_ONLY`.
3. **Progresi Lot & *Auto-Overtake* (`CalculateNextLot`):**
   - Mendukung `LOT_FIXED`, `LOT_ADDER` (+), dan `LOT_MULTIPLIER` (x) dengan batas aman `InpMaxLotSize`.
   - **Fitur *Auto-Overtake*:** Membalikkan eksposur keranjang saat sinyal Breakout/Reversal terdeteksi.

---

### E. Visualisasi 6 Garis Real-Time di Chart (`UpdateChartLines`)
1. 🔵 **Garis `EXPOSURE BUY`:** Titik impas rata-rata (*weighted breakeven*) posisi BUY.
2. 🔴 **Garis `EXPOSURE SELL`:** Titik impas rata-rata (*weighted breakeven*) posisi SELL.
3. 🟡 **Garis `BEP ($0.00)`:** Titik harga di mana total profit bersih keranjang mencapai `$0.00`.
4. 🟢 **Garis `TARGET TP`:** Titik harga di mana keranjang akan otomatis ditutup sapu bersih.
5. 🟠 **Garis `BATAS RUGI (SL)`:** Titik harga *Cut Loss* darurat keranjang.
6. 🟣 **Garis `STOP OUT (SO)`:** Titik harga peringatan batas ketahanan akun broker.

---

## 3. Peta Fungsi Kode (`Code Map`)

```text
Grafik_Tabranij_Scalper_XAUUSD.mq5
├── Struktur Data & Helper Dasar
│   ├── struct Tabranij                   -> Struktur anatomi T-A-B-R-A-I-N-J
│   ├── struct BasketExposure             -> Statistik posisi BUY, SELL, Net Lot, & Profit
│   ├── HitungTabranij()                  -> Kalkulasi anatomi candle (A=Atas, B=Bawah, N=Neto)
│   ├── GetExtremeTR()                    -> Mencari Tinggi (T) & Rendah (R) ekstrem N bar ke belakang
│   ├── GetExecTF()                       -> Menentukan Timeframe aktif (otomatis ikuti _Period)
│   └── GetEffectiveTrendTF()             -> Menentukan Timeframe Kompas MTF secara dinamis
│
├── Modul Mikro-Siklus 10 Detik (v3.20)
│   ├── Check10SecMicroTrigger()          -> Evaluasi aliran tick 10 detik + GT M1 (Opsi 1, 2, 3)
│   └── OnTick() (Tick Flow Tracking)     -> Merekam UpTicks vs DownTicks live per jendela 10s
│
├── Modul Proyeksi Masa Depan (+1, +2, +3)
│   ├── CalculateFutureProjections()      -> Menghitung anatomi kotak masa depan (+1, +2, +3)
│   ├── DrawFutureBoxesOnChart()          -> Menggambar kotak bayangan masa depan di kanan chart
│   ├── DeleteFutureBoxObjects()          -> Membersihkan objek kotak bayangan saat ganti TF
│   └── PlaceFuturePendingOrders()        -> Memasang Buy/Sell Limit & Stop di proyeksi T dan R
│
├── Modul Sinyal & Filter (Pilar 1 & Pilar 2)
│   ├── EvaluateMTFCompass()              -> Evaluasi filter tren Timeframe Besar
│   ├── EvaluateTabranijSignal()          -> Otak sinyal 6 mode bar-by-bar (A/B dominant, Neto)
│   ├── CheckLayerAndStepPermission()     -> Validasi arah keranjang & jarak minimal antar order
│   └── CalculateNextLot()                -> Kalkulasi lot (+ Booster Lot Opsi 3 & Auto-Overtake)
│
├── Modul Eksekusi & Manajemen Keranjang
│   ├── SafeExecute()                     -> Eksekusi Market Order anti-error 10030
│   ├── ClosePositionsBySide()            -> Sapu bersih posisi (Semua / Hanya BUY / Hanya SELL)
│   ├── DeleteAllPendingOrders()          -> Menghapus seluruh pending order saat keranjang selesai
│   ├── CalculateTargets()                -> Kalkulasi nominal USD untuk TP, SL, dan Stop Out
│   ├── UpdateChartLines()                -> Menggambar 6 garis harga (Exp Buy/Sell, BEP, TP, SL, SO)
│   └── ManageBasketProfitAndLoss()       -> Monitor real-time eksekusi TP/SL & Panel Dashboard
│
└── Siklus Utama Event MT5
    ├── RunTabranijCycle()                -> Orkestrator utama yang menyatukan seluruh modul
    ├── OnInit()                          -> Inisialisasi Chart Shift, Timer 1 detik, & gambar awal
    ├── OnTimer()                         -> Detak otomatis tiap 1 detik (update garis & periksa 10s)
    ├── OnTick()                          -> Detak real-time tick flow & eksekusi instan
    └── OnDeinit()                        -> Pembersihan objek chart saat EA dilepas
```

---

## 4. Cara Pemasangan & Kompilasi di MetaTrader 5

1. Buka **MetaTrader 5** -> Tekan **`F4`** untuk membuka **MetaEditor**.
2. Buka file `Grafik_Tabranij_Scalper_XAUUSD.mq5` di dalam folder `MQL5/Experts/`.
3. Tekan **`F7` (Compile)** — pastikan `0 errors, 0 warnings`.
4. Pada jendela MT5, pastikan tombol **`Algo Trading`** di toolbar atas berwarna **Hijau**.
5. Pasang EA ke chart **XAUUSD M1** — bot akan otomatis membaca riwayat 120 kotak dan mengevaluasi pemicu mikro 10 detik dengan informasi *UpTicks vs DownTicks* langsung di dashboard chart.
