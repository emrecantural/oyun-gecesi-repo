#!/usr/bin/env python3
"""İçerik onay masasından gelen kararları CSV'lere işler.

Kullanım: onay_uygula.py <karar_klasoru> [editor_adi]
Klasörde oyun başına bir JSON bulunur (onay/<oyun>.json): {"d": {"<id>": "o"|"r"}, "e": {"<id>": "<düzeltilmiş metin>"}}
(ArtifactData çıktısı "data" altında da olabilir). 'o' -> durum=onayli, 'r' -> durum=reddedildi;
her ikisinde editor alanı doldurulur. Karar verilmeyen satır 'taslak' kalır ve pakete girmez.
"""
import csv
import glob
import json
import os
import sys

ICERIK = os.path.join(os.path.dirname(__file__), "..", "assets", "icerik")


def kararlari_oku(klasor):
    d, e = {}, {}
    for f in glob.glob(os.path.join(klasor, "**", "*.json"), recursive=True):
        j = json.load(open(f, encoding="utf-8"))
        j = j.get("data", j) if isinstance(j.get("data"), dict) else j
        d.update(j.get("d", {}))
        e.update(j.get("e", {}))
    return d, e


def main():
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    editor = sys.argv[2] if len(sys.argv) > 2 else "editor"
    d, e = kararlari_oku(sys.argv[1])
    sayac = {"onayli": 0, "reddedildi": 0, "duzeltildi": 0}
    bulunan = set()
    for f in sorted(glob.glob(os.path.join(ICERIK, "*.csv"))):
        with open(f, "rb") as fh:
            satir_sonu = "\r\n" if b"\r\n" in fh.read(4096) else "\n"
        with open(f, encoding="utf-8", newline="") as fh:
            okuyucu = csv.DictReader(fh)
            alanlar = okuyucu.fieldnames
            satirlar = list(okuyucu)
        degisti = False
        for r in satirlar:
            k = d.get(r["id"])
            if k not in ("o", "r"):
                continue
            bulunan.add(r["id"])
            r["durum"] = "onayli" if k == "o" else "reddedildi"
            r["editor"] = editor
            sayac[r["durum"]] += 1
            yeni = e.get(r["id"])
            if yeni and yeni != r["metin"]:
                r["metin"] = yeni
                sayac["duzeltildi"] += 1
            degisti = True
        if degisti:
            with open(f, "w", encoding="utf-8", newline="") as fh:
                w = csv.DictWriter(fh, fieldnames=alanlar, lineterminator=satir_sonu)
                w.writeheader()
                w.writerows(satirlar)
    kayip = [i for i in d if d[i] in ("o", "r") and i not in bulunan]
    print(sayac)
    if kayip:
        print("CSV'de bulunamayan kimlikler:", kayip[:10], "...")


if __name__ == "__main__":
    main()
