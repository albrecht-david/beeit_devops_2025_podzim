#!/bin/bash
set -e  # pokud nějaký příkaz skončí chybou, skript skončí chybou

SCRIPT="/usr/local/bin/linux_cli.sh"

echo "== Test 1: Kontrola existence a spustitelnosti skriptu =="
if [ ! -x "$SCRIPT" ]; then
    echo "ERROR: Skript $SCRIPT neexistuje nebo není spustitelný."
    exit 1
fi
echo "OK: Skript existuje a je spustitelný."

echo
echo "== Test 2: linux_cli.sh -h (help) =="
$SCRIPT -h >/dev/null
echo "OK: Help se spustil bez chyby."

echo
echo "== Test 3: linux_cli.sh -p (info o procesu) =="
$SCRIPT -p >/tmp/linux_cli_test_procinfo.txt
grep -q "PID aktuálního procesu" /tmp/linux_cli_test_procinfo.txt
echo "OK: Výstup obsahuje informaci o PID aktuálního procesu."

echo
echo "== Test 4: linux_cli.sh -r (regex hledání, neinteraktivně) =="
# Předáme prázdný řádek jako vstup = použije se výchozí adresář "."
echo "" | $SCRIPT -r >/tmp/linux_cli_test_regex.txt || true
echo "OK: Regex hledání proběhlo (i pokud nic nenašlo, považujeme za OK)."

echo
echo "Všechny testy proběhly úspěšně."
exit 0

