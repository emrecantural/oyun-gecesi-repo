#!/usr/bin/env bash
# Komutu çalıştırır; başarısızsa çıktının ilgili satırlarını hata notu olarak yazar
# (Actions günlüklerine API'den erişilemediği için).
set +e
cikti=$("$@" 2>&1)
kod=$?
echo "$cikti"
if [ $kod -ne 0 ]; then
  echo "$cikti" | grep -E "error|Error|FAILED|Exception|failed|Some tests|\[E\]|✖|Expected|Actual|\.dart:[0-9]+" | head -40 | while IFS= read -r satir; do
    echo "::error::${satir}"
  done
fi
if [ $kod -ne 0 ]; then
  # Gradle: "What went wrong" bloğu ve nedeni
  echo "$cikti" | grep -A12 "What went wrong" | head -30 | while IFS= read -r satir; do
    echo "::error::${satir}"
  done
  echo "$cikti" | grep -iE "minSdk|manifest merger|Could not (find|resolve|get)|requires|incompatible|namespace|Duplicate class" | head -15 | while IFS= read -r satir; do
    echo "::error::${satir}"
  done
fi
exit $kod
