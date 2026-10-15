//+------------------------------------------------------------------+
//|                                                     Tabranij.mqh |
//|                         Master MQL5 Gold Specialist - Ontologi   |
//|               Genesis Riwayat Angka Faktual Informasi Keuangan   |
//+------------------------------------------------------------------+
#property copyright "Surgas & Master MQL5 Gold Specialist"
#property link      "https://github.com/surgas/tabranij"
#property version   "1.00"
#property strict

//+------------------------------------------------------------------+
//| STRUKTUR DATA ANATOMI LILIN TABRANIJ                             |
//+------------------------------------------------------------------+
struct Tabranij
{
   // 1. Empat Harga Bebas (Koordinat Y-Axis)
   double T;       // Tinggi (High)
   double Awal;    // Awal (Open)
   double R;       // Rendah (Low)
   double I;       // Inti (Close / Live Price)

   // 2. Empat Unsur Turunan
   double A;       // Atas = max(Awal, Inti) -> Tepi atas tubuh Neto
   double B;       // Bawah = min(Awal, Inti) -> Tepi bawah tubuh Neto
   double N;       // Neto = |Inti - Awal| -> Tubuh Kristal Riil
   double J;       // Julat = Tinggi - Rendah -> Range Volatilitas Total

   // 3. Jarak Ekor Penolakan
   double EkorAtas;   // T - A (Penolakan Penjual)
   double EkorBawah;  // B - R (Penyerapan Pembeli)

   // 4. Arah & Metrik Kuantitatif AI
   bool   IsNaik;           // True jika I >= Awal
   double VektorNeto;       // I - Awal (+ untuk bullish, - untuk bearish)
   double EfisiensiNeto;    // N / J (0.0 s/d 1.0)
   double RasioPenolakanAtas;  // EkorAtas / J
   double RasioPenolakanBawah; // EkorBawah / J
   double AsimetriTekanan;     // (EkorAtas - EkorBawah) / J
};

//+------------------------------------------------------------------+
//| FUNGSI PENGHITUNG ANATOMI TABRANIJ                               |
//+------------------------------------------------------------------+
Tabranij HitungTabranij(string symbol, ENUM_TIMEFRAMES timeframe, int shift)
{
   Tabranij tab;
   ZeroMemory(tab);

   MqlRates rates[];
   ArraySetAsSeries(rates, true);

   if(CopyRates(symbol, timeframe, shift, 1, rates) < 1)
   {
      return tab;
   }

   // 1. Input Empat Harga Bebas
   tab.T    = rates[0].high;
   tab.R    = rates[0].low;
   tab.Awal = rates[0].open;
   tab.I    = rates[0].close;

   // 2. Hitung Empat Turunan
   tab.A = MathMax(tab.Awal, tab.I);
   tab.B = MathMin(tab.Awal, tab.I);
   tab.N = MathAbs(tab.I - tab.Awal);
   tab.J = tab.T - tab.R;

   // 3. Hitung Ekor
   tab.EkorAtas  = tab.T - tab.A;
   tab.EkorBawah = tab.B - tab.R;

   // 4. Metrik Kuantitatif
   tab.VektorNeto = tab.I - tab.Awal;
   tab.IsNaik     = (tab.I >= tab.Awal);

   if(tab.J > 0)
   {
      tab.EfisiensiNeto       = tab.N / tab.J;
      tab.RasioPenolakanAtas  = tab.EkorAtas / tab.J;
      tab.RasioPenolakanBawah = tab.EkorBawah / tab.J;
      tab.AsimetriTekanan     = (tab.EkorAtas - tab.EkorBawah) / tab.J;
   }

   return tab;
}

//+------------------------------------------------------------------+
//| KLASIFIKASI DINAMIKA PASAR TABRANIJ                              |
//+------------------------------------------------------------------+
enum ENUM_POLA_TABRANIJ
{
   POLA_NETRAL,          // Lilin Standar
   POLA_IMPULSE_NAIK,    // Neto Tebal Bullish (Efisiensi Tinggi)
   POLA_IMPULSE_TURUN,   // Neto Tebal Bearish (Efisiensi Tinggi)
   POLA_REJECTION_ATAS,  // Ekor Atas Sangat Panjang (Potensi Reversal Sell)
   POLA_REJECTION_BAWAH, // Ekor Bawah Sangat Panjang (Potensi Reversal Buy)
   POLA_KOMPRESI_DOJI    // Neto Tipis (Keraguan Pasar / Konsolidasi)
};

ENUM_POLA_TABRANIJ KlasifikasiPolaTabranij(const Tabranij &t, double threshold_efisiensi = 0.60, double threshold_ekor = 0.50)
{
   if(t.J <= 0) return POLA_NETRAL;

   // A. Cek Kompresi / Doji
   if(t.EfisiensiNeto <= 0.20)
   {
      return POLA_KOMPRESI_DOJI;
   }

   // B. Cek Penolakan Ekstrem (Reversal Sinyal)
   if(t.RasioPenolakanAtas >= threshold_ekor && t.EfisiensiNeto <= 0.35)
   {
      return POLA_REJECTION_ATAS;
   }
   if(t.RasioPenolakanBawah >= threshold_ekor && t.EfisiensiNeto <= 0.35)
   {
      return POLA_REJECTION_BAWAH;
   }

   // C. Cek Momentum Impulsif (Breakout / Trend Sinyal)
   if(t.EfisiensiNeto >= threshold_efisiensi)
   {
      if(t.IsNaik) return POLA_IMPULSE_NAIK;
      else         return POLA_IMPULSE_TURUN;
   }

   return POLA_NETRAL;
}
