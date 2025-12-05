#!/bin/bash


LOG_DESTINATION="stdout"
LOG_FILE=""


log() {
    local msg="$1"
    local ts
    ts="$(date '+%Y-%m-%d %H:%M:%S')"

    if [ "$LOG_DESTINATION" = "file" ] && [ -n "$LOG_FILE" ]; then
        echo "$ts [INFO] $msg" >> "$LOG_FILE"
    else
        echo "$ts [INFO] $msg"
    fi
}

logError() {
    local msg="$1"
    local ts
    ts="$(date '+%Y-%m-%d %H:%M:%S')"

    if [ "$LOG_DESTINATION" = "file" ] && [ -n "$LOG_FILE" ]; then
        echo "$ts [ERROR] $msg" >> "$LOG_FILE"
    else
        echo "$ts [ERROR] $msg" >&2
    fi
}

nastav_logovani() {
    echo "Zvol, kam se má logovat:"
    echo "1) STDOUT"
    echo "2) Soubor"
    read -rp "Volba [1/2]: " volba

    case "$volba" in
        2)
            read -rp "Zadej cestu k log souboru (např. /tmp/linux_cli.log): " LOG_FILE
            if [ -z "$LOG_FILE" ]; then
                echo "Nebyla zadána cesta, používám STDOUT."
                LOG_DESTINATION="stdout"
            else
                LOG_DESTINATION="file"
                log "Logování nastaveno do souboru: $LOG_FILE"
            fi
            ;;
        *)
            LOG_DESTINATION="stdout"
            log "Logování nastaveno na STDOUT."
            ;;
    esac
}


show_help() {
    cat <<EOF
Použití: $0 [volby]

Volby:
  -h, --help        Zobrazí tuto nápovědu

Po spuštění skriptu bez argumentů:
  - skript se zeptá, kam logovat (STDOUT / soubor)
  - zobrazí interaktivní menu:

    1) Vytvořit link (soft/hard) dle zadání uživatele
    2) Vypsat balíčky, které mají dostupný update (APT)
    3) Provést update/upgrade balíčků (APT)
    4) Najít soubory obsahující písmena 'b', 'e', 'a', 'e' v tomto pořadí
    5) Vytvořit symlink /bin/linux_cli -> tento skript
    q) Konec

Příklady:
  $0 -h
  $0
EOF
}


vytvor_link() {
    read -rp "Zadej zdroj (existing soubor/adresář): " src
    read -rp "Zadej cílovou cestu (jméno linku): " dest
    read -rp "Typ linku [soft/hard]: " typ

    if [ ! -e "$src" ]; then
        logError "Zdroj '$src' neexistuje."
        return 1
    fi

    case "$typ" in
        soft|symbolic)
            ln -s "$src" "$dest" 2>/dev/null
            if [ $? -eq 0 ]; then
                log "Soft link vytvořen: $dest -> $src"
            else
                logError "Nepodařilo se vytvořit soft link."
            fi
            ;;
        hard)
            ln "$src" "$dest" 2>/dev/null
            if [ $? -eq 0 ]; then
                log "Hard link vytvořen: $dest -> $src"
            else
                logError "Nepodařilo se vytvořit hard link."
            fi
            ;;
        *)
            logError "Neznámý typ linku: $typ (použij 'soft' nebo 'hard')."
            return 1
            ;;
    esac
}


vypsat_updaty() {
    if ! command -v apt >/dev/null 2>&1; then
        logError "Tato funkce je připravena pro systémy s APT (Debian/Ubuntu)."
        return 1
    fi

    log "Aktualizuji seznam balíčků (apt update)..."
    sudo apt update >/tmp/linux_cli_apt_update.log 2>&1
    if [ $? -ne 0 ]; then
        logError "apt update selhal. Podrobnosti jsou v /tmp/linux_cli_apt_update.log."
        return 1
    fi

    log "Vypisuji balíčky, které mají dostupný update:"
    apt list --upgradable 2>/dev/null
}


update_upgrade_balicku() {
    if ! command -v apt >/dev/null 2>&1; then
        logError "Tato funkce je připravena pro systémy s APT (Debian/Ubuntu)."
        return 1
    fi

    log "Spouštím apt update..."
    sudo apt update
    if [ $? -ne 0 ]; then
        logError "apt update selhal."
        return 1
    fi

    log "Spouštím apt upgrade..."
    sudo apt upgrade -y
    if [ $? -ne 0 ]; then
        logError "apt upgrade selhal."
        return 1
    fi

    log "Update/upgrade balíčků úspěšně dokončen."
}


vytvor_symlink_do_bin() {
    local script_path
    script_path="$(realpath "$0")"

    if [ ! -w /bin ]; then
        logError "Nemám právo zapisovat do /bin. Spusť skript pomocí sudo."
        return 1
    fi

    ln -sf "$script_path" /bin/linux_cli
    if [ $? -eq 0 ]; then
        log "Symlink /bin/linux_cli -> $script_path vytvořen."
    else
        logError "Nepodařilo se vytvořit symlink /bin/linux_cli."
    fi
}


najdi_soubory_beae() {
    read -rp "Zadej adresář, odkud hledat (výchozí je aktuální .): " dir
    dir="${dir:-.}"

    log "Hledám soubory v '$dir', které obsahují vzor b.*e.*a.*e ..."
    find "$dir" -type f -exec grep -lE 'b.*e.*a.*e' {} \; 2>/dev/null
}


hlavni_menu() {
    while true; do
        echo
        echo "=== linux_cli menu ==="
        echo "1) Vytvořit link (soft/hard)"
        echo "2) Vypsat balíčky s dostupným updatem (APT)"
        echo "3) Update/upgrade balíčků (APT)"
        echo "4) Najít soubory s obsahem 'b.*e.*a.*e'"
        echo "5) Vytvořit symlink /bin/linux_cli na tento skript"
        echo "q) Konec"
        read -rp "Zadej volbu: " choice

        case "$choice" in
            1) vytvor_link ;;
            2) vypsat_updaty ;;
            3) update_upgrade_balicku ;;
            4) najdi_soubory_beae ;;
            5) vytvor_symlink_do_bin ;;
            q|Q)
                log "Ukončuji skript."
                break
                ;;
            *)
                echo "Neplatná volba."
                ;;
        esac
    done
}


if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    show_help
    exit 0
fi


nastav_logovani
hlavni_menu


