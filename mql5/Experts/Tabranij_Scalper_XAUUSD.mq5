//+------------------------------------------------------------------+
//|                                  Tabranij_Scalper_XAUUSD.mq5      |
//|                         Master MQL5 Gold Specialist - Production |
//|               Genesis Riwayat Angka Faktual Informasi Keuangan   |
//+------------------------------------------------------------------+
#property copyright "Surgas & Master MQL5 Gold Specialist"
#property link      "https://github.com/surgas/tabranij"
#property version   "2.00"
#property strict

#include <Trade\Trade.mqh>
#include "..\Include\Tabranij.mqh"

CTrade trade;

// 1. Pilihan Mode Arah Entry Sinyal Tabranij
enum ENUM_ENTRY_MODE
{
   MODE_FOLLOW_TREND,    // Trend: Neto Hijau = BUY, Neto Merah = SELL
   MODE_COUNTER_TREND,   // Reversal: Neto Hijau = SELL, Neto Merah = BUY
   MODE_TABRANIJ_AI      // Algoritmik AI: Impuls = Follow, Penolakan Ekor = Reversal
};

// 2. Pilihan Mode Basket TP & SL
enum ENUM_BASKET_TYPE
{
   BASKET_USD,           // Nominal Uang ($ Tunai)
   BASKET_PERCENT        // Persentase Saldo (% Saldo)
};

//+------------------------------------------------------------------+
//| PARAMETER INPUT                                                  |
//+------------------------------------------------------------------+
input group "=== [1. STRATEGI ANATOMI TABRANIJ] ==="
input ENUM_ENTRY_MODE   InpEntryMode         = MODE_COUNTER_TREND; // Mode Arah Sinyal
input double            InpMinNetoPoints     = 0.0;                // Filter Minimal Panjang Neto (0 = Bebas)
input ulong             InpMagicNumber       = 999111;             // Magic Number
input double            InpLotSize           = 0.01;               // Ukuran Lot Tiap Menit
input int               InpMaxOpenPositions  = 50;                 // Maksimal Posisi Terbuka Bersamaan

input group "=== [2. TARGET BASKET TAKE PROFIT] ==="
input ENUM_BASKET_TYPE  InpBasketType        = BASKET_USD;         // Tipe Perhitungan (USD atau %)
input double            InpTargetUSD         = 5.0;                // Target Profit ($ Tunai)
input double            InpTargetPercent     = 0.5;                // Target Profit (% Saldo)

input group "=== [3. BATAS RUGI / BASKET STOP LOSS] ==="
input bool              InpUseBasketSL       = true;               // Aktifkan Batas Rugi Keranjang?
input double            InpMaxLossUSD        = 15.0;               // Batas Maksimal Rugi ($ Tunai)
input double            InpMaxLossPercent    = 1.5;                // Batas Maksimal Rugi (% Saldo)

input group "=== [4. NOTIFIKASI SUARA] ==="
input bool              InpEnableSound       = true;               // Aktifkan Suara?
input string            InpSoundBuy          = "ok.wav";           // Suara Order BUY
input string            InpSoundSell         = "expert.wav";       // Suara Order SELL
input string            InpSoundTP           = "alert.wav";        // Suara Saat Profit Tercapai
input string            InpSoundSL           = "stops.wav";        // Suara Saat Batas Rugi Terkena

datetime last_m1_bar_time = 0;

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
//| Tutup Seluruh Posisi Keranjang                                   |
//+------------------------------------------------------------------+
void CloseAllPositions()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket > 0)
      {
         if(PositionGetString(POSITION_SYMBOL) == _Symbol && 
            PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
         {
            trade.PositionClose(ticket);
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Monitor & Eksekusi Basket TP & SL (Real-Time Setiap Tick)        |
//+------------------------------------------------------------------+
void ManageBasketProfitAndLoss(const Tabranij &t)
{
   double total_profit = 0.0;
   int open_count = 0;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket > 0)
      {
         if(PositionGetString(POSITION_SYMBOL) == _Symbol && 
            PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
         {
            total_profit += (PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP));
            open_count++;
         }
      }
   }

   if(open_count == 0)
   {
      Comment("");
      return;
   }

   double target_tp_money = 0.0;
   double max_loss_money  = 0.0;

   if(InpBasketType == BASKET_USD)
   {
      target_tp_money = InpTargetUSD;
      max_loss_money  = InpMaxLossUSD;
   }
   else
   {
      double balance = AccountInfoDouble(ACCOUNT_BALANCE);
      target_tp_money = balance * (InpTargetPercent / 100.0);
      max_loss_money  = balance * (InpMaxLossPercent / 100.0);
   }

   // Tampilkan Dashboard Lengkap Tabranij di Chart
   string status_text = StringFormat(
      "=== [LAB KRISTAL TABRANIJ MONITOR] ===\n" +
      "Tinggi (T): %.2f | Rendah (R): %.2f\n" +
      "Awal   (A): %.2f | Inti   (I): %.2f\n" +
      "Neto   (N): %.2f | Julat  (J): %.2f (Efisiensi: %.1f%%)\n" +
      "Ekor Atas : %.2f | Ekor Bwh: %.2f\n" +
      "--------------------------------------\n" +
      "Posisi Terbuka : %d Posisi\n" +
      "Floating Net   : $%.2f\n" +
      "Target TP      : +$%.2f\n" +
      "Batas Rugi (SL): %s\n",
      t.T, t.R,
      t.Awal, t.I,
      t.N, t.J, (t.EfisiensiNeto * 100.0),
      t.EkorAtas, t.EkorBawah,
      open_count, 
      total_profit, 
      target_tp_money,
      (InpUseBasketSL ? StringFormat("-$%.2f", max_loss_money) : "NON-AKTIF")
   );
   Comment(status_text);

   // A. KONDISI TP TERCAPAI
   if(total_profit >= target_tp_money)
   {
      Print(">>> [BASKET TP!] Profit: $", DoubleToString(total_profit, 2), " >= Target: $", DoubleToString(target_tp_money, 2));
      CloseAllPositions();
      if(InpEnableSound && !MQLInfoInteger(MQL_TESTER)) PlaySound(InpSoundTP);
      return;
   }

   // B. KONDISI SL TERSENTUH
   if(InpUseBasketSL && total_profit <= -max_loss_money)
   {
      Print(">>> [BASKET SL!] Rugi: $", DoubleToString(total_profit, 2), " <= Batas: -$", DoubleToString(max_loss_money, 2));
      CloseAllPositions();
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
   last_m1_bar_time = 0;

   Print(">>> [Tabranij Scalper] Aktif pada ", _Symbol, " M1. Mode: ", EnumToString(InpEntryMode));
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   Comment("");
   Print(">>> [Tabranij Scalper] Dihentikan.");
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   // 1. Hitung Struktur Tabranij Terbaru (Bar 1)
   Tabranij t1 = HitungTabranij(_Symbol, PERIOD_M1, 1);

   // 2. Kelola TP & SL Basket Real-Time
   ManageBasketProfitAndLoss(t1);

   // 3. Cek Pergantian Menit
   datetime current_m1_time = iTime(_Symbol, PERIOD_M1, 0);
   if(current_m1_time == 0) return;

   if(current_m1_time == last_m1_bar_time)
   {
      return; // Masih di menit yang sama
   }

   // 4. Batasan Maksimal Posisi Terbuka
   if(InpMaxOpenPositions > 0 && PositionsTotal() >= InpMaxOpenPositions)
   {
      last_m1_bar_time = current_m1_time;
      return;
   }

   last_m1_bar_time = current_m1_time;

   // 5. Filter Minimal Panjang Neto
   if(InpMinNetoPoints > 0 && (t1.N / _Point) < InpMinNetoPoints)
   {
      Print("[Tabranij] Neto terlalu kecil (", t1.N, "). Entry dilewati.");
      return;
   }

   // ================= LOGIKA SINYAL TABRANIJ =================
   bool execute_buy  = false;
   bool execute_sell = false;

   if(InpEntryMode == MODE_FOLLOW_TREND)
   {
      // Trend: Neto Hijau (Naik) -> BUY | Neto Merah (Turun) -> SELL
      execute_buy  = t1.IsNaik;
      execute_sell = !t1.IsNaik;
   }
   else if(InpEntryMode == MODE_COUNTER_TREND)
   {
      // Counter: Neto Hijau (Naik) -> SELL | Neto Merah (Turun) -> BUY
      execute_buy  = !t1.IsNaik;
      execute_sell = t1.IsNaik;
   }
   else if(InpEntryMode == MODE_TABRANIJ_AI)
   {
      // Klasifikasi Dinamika Pasar Tabranij
      ENUM_POLA_TABRANIJ pola = KlasifikasiPolaTabranij(t1);

      if(pola == POLA_IMPULSE_NAIK)        execute_buy  = true;
      else if(pola == POLA_IMPULSE_TURUN)   execute_sell = true;
      else if(pola == POLA_REJECTION_BAWAH) execute_buy  = true; // Penolakan bawah -> Pantulan naik
      else if(pola == POLA_REJECTION_ATAS)  execute_sell = true; // Penolakan atas -> Pantulan turun
   }

   // EKSEKUSI BUY
   if(execute_buy)
   {
      if(SafeExecute(true, InpLotSize, "Tabranij_Buy"))
      {
         Print("[Tabranij] BUY Eksekusi | Neto: ", t1.N, " | Efisiensi: ", DoubleToString(t1.EfisiensiNeto*100, 1), "%");
         if(InpEnableSound && !MQLInfoInteger(MQL_TESTER)) PlaySound(InpSoundBuy);
      }
   }
   // EKSEKUSI SELL
   else if(execute_sell)
   {
      if(SafeExecute(false, InpLotSize, "Tabranij_Sell"))
      {
         Print("[Tabranij] SELL Eksekusi | Neto: ", t1.N, " | Efisiensi: ", DoubleToString(t1.EfisiensiNeto*100, 1), "%");
         if(InpEnableSound && !MQLInfoInteger(MQL_TESTER)) PlaySound(InpSoundSell);
      }
   }
}
//+------------------------------------------------------------------+
