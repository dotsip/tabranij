# SPESIFIKASI MATEMATIS TABRANIJ
### Formulasi Kuantitatif, Hukum Konservasi & Metrik AI

---

## 📐 1. Definisi Variabel Matematis

Misalkan sebuah satuan waktu pasar (periode $t$) memiliki riwayat transaksi berurutan:
$$P(t) = \{ p_0, p_1, p_2, \dots, p_k \}$$

Maka 4 Harga Bebas (Data Primer) didefinisikan sebagai:
$$\begin{aligned}
\text{Awal } (A_0) &= p_0 \\
\text{Inti } (I) &= p_k \quad (\text{atau } p_{\text{live}} \text{ saat periode masih berjalan}) \\
\text{Tinggi } (T) &= \max_{0 \le i \le k} p_i \\
\text{Rendah } (R) &= \min_{0 \le i \le k} p_i
\end{aligned}$$

Berdasarkan 4 harga bebas tersebut, 4 Unsur Turunan didefinisikan secara eksak:
$$\begin{aligned}
\text{Atas } (A) &= \max(A_0, I) \\
\text{Bawah } (B) &= \min(A_0, I) \\
\text{Neto } (N) &= |I - A_0| \\
\text{Julat } (J) &= T - R
\end{aligned}$$

---

## ⚖️ 2. Hukum Kekekalan Volatilitas Tabranij

Untuk setiap lilin harga yang valid ($J > 0$), berlaku persamaan konservasi mutlak:

$$\mathbf{Julat} = \mathbf{Neto} + \mathbf{Ekor\text{ }Atas} + \mathbf{Ekor\text{ }Bawah}$$

Di mana:
$$\begin{aligned}
\text{Ekor Atas} &= T - A = T - \max(A_0, I) \\
\text{Ekor Bawah} &= B - R = \min(A_0, I) - R
\end{aligned}$$

### Pembuktian Matematis:
$$\begin{aligned}
J &= (T - A) + N + (B - R) \\
  &= T - \max(A_0, I) + |I - A_0| + \min(A_0, I) - R \\
  &= T - R - [\max(A_0, I) - \min(A_0, I)] + |I - A_0|
\end{aligned}$$
Karena secara identitas aljabar:
$$\max(x, y) - \min(x, y) = |x - y|$$
Maka:
$$J = T - R - |I - A_0| + |I - A_0| = T - R \quad (\text{Terbukti Identik})$$

---

## 🤖 3. Metrik Kuantitatif untuk Algoritma & AI

### 1. Rasio Efisiensi Neto ($E_N$)
Mengukur fraksi energi pasar yang berhasil diubah menjadi teritori bersih:
$$E_N = \frac{N}{J} = \frac{|I - A_0|}{T - R} \quad (0.0 \le E_N \le 1.0)$$

* **$E_N \ge 0.65$ (Pola Impuls / Breakout)**:
  Lilin didominasi oleh tubuh Neto padat. Tekanan beli atau jual sangat terkonsolidasi tanpa banyak penolakan. Sinyal kuat untuk strategi *Trend Following*.
* **$E_N \le 0.20$ (Pola Kompresi / Doji)**:
  Pasar berada dalam keraguan total atau volume transaksi sangat rendah.

---

### 2. Rasio Penolakan Ekstrem Atas ($R_{\text{atas}}$) & Bawah ($R_{\text{bawah}}$)
Mengukur besarnya penyerapan likuiditas oleh pihak lawan di level harga ekstrem:
$$R_{\text{atas}} = \frac{T - A}{J}, \quad R_{\text{bawah}} = \frac{B - R}{J}$$

* **Kondisi Reversal SELL**:
  $$R_{\text{atas}} \ge 0.50 \quad \text{dan} \quad E_N \le 0.30$$
  *Interpretasi*: Pembeli sempat mendorong harga hingga ke puncak *Tinggi*, tetapi penjual membalas secara masif dan memaksakan *Inti* ditutup di dekat batas bawah.
* **Kondisi Reversal BUY**:
  $$R_{\text{bawah}} \ge 0.50 \quad \text{dan} \quad E_N \le 0.30$$
  *Interpretasi*: Penjual sempat menekan harga hingga ke dasar *Rendah*, tetapi pembeli menyerap seluruh penawaran dan memantulkan *Inti* ke atas.

---

### 3. Vektor Asimetri Tekanan ($S_{\text{skew}}$)
Mengukur bias arah penolakan harga:
$$S_{\text{skew}} = \frac{(T - A) - (B - R)}{J} \quad (-1.0 \le S_{\text{skew}} \le 1.0)$$

* $S_{\text{skew}} > 0$: Tekanan penolakan dari atas lebih dominan dibanding bawah.
* $S_{\text{skew}} < 0$: Tekanan penolakan dari bawah lebih dominan dibanding atas.
* $S_{\text{skew}} \approx 0$: Lilin simetris (ekor atas dan ekor bawah seimbang).
