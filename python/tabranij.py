"""
TABRANIJ (Grafik Tabranij) Python Quantitative Engine
Genesis Riwayat Angka Faktual Informasi Keuangan
Author: Surgas (2026)
"""

from typing import Dict, Union
import numpy as np
import pandas as pd


class Tabranij:
    """
    Kelas representasi ontologi 8 unsur Tabranij untuk 1 lilin harga.
    """
    def __init__(self, tinggi: float, awal: float, inti: float, rendah: float):
        self.T = float(tinggi)      # Tinggi (High)
        self.Awal = float(awal)     # Awal (Open)
        self.I = float(inti)        # Inti (Close / Live Price)
        self.R = float(rendah)      # Rendah (Low)

        # 4 Unsur Turunan
        self.A = max(self.Awal, self.I)              # Atas (Tepi atas Neto)
        self.B = min(self.Awal, self.I)              # Bawah (Tepi bawah Neto)
        self.N = abs(self.I - self.Awal)             # Neto (Tubuh Kristal)
        self.J = self.T - self.R                     # Julat (Gross Volatility)

        # Jarak Ekor Penolakan
        self.ekor_atas = self.T - self.A             # Penolakan Penjual
        self.ekor_bawah = self.B - self.R            # Penyerapan Pembeli

        # Metrik Kuantitatif
        self.efisiensi_neto = (self.N / self.J) if self.J > 0 else 0.0
        self.rasio_penolakan_atas = (self.ekor_atas / self.J) if self.J > 0 else 0.0
        self.rasio_penolakan_bawah = (self.ekor_bawah / self.J) if self.J > 0 else 0.0
        self.asimetri_tekanan = ((self.ekor_atas - self.ekor_bawah) / self.J) if self.J > 0 else 0.0
        self.is_naik = self.I >= self.Awal

    def to_dict(self) -> Dict[str, Union[float, bool]]:
        return {
            "T": self.T,
            "A": self.A,
            "B": self.B,
            "R": self.R,
            "Awal": self.Awal,
            "N": self.N,
            "I": self.I,
            "J": self.J,
            "Ekor_Atas": self.ekor_atas,
            "Ekor_Bawah": self.ekor_bawah,
            "Efisiensi_Neto": self.efisiensi_neto,
            "Rasio_Atas": self.rasio_penolakan_atas,
            "Rasio_Bawah": self.rasio_penolakan_bawah,
            "Asimetri_Tekanan": self.asimetri_tekanan,
            "Is_Naik": self.is_naik,
        }

    def __repr__(self) -> str:
        arah = "HIJAU (Naik)" if self.is_naik else "MERAH (Turun)"
        return (
            f"<Tabranij T={self.T:.2f} A={self.A:.2f} B={self.B:.2f} R={self.R:.2f} "
            f"Awal={self.Awal:.2f} N={self.N:.2f} I={self.I:.2f} J={self.J:.2f} "
            f"Efisiensi={self.efisiensi_neto*100:.1f}% Arah={arah}>"
        )


def compute_tabranij_df(df: pd.DataFrame, 
                        col_high="High", 
                        col_open="Open", 
                        col_close="Close", 
                        col_low="Low") -> pd.DataFrame:
    """
    Menghitung seluruh variabel Tabranij untuk seluruh baris DataFrame secara tervektorisasi.
    """
    res = df.copy()
    T = res[col_high]
    Awal = res[col_open]
    I = res[col_close]
    R = res[col_low]

    res["Tabranij_T"] = T
    res["Tabranij_Awal"] = Awal
    res["Tabranij_I"] = I
    res["Tabranij_R"] = R

    res["Tabranij_A"] = np.maximum(Awal, I)
    res["Tabranij_B"] = np.minimum(Awal, I)
    res["Tabranij_N"] = (I - Awal).abs()
    res["Tabranij_J"] = T - R

    res["Tabranij_Ekor_Atas"] = res["Tabranij_T"] - res["Tabranij_A"]
    res["Tabranij_Ekor_Bawah"] = res["Tabranij_B"] - res["Tabranij_R"]

    julat_safe = np.where(res["Tabranij_J"] > 0, res["Tabranij_J"], np.nan)
    res["Tabranij_Efisiensi_Neto"] = res["Tabranij_N"] / julat_safe
    res["Tabranij_Rasio_Atas"] = res["Tabranij_Ekor_Atas"] / julat_safe
    res["Tabranij_Rasio_Bawah"] = res["Tabranij_Ekor_Bawah"] / julat_safe
    res["Tabranij_Asimetri"] = (res["Tabranij_Ekor_Atas"] - res["Tabranij_Ekor_Bawah"]) / julat_safe

    return res.fillna(0.0)
