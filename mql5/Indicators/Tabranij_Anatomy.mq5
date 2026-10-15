//+------------------------------------------------------------------+
//|                                            Tabranij_Anatomy.mq5  |
//|                         Master MQL5 Gold Specialist - Indikator  |
//|               Genesis Riwayat Angka Faktual Informasi Keuangan   |
//+------------------------------------------------------------------+
#property copyright "Surgas & Master MQL5 Gold Specialist"
#property link      "https://github.com/surgas/tabranij"
#property version   "1.00"
#property indicator_separate_window
#property indicator_buffers 3
#property indicator_plots   3

// Plot 1: Efisiensi Neto (Histogram Biru / Hijau)
#property indicator_label1  "Efisiensi Neto (%)"
#property indicator_type1   DRAW_HISTOGRAM
#property indicator_color1  clrDodgerBlue
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

// Plot 2: Penolakan Atas (Line Merah)
#property indicator_label2  "Rasio Penolakan Atas (%)"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrTomato
#property indicator_style2  STYLE_DOT
#property indicator_width2  1

// Plot 3: Penolakan Bawah (Line Hijau)
#property indicator_label3  "Rasio Penolakan Bawah (%)"
#property indicator_type3   DRAW_LINE
#property indicator_color3  clrLimeGreen
#property indicator_style3  STYLE_DOT
#property indicator_width3  1

#include "..\Include\Tabranij.mqh"

//+------------------------------------------------------------------+
//| PARAMETER INPUT                                                  |
//+------------------------------------------------------------------+
input bool   InpShowDashboard      = true;          // Tampilkan Panel Live di Chart?
input color  InpTextColor          = clrWhite;      // Warna Teks Panel
input color  InpBgColor             = C'20,24,35';   // Warna Background Panel

// Buffer Indikator
double BufferEfisiensi[];
double BufferPenolakanAtas[];
double BufferPenolakanBawah[];

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
   SetIndexBuffer(0, BufferEfisiensi, INDICATOR_DATA);
   SetIndexBuffer(1, BufferPenolakanAtas, INDICATOR_DATA);
   SetIndexBuffer(2, BufferPenolakanBawah, INDICATOR_DATA);

   IndicatorSetInteger(INDICATOR_DIGITS, 1);
   IndicatorSetString(INDICATOR_SHORTNAME, "Tabranij Quant Engine");

   // Level Acuan (Level 20% Doji, Level 50% Penolakan Ekstrem, Level 65% Impuls)
   IndicatorSetInteger(INDICATOR_LEVELS, 3);
   IndicatorSetDouble(INDICATOR_LEVELVALUE, 0, 20.0);
   IndicatorSetDouble(INDICATOR_LEVELVALUE, 1, 50.0);
   IndicatorSetDouble(INDICATOR_LEVELVALUE, 2, 65.0);

   Print(">>> [Tabranij Indicator] Inisialisasi Berhasil.");
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                       |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   if(InpShowDashboard)
   {
      Comment("");
   }
}

//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
{
   if(rates_total < 2) return 0;

   int start = prev_calculated - 1;
   if(start < 0) start = 0;

   for(int i = start; i < rates_total; i++)
   {
      double o = open[i];
      double h = high[i];
      double l = low[i];
      double c = close[i];

      double j = h - l;
      double n = MathAbs(c - o);
      double atas  = MathMax(o, c);
      double bawah = MathMin(o, c);
      double ekor_atas  = h - atas;
      double ekor_bawah = bawah - l;

      if(j > 0)
      {
         BufferEfisiensi[i]       = (n / j) * 100.0;
         BufferPenolakanAtas[i]  = (ekor_atas / j) * 100.0;
         BufferPenolakanBawah[i] = (ekor_bawah / j) * 100.0;
      }
      else
      {
         BufferEfisiensi[i]       = 0.0;
         BufferPenolakanAtas[i]  = 0.0;
         BufferPenolakanBawah[i] = 0.0;
      }
   }

   // Update Live Dashboard pada Bar Terbaru
   if(InpShowDashboard)
   {
      Tabranij t_live = HitungTabranij(_Symbol, _Period, 0);
      ENUM_POLA_TABRANIJ pola = KlasifikasiPolaTabranij(t_live);

      string pola_nama = "STANDAR (NETRAL)";
      if(pola == POLA_IMPULSE_NAIK)        pola_nama = "IMPULS NAIK (MOMENTUM KUAT)";
      else if(pola == POLA_IMPULSE_TURUN)   pola_nama = "IMPULS TURUN (MOMENTUM KUAT)";
      else if(pola == POLA_REJECTION_ATAS)  pola_nama = "PENOLAKAN ATAS (REVERSAL SELL)";
      else if(pola == POLA_REJECTION_BAWAH) pola_nama = "PENOLAKAN BAWAH (REVERSAL BUY)";
      else if(pola == POLA_KOMPRESI_DOJI)   pola_nama = "KOMPRESI / DOJI (KERAGUAN)";

      string dash = StringFormat(
         "==========================================\n" +
         "       ANATOMI LILIN HARGA TABRANIJ       \n" +
         "==========================================\n" +
         "[T] Tinggi   : %.2f | [A] Atas  : %.2f\n" +
         "[B] Bawah    : %.2f | [R] Rendah: %.2f\n" +
         "[A] Awal     : %.2f | [N] Neto  : %.2f (Tubuh)\n" +
         "[I] Inti     : %.2f | [J] Julat : %.2f (Total)\n" +
         "------------------------------------------\n" +
         "Ekor Atas (Penolakan Jual) : %.2f (%.1f%%)\n" +
         "Ekor Bawah (Penyerapan Beli): %.2f (%.1f%%)\n" +
         "Efisiensi Neto (N/J)       : %.1f%%\n" +
         "Kondisi Faktual Pasar      : %s\n" +
         "==========================================",
         t_live.T, t_live.A,
         t_live.B, t_live.R,
         t_live.Awal, t_live.N,
         t_live.I, t_live.J,
         t_live.EkorAtas, (t_live.RasioPenolakanAtas * 100.0),
         t_live.EkorBawah, (t_live.RasioPenolakanBawah * 100.0),
         (t_live.EfisiensiNeto * 100.0),
         pola_nama
      );

      Comment(dash);
   }

   return rates_total;
}
//+------------------------------------------------------------------+
