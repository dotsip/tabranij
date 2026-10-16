//+------------------------------------------------------------------+
//|                          Grafik_Tabranij_Scalper_XAUUSD.mq5       |
//|                    Master MQL5 Gold Specialist - Standalone       |
//|            Genesis Riwayat Angka Faktual Informasi Keuangan       |
//+------------------------------------------------------------------+
#property copyright "Surgas & Master MQL5 Gold Specialist"
#property link      "https://github.com/surgas/tabranij"
#property version   "2.70"
#property strict

#include <Trade\Trade.mqh>

//+------------------------------------------------------------------+
//| STRUKTUR DATA ANATOMI GRAFIK TABRANIJ (EMBEDDED)                  |
//+------------------------------------------------------------------+
struct Tabranij
{
   double T;       // Tinggi (High)
   double A;       // Atas = max(Awal, Inti)
   double B;       // Bawah = min(Awal, Inti)
   double R;       // Rendah (Low)
   double Awal;    // Awal (Open)
   double I;       // Inti (Close / Live Price)
   double N;       // Neto = |Inti - Awal|
   double J;       // Julat = Tinggi - Rendah
   double EkorAtas;   // T - A
   double EkorBawah;  // B - R
   bool   IsNaik;
   double VektorNeto;
   double EfisiensiNeto;
   double RasioPenolakanAtas;
   double RasioPenolakanBawah;
};

//+------------------------------------------------------------------+
//| STRUKTUR DATA EXPOSURE & STATISTIK POSISI KERANJANG              |
//+------------------------------------------------------------------+
struct BasketExposure
{
   int      total_count;
   int      buy_count;
   int      sell_count;
   double   buy_lots;
   double   sell_lots;
   double   net_lots;
   double   buy_profit;
   double   sell_profit;
   double   total_profit;
   double   lowest_buy_price;
   double   highest_sell_price;
   double   last_buy_price;
   double   last_sell_price;
   datetime last_buy_time;
   datetime last_sell_time;
};

Tabranij HitungTabranij(string symbol, ENUM_TIMEFRAMES timeframe, int shift)
{
   Tabranij tab;
   ZeroMemory(tab);
   MqlRates rates[];
   ArraySetAsSeries(rates, true);

   if(CopyRates(symbol, timeframe, shift, 1, rates) < 1) return tab;

   tab.T    = rates[0].high;
   tab.R    = rates[0].low;
   tab.Awal = rates[0].open;
   tab.I    = rates[0].close;

   tab.A = MathMax(tab.Awal, tab.I);
   tab.B = MathMin(tab.Awal, tab.I);
   tab.N = MathAbs(tab.I - tab.Awal);
   tab.J = tab.T - tab.R;

   tab.EkorAtas   = tab.T - tab.A;
   tab.EkorBawah  = tab.B - tab.R;
   tab.VektorNeto = tab.I - tab.Awal;
   tab.IsNaik     = (tab.I >= tab.Awal);

   if(tab.J > 0)
   {
      tab.EfisiensiNeto       = tab.N / tab.J;
      tab.RasioPenolakanAtas  = tab.EkorAtas / tab.J;
      tab.RasioPenolakanBawah = tab.EkorBawah / tab.J;
   }
   return tab;
}

//+------------------------------------------------------------------+
//| Cari Nilai Tinggi (T) Tertinggi & Rendah (R) Terendah N Bar Lalu |
//+------------------------------------------------------------------+
bool GetExtremeTR(string symbol, ENUM_TIMEFRAMES timeframe, int start_shift, int count,
                  double &out_highest_T, double &out_lowest_R)
{
   out_highest_T = 0.0;
   out_lowest_R  = 0.0;
   if(count <= 0) return false;

   MqlRates rates[];
   ArraySetAsSeries(rates, true);

   int copied = CopyRates(symbol, timeframe, start_shift, count, rates);
   if(copied < 1) return false;

   out_highest_T = rates[0].high;
   out_lowest_R  = rates[0].low;

   for(int i = 1; i < copied; i++)
   {
      if(rates[i].high > out_highest_T) out_highest_T = rates[i].high;
      if(rates[i].low  < out_lowest_R)  out_lowest_R  = rates[i].low;
   }
   return true;
}

CTrade trade;

// 1. Pilihan 6 Mode Sinyal Anatomi Tabranij
enum ENUM_ENTRY_MODE
{
   MODE_FOLLOW_TREND,    // 1. Follow Trend: Momentum Neto Searah Candle
   MODE_COUNTER_TREND,   // 2. Counter Trend: Lawan Arah Neto Candle
   MODE_REJECTION_EKOR,  // 3. Rejection Ekor: Pantulan Ekor Atas/Bawah
   MODE_BREAKOUT,        // 4. Breakout: Inti Tembus Tinggi (T) / Rendah (R) Sebelumnya
   MODE_REVERSAL,        // 5. Reversal: Sweep T/R (False Break) & Engulfing Neto
   MODE_SMART_HYBRID     // 6. Smart Hybrid: Gabungan Otomatis Breakout, Reversal, Ekor & Momentum
};

// 2. Pilihan Mode Kompas Multi-Timeframe (MTF)
enum ENUM_MTF_MODE
{
   MTF_OFF,                  // Non-Aktif (Bebas Entry Tanpa Filter TF Besar)
   MTF_LIVE_BAR0,            // Live Bar 0 HTF (Searah Neto Candle TF Besar Saat Ini)
   MTF_CLOSED_BAR1,          // Closed Bar 1 HTF (Searah Candle TF Besar yang Sudah Tutup)
   MTF_BREAKOUT_OR_REVERSAL  // Pintar: Ikuti Breakout / Reversal Ekor pada TF Besar
};

// 3. Pilihan Mode Arah Keranjang (Pilar 2: Anti-Kunci Buy vs Sell)
enum ENUM_BASKET_DIRECTION
{
   BASKET_MIXED_ANTI_LOCK,   // Gabungan 2 Arah + Otomatis Anti-Kunci (Cegah Lot Buy == Lot Sell)
   BASKET_ONE_WAY,           // Kunci 1 Arah Saja Sampai Keranjang Selesai TP/SL
   BASKET_SEPARATE_BUY_SELL  // Pisah Keranjang BUY & SELL Sendiri-Sendiri (Panen 2 Arah)
};

// 4. Pilihan Mode Jarak Antar Order / Pip Step (Pilar 2: Layering Filter)
enum ENUM_STEP_MODE
{
   STEP_AVERAGING_ONLY,      // Averaging: Hanya Tambah Layer Saat Floating Minus Sejauh X Poin
   STEP_MIN_DISTANCE,        // Minimum Distance: Jarak Minimal X Poin dari Order Terakhir
   STEP_FREE                 // Bebas: Tanpa Filter Jarak (Buka Setiap Ada Sinyal)
};

// 5. Pilihan Mode Progresi Lot Layer (Pilar 2: Lot Sizing)
enum ENUM_LOT_MODE
{
   LOT_FIXED,                // Fixed Lot: Ukuran Lot Selalu Tetap
   LOT_ADDER,                // Lot Adder (+): Tambah Lot Bertahap Tiap Layer (0.01, 0.02, 0.03...)
   LOT_MULTIPLIER            // Lot Multiplier (x): Kalikan Lot Tiap Layer (misal 1.2x, 1.5x...)
};

// 6. Pilihan Mode Perhitungan Berdasarkan Angka ($ USD) atau Persentase (% Saldo)
enum ENUM_BASKET_TYPE
{
   BASKET_USD,           // Berdasarkan Angka Nominal ($ Tunai)
   BASKET_PERCENT        // Berdasarkan Persentase (% Saldo)
};

// Nama Objek 6 Garis & Label di Chart (Exposure BUY, Exposure SELL, BEP, TP, Batas Rugi/SL, Stop Out/SO)
#define LINE_EXP_BUY_NAME   "GT_Line_ExposureBuy"
#define LINE_EXP_SELL_NAME  "GT_Line_ExposureSell"
#define LINE_BEP_NAME       "GT_Line_Breakeven"
#define LINE_TP_NAME        "GT_Line_TargetProfit"
#define LINE_SL_NAME        "GT_Line_BasketSL"
#define LINE_SO_NAME        "GT_Line_StopOut"

#define LABEL_EXP_BUY_NAME  "GT_Label_ExposureBuy"
#define LABEL_EXP_SELL_NAME "GT_Label_ExposureSell"
#define LABEL_BEP_NAME      "GT_Label_Breakeven"
#define LABEL_TP_NAME       "GT_Label_TargetProfit"
#define LABEL_SL_NAME       "GT_Label_BasketSL"
#define LABEL_SO_NAME       "GT_Label_StopOut"

//+------------------------------------------------------------------+
//| PARAMETER INPUT                                                  |
//+------------------------------------------------------------------+
input group "=== [1. PENGATURAN KERANJANG & SAPU BERSIH] ==="
input bool                  InpCloseAllMagic     = true;                    // SAPU BERSIH: Hitung & Tutup SEMUA Posisi Lama?
input bool                  InpAllSymbols        = false;                   // Pantau Semua Pair? (false = Hanya Simbol Ini)
input ulong                 InpMagicNumber       = 999111;                  // Magic Number

input group "=== [2. KONTROL LAYER, JARAK ORDER, & PROGRESI LOT (PILAR 2)] ==="
input ENUM_BASKET_DIRECTION InpBasketDirection   = BASKET_MIXED_ANTI_LOCK;  // Mode Arah Keranjang (Anti-Kunci / 1 Arah / Pisah)
input ENUM_STEP_MODE        InpStepMode          = STEP_MIN_DISTANCE;       // Mode Filter Jarak Antar Posisi (Pip Step)
input double                InpMinStepPoints     = 100.0;                   // Jarak Minimal Antar Order (Poin, 0 = Bebas)
input ENUM_LOT_MODE         InpLotMode           = LOT_FIXED;               // Mode Ukuran Lot Layer
input double                InpLotSize           = 0.01;                    // Ukuran Lot Awal (Layer 1)
input double                InpLotAddValue       = 0.01;                    // Nilai Tambah Lot (Jika Mode LOT_ADDER)
input double                InpLotMultiplier     = 1.3;                     // Pengali Lot (Jika Mode LOT_MULTIPLIER)
input double                InpMaxLotSize        = 0.50;                    // Pengaman Batas Maksimal Lot Per Order
input int                   InpMaxOpenPositions  = 50;                      // Maksimal Posisi Terbuka Bersamaan

input group "=== [3. PILIHAN MODE SINYAL ANATOMI TABRANIJ (PILAR 1)] ==="
input ENUM_TIMEFRAMES       InpExecTF            = PERIOD_M1;               // Timeframe Eksekusi Sinyal
input ENUM_ENTRY_MODE       InpEntryMode         = MODE_SMART_HYBRID;       // Mode Sinyal Anatomi Tabranij
input double                InpMinNetoPoints     = 0.0;                     // Filter Minimal Panjang Neto (Poin, 0 = Bebas)
input double                InpMinEfficiencyPct  = 50.0;                    // Minimal Efisiensi Neto % (Utk Trend & Breakout)
input double                InpMinRejectionPct   = 45.0;                    // Minimal Rasio Penolakan Ekor % (Utk Rejection & Sweep)
input int                   InpLookbackBars      = 5;                       // Jumlah Bar Acuan Tinggi (T) & Rendah (R) (Breakout/Reversal)

input group "=== [4. KOMPAS MULTI-TIMEFRAME (MTF TABRANIJ)] ==="
input ENUM_MTF_MODE         InpMTFMode           = MTF_LIVE_BAR0;           // Mode Filter Kompas TF Besar
input ENUM_TIMEFRAMES       InpTrendTF           = PERIOD_M15;              // Timeframe Kompas Tren Besar (HTF)
input int                   InpHTFLookbackBars   = 3;                       // Jumlah Bar Acuan Breakout di TF Besar

input group "=== [5. TARGET PROFIT KERANJANG (ANGKA / PERSENTASE)] ==="
input ENUM_BASKET_TYPE      InpTPType            = BASKET_USD;              // Mode Target Profit (Angka $ atau % Saldo)
input double                InpTargetUSD         = 5.0;                     // Target Profit ($ Tunai)
input double                InpTargetPercent     = 0.5;                     // Target Profit (% Saldo)

input group "=== [6. BATAS RUGI / CUT LOSS (ANGKA / PERSENTASE)] ==="
input bool                  InpUseBasketSL       = true;                    // Aktifkan Cut Loss Saat Batas Rugi Tersentuh?
input ENUM_BASKET_TYPE      InpSLType            = BASKET_USD;              // Mode Batas Rugi (Angka $ atau % Saldo)
input double                InpMaxLossUSD        = 15.0;                    // Batas Maksimal Rugi ($ Tunai)
input double                InpMaxLossPercent    = 1.5;                     // Batas Maksimal Rugi (% Saldo)

input group "=== [7. VISUALISASI 6 GARIS (EXPOSURE BUY/SELL, BEP, TP, SL, SO)] ==="
input bool                  InpShowChartLines    = true;                    // Tampilkan Garis di Chart?
input bool                  InpShowLineLabels    = true;                    // Tampilkan Teks Keterangan di Atas Garis?
input bool                  InpShowExposureLines = true;                    // Tampilkan Garis Exposure BUY & Exposure SELL?
input bool                  InpShowSOLine        = true;                    // Tampilkan Garis Stop Out (SO) Broker?
input color                 InpColorExpBuy       = clrDodgerBlue;           // Warna Garis Exposure BUY (Rata-Rata/BEP Buy)
input color                 InpColorExpSell      = clrTomato;               // Warna Garis Exposure SELL (Rata-Rata/BEP Sell)
input color                 InpColorBEP          = clrGold;                 // Warna Garis Breakeven Gabungan (Net BEP)
input color                 InpColorTP           = clrLime;                 // Warna Garis Target Profit (TP)
input color                 InpColorSL           = clrOrangeRed;            // Warna Garis Batas Rugi (Cut Loss / SL)
input color                 InpColorSO           = clrMagenta;              // Warna Garis Stop Out (SO Ketahanan Akun)
input ENUM_LINE_STYLE       InpLineStyle         = STYLE_SOLID;             // Gaya Garis Utama (Solid / Dash / Dot)
input int                   InpLineWidth         = 2;                       // Ketebalan Garis Utama (1 - 5)

input group "=== [8. NOTIFIKASI SUARA] ==="
input bool                  InpEnableSound       = true;                    // Aktifkan Suara?
input string                InpSoundBuy          = "ok.wav";                // Suara Order BUY
input string                InpSoundSell         = "expert.wav";            // Suara Order SELL
input string                InpSoundTP           = "alert.wav";             // Suara Saat Profit Tercapai
input string                InpSoundSL           = "stops.wav";             // Suara Saat Batas Rugi Terkena

datetime last_exec_bar_time = 0;
string   g_last_signal_info = "Menunggu Pergantian Bar...";
string   g_mtf_status_info  = "NON-AKTIF";

//+------------------------------------------------------------------+
//| Inisialisasi Mode Eksekusi Awal                                  |
//+------------------------------------------------------------------+
void InitTradeEngine()
{
   trade.SetExpertMagicNumber(InpMagicNumber);
   trade.SetDeviationInPoints(50);

   uint filling = (uint)SymbolInfoInteger(_Symbol, SYMBOL_FILLING_MODE);
   if((filling & SYMBOL_FILLING_FOK) != 0)
      trade.SetTypeFilling(ORDER_FILLING_FOK);
   else if((filling & SYMBOL_FILLING_IOC) != 0)
      trade.SetTypeFilling(ORDER_FILLING_IOC);
   else
      trade.SetTypeFilling(ORDER_FILLING_RETURN);
}

//+------------------------------------------------------------------+
//| Normalisasi Ukuran Lot Sesuai Aturan Broker & Pengaman Max Lot   |
//+------------------------------------------------------------------+
double NormalizeLot(double raw_lot)
{
   double min_lot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double max_lot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double lot_step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

   if(lot_step <= 0.0) lot_step = 0.01;
   if(min_lot  <= 0.0) min_lot  = 0.01;

   double lot = raw_lot;
   if(InpMaxLotSize > 0.0 && lot > InpMaxLotSize)
      lot = InpMaxLotSize;

   if(lot < min_lot) lot = min_lot;
   if(max_lot > 0.0 && lot > max_lot) lot = max_lot;

   lot = MathFloor((lot + 0.0000001) / lot_step) * lot_step;

   int lot_digits = 2;
   if(lot_step >= 1.0)        lot_digits = 0;
   else if(lot_step >= 0.1)   lot_digits = 1;
   else if(lot_step >= 0.01)  lot_digits = 2;
   else if(lot_step >= 0.001) lot_digits = 3;

   return NormalizeDouble(lot, lot_digits);
}

//+------------------------------------------------------------------+
//| Hitung Ukuran Lot Berikutnya Berdasarkan Layer & Anti-Kunci      |
//+------------------------------------------------------------------+
double CalculateNextLot(bool is_buy, const BasketExposure &exp)
{
   int same_side_count = is_buy ? exp.buy_count : exp.sell_count;
   double raw_lot = InpLotSize;

   if(same_side_count > 0)
   {
      if(InpLotMode == LOT_ADDER)
         raw_lot = InpLotSize + (same_side_count * InpLotAddValue);
      else if(InpLotMode == LOT_MULTIPLIER)
         raw_lot = InpLotSize * MathPow(InpLotMultiplier, same_side_count);
   }

   double final_lot = NormalizeLot(raw_lot);

   // PROTEKSI ANTI-KUNCI (Jika Mode BASKET_MIXED_ANTI_LOCK):
   // Cegah jumlah lot BUY sama persis dengan lot SELL (Net Lot == 0)
   if(InpBasketDirection == BASKET_MIXED_ANTI_LOCK)
   {
      double projected_buy_lots  = exp.buy_lots  + (is_buy  ? final_lot : 0.0);
      double projected_sell_lots = exp.sell_lots + (!is_buy ? final_lot : 0.0);

      if(MathAbs(projected_buy_lots - projected_sell_lots) < 0.00001)
      {
         double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
         if(step <= 0.0) step = 0.01;
         final_lot = NormalizeLot(final_lot + step);
         Print("[Anti-Kunci] Lot disesuaikan ke ", DoubleToString(final_lot, 2),
               " agar Total Lot BUY dan SELL tidak terkunci 1:1.");
      }
   }

   return final_lot;
}

//+------------------------------------------------------------------+
//| Validasi Arah Keranjang & Jarak Minimal Antar Posisi (Pilar 2)   |
//+------------------------------------------------------------------+
bool CheckLayerAndStepPermission(bool is_buy, const BasketExposure &exp, string &out_block_reason)
{
   out_block_reason = "";

   // 1. Cek Aturan Arah Keranjang (Jika Mode BASKET_ONE_WAY)
   if(InpBasketDirection == BASKET_ONE_WAY)
   {
      if(is_buy && exp.sell_count > 0 && exp.buy_count == 0)
      {
         out_block_reason = "Ditahan One-Way: Keranjang sedang fokus SELL";
         return false;
      }
      if(!is_buy && exp.buy_count > 0 && exp.sell_count == 0)
      {
         out_block_reason = "Ditahan One-Way: Keranjang sedang fokus BUY";
         return false;
      }
   }

   // 2. Cek Filter Jarak Minimal Antar Posisi (Pip Step)
   if(InpStepMode == STEP_FREE || InpMinStepPoints <= 0.0)
      return true;

   double min_dist_price = InpMinStepPoints * _Point;

   if(is_buy && exp.buy_count > 0)
   {
      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(InpStepMode == STEP_AVERAGING_ONLY)
      {
         // BUY baru hanya boleh dibuka jika harga Ask turun minimal X poin di bawah BUY terendah
         double dist_pts = (exp.lowest_buy_price - ask) / _Point;
         if((exp.lowest_buy_price - ask) < min_dist_price)
         {
            out_block_reason = StringFormat("Ditahan Averaging BUY (Jarak %.0f < %.0f pts di bawah %.2f)",
                                            dist_pts, InpMinStepPoints, exp.lowest_buy_price);
            return false;
         }
      }
      else if(InpStepMode == STEP_MIN_DISTANCE)
      {
         double dist_pts = MathAbs(ask - exp.last_buy_price) / _Point;
         if(MathAbs(ask - exp.last_buy_price) < min_dist_price)
         {
            out_block_reason = StringFormat("Ditahan Jarak BUY (%.0f < %.0f pts dari order terakhir)",
                                            dist_pts, InpMinStepPoints);
            return false;
         }
      }
   }
   else if(!is_buy && exp.sell_count > 0)
   {
      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(InpStepMode == STEP_AVERAGING_ONLY)
      {
         // SELL baru hanya boleh dibuka jika harga Bid naik minimal X poin di atas SELL tertinggi
         double dist_pts = (bid - exp.highest_sell_price) / _Point;
         if((bid - exp.highest_sell_price) < min_dist_price)
         {
            out_block_reason = StringFormat("Ditahan Averaging SELL (Jarak %.0f < %.0f pts di atas %.2f)",
                                            dist_pts, InpMinStepPoints, exp.highest_sell_price);
            return false;
         }
      }
      else if(InpStepMode == STEP_MIN_DISTANCE)
      {
         double dist_pts = MathAbs(bid - exp.last_sell_price) / _Point;
         if(MathAbs(bid - exp.last_sell_price) < min_dist_price)
         {
            out_block_reason = StringFormat("Ditahan Jarak SELL (%.0f < %.0f pts dari order terakhir)",
                                            dist_pts, InpMinStepPoints);
            return false;
         }
      }
   }

   return true;
}

//+------------------------------------------------------------------+
//| Eksekusi Pintar: Auto-Coba Seluruh Filling Mode (Anti-Error 10030)|
//+------------------------------------------------------------------+
bool SafeExecute(bool is_buy, double volume, string comment)
{
   double price = is_buy ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   bool success = false;

   if(is_buy)
      success = trade.Buy(volume, _Symbol, price, 0, 0, comment);
   else
      success = trade.Sell(volume, _Symbol, price, 0, 0, comment);

   if(!success && trade.ResultRetcode() == 10030)
   {
      ENUM_ORDER_TYPE_FILLING alternate_modes[3] = {ORDER_FILLING_IOC, ORDER_FILLING_RETURN, ORDER_FILLING_FOK};

      for(int i = 0; i < 3; i++)
      {
         trade.SetTypeFilling(alternate_modes[i]);
         price = is_buy ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);

         if(is_buy)
            success = trade.Buy(volume, _Symbol, price, 0, 0, comment);
         else
            success = trade.Sell(volume, _Symbol, price, 0, 0, comment);

         if(success) break;
      }
   }

   return success;
}

//+------------------------------------------------------------------+
//| Filter Validasi Posisi (Bisa Sapu Bersih Semua Magic Number)     |
//+------------------------------------------------------------------+
bool IsPositionEligible(ulong ticket)
{
   if(ticket <= 0) return false;

   string pos_symbol = PositionGetString(POSITION_SYMBOL);
   long   pos_magic  = PositionGetInteger(POSITION_MAGIC);

   // Cek simbol
   if(!InpAllSymbols && pos_symbol != _Symbol) return false;

   // JIKA SAPU BERSIH DIAKTIFKAN: SEMUA POSISI IKUT DIHITUNG & DITUTUP!
   if(InpCloseAllMagic) return true;

   // Jika tidak sapu bersih, hanya EA ini atau posisi manual (Magic 0)
   if(pos_magic == (long)InpMagicNumber || pos_magic == 0) return true;

   return false;
}

//+------------------------------------------------------------------+
//| Kumpulkan Data Exposure BUY & SELL Secara Lengkap                |
//+------------------------------------------------------------------+
void CollectBasketExposure(BasketExposure &exp)
{
   ZeroMemory(exp);

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket > 0 && IsPositionEligible(ticket))
      {
         double pos_profit = PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
         exp.total_profit += pos_profit;
         exp.total_count++;

         if(PositionGetString(POSITION_SYMBOL) == _Symbol)
         {
            double   vol        = PositionGetDouble(POSITION_VOLUME);
            double   open_price = PositionGetDouble(POSITION_PRICE_OPEN);
            datetime open_time  = (datetime)PositionGetInteger(POSITION_TIME);
            long     type       = PositionGetInteger(POSITION_TYPE);

            if(type == POSITION_TYPE_BUY)
            {
               exp.buy_count++;
               exp.buy_lots   += vol;
               exp.buy_profit += pos_profit;

               if(exp.lowest_buy_price == 0.0 || open_price < exp.lowest_buy_price)
                  exp.lowest_buy_price = open_price;

               if(open_time >= exp.last_buy_time)
               {
                  exp.last_buy_time  = open_time;
                  exp.last_buy_price = open_price;
               }
            }
            else if(type == POSITION_TYPE_SELL)
            {
               exp.sell_count++;
               exp.sell_lots   += vol;
               exp.sell_profit += pos_profit;

               if(exp.highest_sell_price == 0.0 || open_price > exp.highest_sell_price)
                  exp.highest_sell_price = open_price;

               if(open_time >= exp.last_sell_time)
               {
                  exp.last_sell_time  = open_time;
                  exp.last_sell_price = open_price;
               }
            }
         }
      }
   }

   exp.net_lots = exp.buy_lots - exp.sell_lots;
}

//+------------------------------------------------------------------+
//| Evaluasi Kompas Multi-Timeframe (MTF) Tabranij                   |
//+------------------------------------------------------------------+
void EvaluateMTFCompass(bool &allow_buy, bool &allow_sell, string &mtf_info)
{
   allow_buy  = true;
   allow_sell = true;

   if(InpMTFMode == MTF_OFF)
   {
      mtf_info = "MTF OFF (Bebas 2 Arah)";
      return;
   }

   string tf_name = EnumToString(InpTrendTF);

   if(InpMTFMode == MTF_LIVE_BAR0)
   {
      Tabranij t_htf = HitungTabranij(_Symbol, InpTrendTF, 0);
      allow_buy  = t_htf.IsNaik;
      allow_sell = !t_htf.IsNaik;
      mtf_info   = StringFormat("%s Live(Bar 0): %s (Efisiensi %.0f%%)",
                                tf_name, (t_htf.IsNaik ? "BULLISH [BUY ONLY]" : "BEARISH [SELL ONLY]"),
                                t_htf.EfisiensiNeto * 100.0);
      return;
   }

   if(InpMTFMode == MTF_CLOSED_BAR1)
   {
      Tabranij t_htf = HitungTabranij(_Symbol, InpTrendTF, 1);
      allow_buy  = t_htf.IsNaik;
      allow_sell = !t_htf.IsNaik;
      mtf_info   = StringFormat("%s Closed(Bar 1): %s (Efisiensi %.0f%%)",
                                tf_name, (t_htf.IsNaik ? "BULLISH [BUY ONLY]" : "BEARISH [SELL ONLY]"),
                                t_htf.EfisiensiNeto * 100.0);
      return;
   }

   // Mode MTF_BREAKOUT_OR_REVERSAL pada TF Besar
   Tabranij htf0 = HitungTabranij(_Symbol, InpTrendTF, 0);
   Tabranij htf1 = HitungTabranij(_Symbol, InpTrendTF, 1);

   double htf_high_T = 0.0, htf_low_R = 0.0;
   bool has_range = GetExtremeTR(_Symbol, InpTrendTF, 2, MathMax(1, InpHTFLookbackBars), htf_high_T, htf_low_R);

   double min_rej = InpMinRejectionPct / 100.0;

   bool htf_rev_buy  = (htf1.RasioPenolakanBawah >= min_rej && htf1.EkorBawah > htf1.EkorAtas) ||
                       (has_range && htf1.R < htf_low_R && htf1.I > htf_low_R);
   bool htf_rev_sell = (htf1.RasioPenolakanAtas >= min_rej && htf1.EkorAtas > htf1.EkorBawah) ||
                       (has_range && htf1.T > htf_high_T && htf1.I < htf_high_T);

   bool htf_brk_buy  = has_range && (htf0.I > htf1.T || htf1.I > htf_high_T);
   bool htf_brk_sell = has_range && (htf0.I < htf1.R || htf1.I < htf_low_R);

   if(htf_brk_buy)
   {
      allow_buy  = true;
      allow_sell = false;
      mtf_info   = tf_name + ": BREAKOUT ATAS [BUY ONLY]";
   }
   else if(htf_brk_sell)
   {
      allow_buy  = false;
      allow_sell = true;
      mtf_info   = tf_name + ": BREAKOUT BAWAH [SELL ONLY]";
   }
   else if(htf_rev_buy && !htf_rev_sell)
   {
      allow_buy  = true;
      allow_sell = false;
      mtf_info   = tf_name + ": REVERSAL BAWAH [BUY ONLY]";
   }
   else if(htf_rev_sell && !htf_rev_buy)
   {
      allow_buy  = false;
      allow_sell = true;
      mtf_info   = tf_name + ": REVERSAL ATAS [SELL ONLY]";
   }
   else
   {
      allow_buy  = htf0.IsNaik;
      allow_sell = !htf0.IsNaik;
      mtf_info   = StringFormat("%s Trend Normal: %s", tf_name, (htf0.IsNaik ? "NAIK [BUY]" : "TURUN [SELL]"));
   }
}

//+------------------------------------------------------------------+
//| Evaluasi Sinyal Anatomi Tabranij Lengkap (Pilar 1)               |
//+------------------------------------------------------------------+
void EvaluateTabranijSignal(const Tabranij &t1, const Tabranij &t2,
                            bool &out_buy, bool &out_sell, string &out_reason)
{
   out_buy    = false;
   out_sell   = false;
   out_reason = "Tidak Ada Sinyal";

   if(InpMinNetoPoints > 0 && (t1.N / _Point) < InpMinNetoPoints)
   {
      out_reason = StringFormat("Neto Kecil (%.0f < %.0f pts)", t1.N / _Point, InpMinNetoPoints);
      return;
   }

   double min_eff = InpMinEfficiencyPct / 100.0;
   double min_rej = InpMinRejectionPct  / 100.0;

   double prev_highest_T = t2.T;
   double prev_lowest_R  = t2.R;
   GetExtremeTR(_Symbol, InpExecTF, 2, MathMax(1, InpLookbackBars), prev_highest_T, prev_lowest_R);

   // A. Sinyal Momentum (Follow Trend dengan Efisiensi Neto)
   bool sig_momentum_buy  = (t1.IsNaik  && t1.EfisiensiNeto >= min_eff);
   bool sig_momentum_sell = (!t1.IsNaik && t1.EfisiensiNeto >= min_eff);

   // B. Sinyal Rejection Ekor (Penolakan Bawah = BUY, Penolakan Atas = SELL)
   bool sig_reject_buy    = (t1.RasioPenolakanBawah >= min_rej && t1.EkorBawah > t1.EkorAtas);
   bool sig_reject_sell   = (t1.RasioPenolakanAtas  >= min_rej && t1.EkorAtas  > t1.EkorBawah);

   // C. Sinyal Breakout Tabranij (Inti t1 menembus Tinggi T atau Rendah R dari N bar sebelumnya)
   bool sig_breakout_buy  = (t1.IsNaik  && t1.I > prev_highest_T && t1.EfisiensiNeto >= min_eff);
   bool sig_breakout_sell = (!t1.IsNaik && t1.I < prev_lowest_R  && t1.EfisiensiNeto >= min_eff);

   // D. Sinyal Reversal Tabranij (1: Liquidity Sweep / False Breakout T-R, 2: Engulfing Neto A-B)
   bool rev_sweep_buy     = (t1.R < prev_lowest_R  && t1.I > prev_lowest_R  && t1.RasioPenolakanBawah >= min_rej);
   bool rev_sweep_sell    = (t1.T > prev_highest_T && t1.I < prev_highest_T && t1.RasioPenolakanAtas  >= min_rej);

   bool rev_engulf_buy    = (!t2.IsNaik && t1.IsNaik  && t1.I > t2.A && t1.N > t2.N);
   bool rev_engulf_sell   = (t2.IsNaik  && !t1.IsNaik && t1.I < t2.B && t1.N > t2.N);

   bool sig_reversal_buy  = (rev_sweep_buy  || rev_engulf_buy);
   bool sig_reversal_sell = (rev_sweep_sell || rev_engulf_sell);

   switch(InpEntryMode)
   {
      case MODE_FOLLOW_TREND:
         out_buy  = sig_momentum_buy;
         out_sell = sig_momentum_sell;
         if(out_buy)       out_reason = StringFormat("FOLLOW TREND BUY (Efisiensi %.1f%%)", t1.EfisiensiNeto * 100.0);
         else if(out_sell) out_reason = StringFormat("FOLLOW TREND SELL (Efisiensi %.1f%%)", t1.EfisiensiNeto * 100.0);
         else              out_reason = StringFormat("Skip: Efisiensi %.1f%% < %.1f%%", t1.EfisiensiNeto * 100.0, InpMinEfficiencyPct);
         break;

      case MODE_COUNTER_TREND:
         out_buy  = !t1.IsNaik;
         out_sell = t1.IsNaik;
         out_reason = out_buy ? "COUNTER TREND BUY (Lawan Neto Merah)" : "COUNTER TREND SELL (Lawan Neto Hijau)";
         break;

      case MODE_REJECTION_EKOR:
         out_buy  = sig_reject_buy;
         out_sell = sig_reject_sell;
         if(out_buy)       out_reason = StringFormat("REJECTION EKOR BAWAH BUY (%.1f%%)", t1.RasioPenolakanBawah * 100.0);
         else if(out_sell) out_reason = StringFormat("REJECTION EKOR ATAS SELL (%.1f%%)", t1.RasioPenolakanAtas * 100.0);
         else              out_reason = "Skip: Rasio Ekor Belum Mencapai Target";
         break;

      case MODE_BREAKOUT:
         out_buy  = sig_breakout_buy;
         out_sell = sig_breakout_sell;
         if(out_buy)       out_reason = StringFormat("BREAKOUT TINGGI (T) BUY @ %.2f", prev_highest_T);
         else if(out_sell) out_reason = StringFormat("BREAKOUT RENDAH (R) SELL @ %.2f", prev_lowest_R);
         else              out_reason = "Skip: Belum Ada Breakout T/R Valid";
         break;

      case MODE_REVERSAL:
         out_buy  = sig_reversal_buy;
         out_sell = sig_reversal_sell;
         if(rev_sweep_buy)        out_reason = "REVERSAL SWEEP RENDAH (R) BUY";
         else if(rev_engulf_buy)  out_reason = "REVERSAL ENGULFING ATAS (A) BUY";
         else if(rev_sweep_sell)  out_reason = "REVERSAL SWEEP TINGGI (T) SELL";
         else if(rev_engulf_sell) out_reason = "REVERSAL ENGULFING BAWAH (B) SELL";
         else                     out_reason = "Skip: Belum Ada Pola Reversal Tabranij";
         break;

      case MODE_SMART_HYBRID:
         if(sig_breakout_buy)       { out_buy = true;  out_reason = "SMART: BREAKOUT TINGGI (T) BUY"; }
         else if(sig_breakout_sell) { out_sell = true; out_reason = "SMART: BREAKOUT RENDAH (R) SELL"; }
         else if(sig_reversal_buy)  { out_buy = true;  out_reason = (rev_sweep_buy ? "SMART: REVERSAL SWEEP BUY" : "SMART: REVERSAL ENGULF BUY"); }
         else if(sig_reversal_sell) { out_sell = true; out_reason = (rev_sweep_sell ? "SMART: REVERSAL SWEEP SELL" : "SMART: REVERSAL ENGULF SELL"); }
         else if(sig_reject_buy)    { out_buy = true;  out_reason = StringFormat("SMART: REJECTION EKOR BUY (%.0f%%)", t1.RasioPenolakanBawah * 100.0); }
         else if(sig_reject_sell)   { out_sell = true; out_reason = StringFormat("SMART: REJECTION EKOR SELL (%.0f%%)", t1.RasioPenolakanAtas * 100.0); }
         else if(sig_momentum_buy)  { out_buy = true;  out_reason = StringFormat("SMART: MOMENTUM NETO BUY (%.0f%%)", t1.EfisiensiNeto * 100.0); }
         else if(sig_momentum_sell) { out_sell = true; out_reason = StringFormat("SMART: MOMENTUM NETO SELL (%.0f%%)", t1.EfisiensiNeto * 100.0); }
         else                       { out_reason = "SMART: Candle Bimbang / Hold"; }
         break;
   }
}

//+------------------------------------------------------------------+
//| Hapus Semua Objek Garis & Label dari Chart                       |
//+------------------------------------------------------------------+
void DeleteChartLines()
{
   ObjectDelete(0, LINE_EXP_BUY_NAME);
   ObjectDelete(0, LINE_EXP_SELL_NAME);
   ObjectDelete(0, LINE_BEP_NAME);
   ObjectDelete(0, LINE_TP_NAME);
   ObjectDelete(0, LINE_SL_NAME);
   ObjectDelete(0, LINE_SO_NAME);

   ObjectDelete(0, LABEL_EXP_BUY_NAME);
   ObjectDelete(0, LABEL_EXP_SELL_NAME);
   ObjectDelete(0, LABEL_BEP_NAME);
   ObjectDelete(0, LABEL_TP_NAME);
   ObjectDelete(0, LABEL_SL_NAME);
   ObjectDelete(0, LABEL_SO_NAME);
}

//+------------------------------------------------------------------+
//| Buat atau Perbarui Garis Horizontal + Label di Chart             |
//+------------------------------------------------------------------+
void DrawOrUpdateHorizontalLine(string line_name, string label_name, double price, color line_color,
                                ENUM_LINE_STYLE style, int width, string description)
{
   if(price <= 0 || !MathIsValidNumber(price))
   {
      ObjectDelete(0, line_name);
      ObjectDelete(0, label_name);
      return;
   }

   double normalized_price = NormalizeDouble(price, _Digits);

   // 1. Buat / Update Garis Horizontal (OBJ_HLINE)
   if(ObjectFind(0, line_name) < 0)
   {
      ObjectCreate(0, line_name, OBJ_HLINE, 0, 0, normalized_price);
      ObjectSetInteger(0, line_name, OBJPROP_BACK, false);
      ObjectSetInteger(0, line_name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, line_name, OBJPROP_SELECTED, false);
   }
   ObjectSetDouble(0, line_name, OBJPROP_PRICE, normalized_price);
   ObjectSetInteger(0, line_name, OBJPROP_COLOR, line_color);
   ObjectSetInteger(0, line_name, OBJPROP_STYLE, style);
   ObjectSetInteger(0, line_name, OBJPROP_WIDTH, width);
   ObjectSetString(0, line_name, OBJPROP_TEXT, description);
   ObjectSetString(0, line_name, OBJPROP_TOOLTIP, description);

   // 2. Buat / Update Label Teks di Atas Garis (OBJ_TEXT)
   if(InpShowLineLabels)
   {
      datetime bar_time = iTime(_Symbol, _Period, 0);
      if(bar_time > 0)
      {
         if(ObjectFind(0, label_name) < 0)
         {
            ObjectCreate(0, label_name, OBJ_TEXT, 0, bar_time, normalized_price);
            ObjectSetInteger(0, label_name, OBJPROP_ANCHOR, ANCHOR_RIGHT_LOWER);
            ObjectSetString(0, label_name, OBJPROP_FONT, "Consolas");
            ObjectSetInteger(0, label_name, OBJPROP_FONTSIZE, 9);
            ObjectSetInteger(0, label_name, OBJPROP_SELECTABLE, false);
         }
         ObjectMove(0, label_name, 0, bar_time, normalized_price);
         ObjectSetInteger(0, label_name, OBJPROP_COLOR, line_color);
         ObjectSetString(0, label_name, OBJPROP_TEXT, "  " + description + "  ");
      }
   }
   else
   {
      ObjectDelete(0, label_name);
   }
}

//+------------------------------------------------------------------+
//| Hitung Target Profit, Batas Rugi (SL), & Jarak Stop Out (SO)     |
//+------------------------------------------------------------------+
void CalculateTargets(double total_profit, double &target_tp_money, double &max_loss_money,
                      double &remaining_to_so_money, double &total_loss_at_so_money)
{
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);

   // 1. Target Profit (Berdasarkan Angka $ atau % Saldo)
   if(InpTPType == BASKET_USD)
      target_tp_money = InpTargetUSD;
   else
      target_tp_money = balance * (InpTargetPercent / 100.0);

   // 2. Batas Rugi / Cut Loss Keranjang (Berdasarkan Angka $ atau % Saldo)
   if(InpSLType == BASKET_USD)
      max_loss_money = InpMaxLossUSD;
   else
      max_loss_money = balance * (InpMaxLossPercent / 100.0);

   // 3. Stop Out (SO) Akun Broker (Titik Margin Call / Stop Out Level Broker)
   double equity   = AccountInfoDouble(ACCOUNT_EQUITY);
   double margin   = AccountInfoDouble(ACCOUNT_MARGIN);
   double so_level = AccountInfoDouble(ACCOUNT_MARGIN_SO_SO);
   long   so_mode  = AccountInfoInteger(ACCOUNT_MARGIN_SO_MODE);

   double min_equity_so = 0.0;
   if(so_mode == ACCOUNT_STOPOUT_MODE_PERCENT)
      min_equity_so = margin * (so_level / 100.0);
   else
      min_equity_so = so_level;

   // Sisa ketahanan Equity dari harga saat ini sampai menyentuh Stop Out Broker
   remaining_to_so_money  = MathMax(0.0, equity - min_equity_so);
   total_loss_at_so_money = remaining_to_so_money - total_profit;
}

//+------------------------------------------------------------------+
//| Hitung & Gambar 6 Garis: Exposure BUY, Exposure SELL, BEP, TP,   |
//| Batas Rugi (SL), dan Stop Out (SO)                               |
//+------------------------------------------------------------------+
void UpdateChartLines(const BasketExposure &exp,
                      double target_tp_money, double max_loss_money,
                      double remaining_to_so_money, double total_loss_at_so_money,
                      double &out_exp_buy_price, double &out_exp_sell_price,
                      double &out_bep_price, double &out_tp_price,
                      double &out_sl_price, double &out_so_price)
{
   out_exp_buy_price  = 0.0;
   out_exp_sell_price = 0.0;
   out_bep_price      = 0.0;
   out_tp_price       = 0.0;
   out_sl_price       = 0.0;
   out_so_price       = 0.0;

   double tick_value  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tick_size   = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double current_bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   if(tick_size <= 0.0 || tick_value <= 0.0 || current_bid <= 0.0)
   {
      DeleteChartLines();
      return;
   }

   // Nilai perubahan USD per 1.0 unit harga untuk 1.0 lot (contoh XAUUSD: $100 per $1 gerak harga)
   double value_per_price_unit = tick_value / tick_size;

   // --- A. HITUNG GARIS EXPOSURE BUY (Titik Impas / Pusat Massa Seluruh Posisi BUY) ---
   if(exp.buy_count > 0 && exp.buy_lots > 0.0)
   {
      double buy_usd_per_unit = exp.buy_lots * value_per_price_unit;
      out_exp_buy_price = current_bid + ((0.0 - exp.buy_profit) / buy_usd_per_unit);
   }

   // --- B. HITUNG GARIS EXPOSURE SELL (Titik Impas / Pusat Massa Seluruh Posisi SELL) ---
   if(exp.sell_count > 0 && exp.sell_lots > 0.0)
   {
      double sell_usd_per_unit = -exp.sell_lots * value_per_price_unit;
      out_exp_sell_price = current_bid + ((0.0 - exp.sell_profit) / sell_usd_per_unit);
   }

   // --- C. HITUNG GARIS BEP GABUNGAN, TP, SL, & SO (Jika Net Lot != 0) ---
   if(MathAbs(exp.net_lots) >= 0.00001)
   {
      double basket_usd_per_unit = exp.net_lots * value_per_price_unit;

      // 1. HARGA BREAKEVEN GABUNGAN (NET BEP) -> Floating Net = $0.00
      out_bep_price = current_bid + ((0.0 - exp.total_profit) / basket_usd_per_unit);

      // 2. HARGA TARGET PROFIT (TP) -> Floating Net = +target_tp_money ($ atau %)
      out_tp_price  = current_bid + ((target_tp_money - exp.total_profit) / basket_usd_per_unit);

      // 3. HARGA BATAS RUGI / CUT LOSS (SL) -> Floating Net = -max_loss_money ($ atau %)
      out_sl_price  = current_bid + (((-max_loss_money) - exp.total_profit) / basket_usd_per_unit);

      // 4. HARGA STOP OUT (SO) -> Equity jatuh menyentuh Stop Out Level Broker
      out_so_price  = current_bid + ((-remaining_to_so_money) / basket_usd_per_unit);
   }

   if(!InpShowChartLines || (MQLInfoInteger(MQL_TESTER) && !MQLInfoInteger(MQL_VISUAL_MODE)))
      return;

   // --- GAMBAR GARIS EXPOSURE BUY & EXPOSURE SELL ---
   if(InpShowExposureLines)
   {
      if(out_exp_buy_price > 0.0)
      {
         string exp_buy_desc = StringFormat("[EXPOSURE BUY: %d Pos | %.2f Lot | $%.2f | Balik 2x: Sell %.2f Lot] @ %." + IntegerToString(_Digits) + "f",
                                            exp.buy_count, exp.buy_lots, exp.buy_profit, (exp.buy_lots * 2.0), out_exp_buy_price);
         DrawOrUpdateHorizontalLine(LINE_EXP_BUY_NAME, LABEL_EXP_BUY_NAME, out_exp_buy_price, InpColorExpBuy, STYLE_DASH, 1, exp_buy_desc);
      }
      else
      {
         ObjectDelete(0, LINE_EXP_BUY_NAME);
         ObjectDelete(0, LABEL_EXP_BUY_NAME);
      }

      if(out_exp_sell_price > 0.0)
      {
         string exp_sell_desc = StringFormat("[EXPOSURE SELL: %d Pos | %.2f Lot | $%.2f | Balik 2x: Buy %.2f Lot] @ %." + IntegerToString(_Digits) + "f",
                                             exp.sell_count, exp.sell_lots, exp.sell_profit, (exp.sell_lots * 2.0), out_exp_sell_price);
         DrawOrUpdateHorizontalLine(LINE_EXP_SELL_NAME, LABEL_EXP_SELL_NAME, out_exp_sell_price, InpColorExpSell, STYLE_DASH, 1, exp_sell_desc);
      }
      else
      {
         ObjectDelete(0, LINE_EXP_SELL_NAME);
         ObjectDelete(0, LABEL_EXP_SELL_NAME);
      }
   }
   else
   {
      ObjectDelete(0, LINE_EXP_BUY_NAME);
      ObjectDelete(0, LABEL_EXP_BUY_NAME);
      ObjectDelete(0, LINE_EXP_SELL_NAME);
      ObjectDelete(0, LABEL_EXP_SELL_NAME);
   }

   // --- GAMBAR GARIS BEP, TP, BATAS RUGI (SL), & STOP OUT (SO) ---
   if(MathAbs(exp.net_lots) >= 0.00001)
   {
      double balance = AccountInfoDouble(ACCOUNT_BALANCE);
      double tp_pct  = (balance > 0) ? (target_tp_money / balance * 100.0) : 0.0;
      double sl_pct  = (balance > 0) ? (max_loss_money / balance * 100.0) : 0.0;
      double so_pct  = (balance > 0) ? (total_loss_at_so_money / balance * 100.0) : 0.0;
      double so_lvl  = AccountInfoDouble(ACCOUNT_MARGIN_SO_SO);

      string dir_label = (exp.net_lots > 0)
                         ? StringFormat("NET BUY %.2f Lot", exp.net_lots)
                         : StringFormat("NET SELL %.2f Lot", MathAbs(exp.net_lots));

      string bep_desc = StringFormat("[BEP $0.00] %s @ %." + IntegerToString(_Digits) + "f",
                                     dir_label, out_bep_price);
      string tp_desc  = StringFormat("[TARGET TP +$%.2f (+%.2f%%)] @ %." + IntegerToString(_Digits) + "f",
                                     target_tp_money, tp_pct, out_tp_price);
      string sl_desc  = StringFormat("[BATAS RUGI (SL)%s -$%.2f (-%.2f%%)] @ %." + IntegerToString(_Digits) + "f",
                                     (InpUseBasketSL ? "" : " NON-AKTIF"), max_loss_money, sl_pct, out_sl_price);
      string so_desc  = StringFormat("[STOP OUT (SO %.0f%%) -$%.2f (-%.2f%%)] @ %." + IntegerToString(_Digits) + "f",
                                     so_lvl, total_loss_at_so_money, so_pct, out_so_price);

      DrawOrUpdateHorizontalLine(LINE_BEP_NAME, LABEL_BEP_NAME, out_bep_price, InpColorBEP, InpLineStyle, InpLineWidth, bep_desc);
      DrawOrUpdateHorizontalLine(LINE_TP_NAME,  LABEL_TP_NAME,  out_tp_price,  InpColorTP,  InpLineStyle, InpLineWidth, tp_desc);
      DrawOrUpdateHorizontalLine(LINE_SL_NAME,  LABEL_SL_NAME,  out_sl_price,  InpColorSL,  InpLineStyle, InpLineWidth, sl_desc);

      if(InpShowSOLine)
         DrawOrUpdateHorizontalLine(LINE_SO_NAME, LABEL_SO_NAME, out_so_price, InpColorSO, STYLE_DOT, 1, so_desc);
      else
      {
         ObjectDelete(0, LINE_SO_NAME);
         ObjectDelete(0, LABEL_SO_NAME);
      }
   }
   else
   {
      // Jika Net Lot == 0 (terkunci 1:1), sembunyikan BEP/TP/SL/SO gabungan, tapi Garis Exposure BUY & SELL tetap tampil!
      ObjectDelete(0, LINE_BEP_NAME);
      ObjectDelete(0, LABEL_BEP_NAME);
      ObjectDelete(0, LINE_TP_NAME);
      ObjectDelete(0, LABEL_TP_NAME);
      ObjectDelete(0, LINE_SL_NAME);
      ObjectDelete(0, LABEL_SL_NAME);
      ObjectDelete(0, LINE_SO_NAME);
      ObjectDelete(0, LABEL_SO_NAME);
   }

   ChartRedraw(0);
}

//+------------------------------------------------------------------+
//| Tutup Posisi Keranjang (0 = Semua, 1 = Hanya BUY, -1 = Hanya SELL)|
//+------------------------------------------------------------------+
void ClosePositionsBySide(int side_filter)
{
   int max_attempts = 5;

   for(int attempt = 1; attempt <= max_attempts; attempt++)
   {
      int still_open = 0;

      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         ulong ticket = PositionGetTicket(i);
         if(ticket > 0 && IsPositionEligible(ticket))
         {
            long type = PositionGetInteger(POSITION_TYPE);
            if(side_filter == 1  && type != POSITION_TYPE_BUY)  continue;
            if(side_filter == -1 && type != POSITION_TYPE_SELL) continue;

            long magic = PositionGetInteger(POSITION_MAGIC);

            if(trade.PositionClose(ticket))
            {
               Print("[CloseBasket] Berhasil menutup tiket #", ticket, " (Magic: ", magic, ")");
            }
            else
            {
               Print("[CloseBasket] Percobaan ", attempt, " Gagal tiket #", ticket,
                     " - Retcode: ", trade.ResultRetcode(), " (", trade.ResultRetcodeDescription(), ")");
               still_open++;
            }
         }
      }

      if(still_open == 0)
      {
         Print("[CloseBasket] POSISI TARGET TELAH BERSIH TERTUTUP!");
         break;
      }

      Sleep(150);
   }

   ChartRedraw(0);
}

//+------------------------------------------------------------------+
//| Monitor & Eksekusi Basket TP & SL + Exposure (Real-Time)         |
//+------------------------------------------------------------------+
void ManageBasketProfitAndLoss(const Tabranij &t, BasketExposure &exp)
{
   CollectBasketExposure(exp);

   double target_tp_money        = 0.0;
   double max_loss_money         = 0.0;
   double remaining_to_so_money  = 0.0;
   double total_loss_at_so_money = 0.0;

   CalculateTargets(exp.total_profit, target_tp_money, max_loss_money, remaining_to_so_money, total_loss_at_so_money);

   double exp_buy_price  = 0.0;
   double exp_sell_price = 0.0;
   double bep_price      = 0.0;
   double tp_price       = 0.0;
   double sl_price       = 0.0;
   double so_price       = 0.0;

   if(exp.total_count > 0)
   {
      UpdateChartLines(exp, target_tp_money, max_loss_money,
                       remaining_to_so_money, total_loss_at_so_money,
                       exp_buy_price, exp_sell_price,
                       bep_price, tp_price, sl_price, so_price);
   }
   else
   {
      DeleteChartLines();
   }

   double balance     = AccountInfoDouble(ACCOUNT_BALANCE);
   double current_pct = (balance > 0) ? (exp.total_profit / balance * 100.0) : 0.0;
   double tp_pct      = (balance > 0) ? (target_tp_money / balance * 100.0) : 0.0;
   double sl_pct      = (balance > 0) ? (max_loss_money / balance * 100.0) : 0.0;
   double so_pct      = (balance > 0) ? (total_loss_at_so_money / balance * 100.0) : 0.0;

   // Kalkulator Cepat Lot untuk Lock & Reversal / Breakout Mendadak
   string quick_calc_info = "Belum Ada Posisi Terbuka";
   if(MathAbs(exp.net_lots) >= 0.00001)
   {
      string opp_dir  = (exp.net_lots > 0) ? "SELL" : "BUY";
      double lock_lot = MathAbs(exp.net_lots);
      double rev_lot  = MathAbs(exp.net_lots) * 2.0;
      quick_calc_info = StringFormat("Lock 1:1 = %s %.2f Lot | Balik Arah (2x) = %s %.2f Lot",
                                     opp_dir, lock_lot, opp_dir, rev_lot);
   }
   else if(exp.total_count > 0)
   {
      quick_calc_info = "POSISI TERKUNCI 1:1 (Lot Buy == Lot Sell)";
   }

   // Tampilkan Dashboard Lengkap Tabranij + Exposure Buy/Sell + Kalkulator Cepat + 6 Garis
   string status_text = StringFormat(
      "=== [GRAFIK TABRANIJ MONITOR v2.70] ===\n" +
      "TF Eksekusi : %s | Mode: %s\n" +
      "Kompas MTF  : %s\n" +
      "Sinyal Bar 1: %s\n" +
      "--------------------------------------\n" +
      "Tinggi (T): %.2f | Rendah (R): %.2f | Neto (N): %.2f | Julat (J): %.2f\n" +
      "Efisiensi : %.1f%% | Ekor Atas: %.0f%% | Ekor Bawah: %.0f%%\n" +
      "--------------------------------------\n" +
      "EXPOSURE BUY   : %d Pos | %.2f Lot | P/L: $%.2f | Garis: %s\n" +
      "EXPOSURE SELL  : %d Pos | %.2f Lot | P/L: $%.2f | Garis: %s\n" +
      "TOTAL KERANJANG: %d Pos | Net: %.2f Lot | Floating: $%.2f (%.2f%%)\n" +
      "KALKULATOR CPT : %s\n" +
      "--------------------------------------\n" +
      "1. Garis BEP ($0)    : %s\n" +
      "2. Garis Target TP   : %s (+$%.2f / +%.2f%%)\n" +
      "3. Garis Batas Rugi  : %s (-$%.2f / -%.2f%%) [%s]\n" +
      "4. Garis Stop Out SO : %s (-$%.2f / -%.2f%%)\n",
      EnumToString(InpExecTF), EnumToString(InpEntryMode),
      g_mtf_status_info,
      g_last_signal_info,
      t.T, t.R, t.N, t.J,
      (t.EfisiensiNeto * 100.0), (t.RasioPenolakanAtas * 100.0), (t.RasioPenolakanBawah * 100.0),
      exp.buy_count,  exp.buy_lots,  exp.buy_profit,  (exp_buy_price  > 0 ? DoubleToString(exp_buy_price,  _Digits) : "-"),
      exp.sell_count, exp.sell_lots, exp.sell_profit, (exp_sell_price > 0 ? DoubleToString(exp_sell_price, _Digits) : "-"),
      exp.total_count, exp.net_lots, exp.total_profit, current_pct,
      quick_calc_info,
      (exp.total_count == 0 ? "-" : (bep_price > 0 ? DoubleToString(bep_price, _Digits) : "TERKUNCI (HEDGE)")),
      (exp.total_count == 0 ? "-" : (tp_price  > 0 ? DoubleToString(tp_price,  _Digits) : "TERKUNCI (HEDGE)")), target_tp_money, tp_pct,
      (exp.total_count == 0 ? "-" : (sl_price  > 0 ? DoubleToString(sl_price,  _Digits) : "TERKUNCI (HEDGE)")), max_loss_money,  sl_pct, (InpUseBasketSL ? "AKTIF" : "NON-AKTIF"),
      (exp.total_count == 0 ? "-" : (so_price  > 0 ? DoubleToString(so_price,  _Digits) : "TERKUNCI (HEDGE)")), total_loss_at_so_money, so_pct
   );
   Comment(status_text);

   if(exp.total_count == 0) return;

   // --- MODE PISAH KERANJANG BUY & SELL SENDIRI-SENDIRI ---
   if(InpBasketDirection == BASKET_SEPARATE_BUY_SELL)
   {
      if(exp.buy_count > 0 && exp.buy_profit >= target_tp_money)
      {
         Print(">>> [KERANJANG BUY TP TERCAPAI!] Profit BUY: $", DoubleToString(exp.buy_profit, 2));
         ClosePositionsBySide(1);
         if(InpEnableSound && !MQLInfoInteger(MQL_TESTER)) PlaySound(InpSoundTP);
         return;
      }
      if(exp.sell_count > 0 && exp.sell_profit >= target_tp_money)
      {
         Print(">>> [KERANJANG SELL TP TERCAPAI!] Profit SELL: $", DoubleToString(exp.sell_profit, 2));
         ClosePositionsBySide(-1);
         if(InpEnableSound && !MQLInfoInteger(MQL_TESTER)) PlaySound(InpSoundTP);
         return;
      }
      if(InpUseBasketSL && exp.buy_count > 0 && exp.buy_profit <= -max_loss_money)
      {
         Print(">>> [KERANJANG BUY SL TERSENTUH!] Rugi BUY: $", DoubleToString(exp.buy_profit, 2));
         ClosePositionsBySide(1);
         if(InpEnableSound && !MQLInfoInteger(MQL_TESTER)) PlaySound(InpSoundSL);
         return;
      }
      if(InpUseBasketSL && exp.sell_count > 0 && exp.sell_profit <= -max_loss_money)
      {
         Print(">>> [KERANJANG SELL SL TERSENTUH!] Rugi SELL: $", DoubleToString(exp.sell_profit, 2));
         ClosePositionsBySide(-1);
         if(InpEnableSound && !MQLInfoInteger(MQL_TESTER)) PlaySound(InpSoundSL);
         return;
      }
      return;
   }

   // --- MODE KERANJANG GABUNGAN (ONE-WAY ATAU MIXED ANTI-LOCK) ---
   // A. KONDISI TP TERCAPAI
   if(exp.total_profit >= target_tp_money)
   {
      Print("======================================================");
      Print(">>> [BASKET TP TERCAPAI!] Profit: $", DoubleToString(exp.total_profit, 2),
            " >= Target: $", DoubleToString(target_tp_money, 2));
      Print(">>> Eksekusi Sapu Bersih seluruh ", exp.total_count, " posisi...");
      Print("======================================================");

      ClosePositionsBySide(0);
      DeleteChartLines();

      if(InpEnableSound && !MQLInfoInteger(MQL_TESTER)) PlaySound(InpSoundTP);
      return;
   }

   // B. KONDISI BATAS RUGI (BASKET SL) TERSENTUH
   if(InpUseBasketSL && exp.total_profit <= -max_loss_money)
   {
      Print("======================================================");
      Print(">>> [BATAS RUGI / BASKET SL TERSENTUH!] Rugi: $", DoubleToString(exp.total_profit, 2),
            " <= Batas: -$", DoubleToString(max_loss_money, 2));
      Print(">>> CUT LOSS DARURAT: Sapu bersih seluruh posisi!");
      Print("======================================================");

      ClosePositionsBySide(0);
      DeleteChartLines();

      if(InpEnableSound && !MQLInfoInteger(MQL_TESTER)) PlaySound(InpSoundSL);
      return;
   }
}

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   InitTradeEngine();
   last_exec_bar_time = 0;

   // Aktifkan tampilan deskripsi objek di chart agar keterangan garis selalu terlihat
   ChartSetInteger(0, CHART_SHOW_OBJECT_DESCR, true);

   Print(">>> [Tabranij Scalper v2.70] Aktif pada ", _Symbol,
         " | Mode Sinyal: ", EnumToString(InpEntryMode),
         " | Arah Keranjang: ", EnumToString(InpBasketDirection),
         " | Step Mode: ", EnumToString(InpStepMode));
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   DeleteChartLines();
   Comment("");
   Print(">>> [Tabranij Scalper] Dihentikan & garis chart dibersihkan.");
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   // 1. Hitung Struktur Tabranij pada TF Eksekusi (Bar 1 dan Bar 2)
   Tabranij t1 = HitungTabranij(_Symbol, InpExecTF, 1);
   Tabranij t2 = HitungTabranij(_Symbol, InpExecTF, 2);

   // 2. Evaluasi Kompas Multi-Timeframe (MTF) secara Real-Time
   bool mtf_allow_buy  = true;
   bool mtf_allow_sell = true;
   EvaluateMTFCompass(mtf_allow_buy, mtf_allow_sell, g_mtf_status_info);

   // 3. Kelola TP & SL Basket Real-Time + Gambar 6 Garis (Exposure Buy, Exposure Sell, BEP, TP, SL, SO)
   BasketExposure exp;
   ManageBasketProfitAndLoss(t1, exp);

   // 4. Cek Pergantian Bar pada Timeframe Eksekusi
   datetime current_bar_time = iTime(_Symbol, InpExecTF, 0);
   if(current_bar_time == 0) return;

   if(current_bar_time == last_exec_bar_time)
   {
      return; // Masih di bar yang sama
   }

   last_exec_bar_time = current_bar_time;

   // 5. Batasan Maksimal Posisi Terbuka
   if(InpMaxOpenPositions > 0 && exp.total_count >= InpMaxOpenPositions)
   {
      g_last_signal_info = StringFormat("Hold: Posisi Penuh (%d/%d)", exp.total_count, InpMaxOpenPositions);
      return;
   }

   // 6. Evaluasi Sinyal Anatomi Tabranij Lengkap (Follow, Counter, Ekor, Breakout, Reversal, Smart Hybrid)
   bool raw_buy  = false;
   bool raw_sell = false;
   EvaluateTabranijSignal(t1, t2, raw_buy, raw_sell, g_last_signal_info);

   if(!raw_buy && !raw_sell) return;

   // 7. Saring Sinyal dengan Kompas Multi-Timeframe (MTF)
   if(raw_buy && !mtf_allow_buy)
   {
      g_last_signal_info += " [DITAHAN KOMPAS MTF SELL]";
      Print("[Tabranij] Sinyal BUY ditahan karena Kompas MTF sedang BEARISH.");
      return;
   }
   if(raw_sell && !mtf_allow_sell)
   {
      g_last_signal_info += " [DITAHAN KOMPAS MTF BUY]";
      Print("[Tabranij] Sinyal SELL ditahan karena Kompas MTF sedang BULLISH.");
      return;
   }

   // 8. Validasi Aturan Keranjang & Jarak Minimal Antar Posisi (Pilar 2)
   string block_reason = "";
   if(raw_buy && !CheckLayerAndStepPermission(true, exp, block_reason))
   {
      g_last_signal_info += " [" + block_reason + "]";
      Print("[Tabranij] ", block_reason);
      return;
   }
   if(raw_sell && !CheckLayerAndStepPermission(false, exp, block_reason))
   {
      g_last_signal_info += " [" + block_reason + "]";
      Print("[Tabranij] ", block_reason);
      return;
   }

   // 9. Hitung Lot Berikutnya (Fixed / Adder / Multiplier + Proteksi Anti-Kunci)
   if(raw_buy)
   {
      double lot_to_open = CalculateNextLot(true, exp);
      if(SafeExecute(true, lot_to_open, "GT Buy"))
      {
         Print("[GT] BUY Eksekusi ", DoubleToString(lot_to_open, 2), " Lot | ", g_last_signal_info);
         if(InpEnableSound && !MQLInfoInteger(MQL_TESTER)) PlaySound(InpSoundBuy);
      }
   }
   else if(raw_sell)
   {
      double lot_to_open = CalculateNextLot(false, exp);
      if(SafeExecute(false, lot_to_open, "GT Sell"))
      {
         Print("[GT] SELL Eksekusi ", DoubleToString(lot_to_open, 2), " Lot | ", g_last_signal_info);
         if(InpEnableSound && !MQLInfoInteger(MQL_TESTER)) PlaySound(InpSoundSell);
      }
   }
}
