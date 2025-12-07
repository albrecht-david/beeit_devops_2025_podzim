#!/bin/bash

# Ukol lekce 8


#========================================
# Globální proměnné
#========================================
LOG_DESTINATION="stdout"
LOG_FILE=""
EXIT_CODE=0

DO_LIST=0
DO_UPGRADE=0
DO_SYMLINK=0
DO_LINK=0
DO_REGEX=0
DO_PROCINFO=0

#========================================
# Log funkce
#========================================
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

    if [ "$EXIT_CODE" -eq 0 ]; then
        EXIT_CODE=1
    fi

    if [ "$LOG_DESTINATION" = "file" ] && [ -n "$LOG_FILE" ]; then
        echo "$ts [ERROR] $msg" >> "$LOG_FILE"
    else
        echo "$ts [ERROR] $msg" >&2
    fi
}

#========================================
# HELP
#========================================
show_help() {
    cat <<EOF
Použití: $0 [volby]

Volby (mohou se kombinovat):
  -h, --help     Zobrazí tuto nápovědu
  -a             Vypíše balíčky, které mají dostupný update (APT)
  -u             Provede update/upgrade balíčků (APT)
  -s             Vytvoří soft link /bin/linux_cli na tento skript
  -l             Interaktivně vytvoří link (soft/hard)
  -r             Najde soubory s obsahem b.*e.*a.*e
  -p             Zobrazí informace o procesu (název, PID, PPID, niceness, priorita, počet procesů)
  -f SOUBOR      Logování do souboru (append)

Pokud skript spustíš BEZ parametrů → zobrazí se MENU.

Příklady:
  $0 -a
  $0 -a -f log.txt
  $0 -a -u -s
  $0 -p
EOF
}

#========================================
# Nastavení log souboru (-f)
#========================================
nastav_log_soubor() {
    local file="$1"

    if [ -z "$file" ]; then
        logError "Za -f musí být uveden název souboru."
        return 1
    fi

    if [ -e "$file" ]; then
        if [ -w "$file" ]; then
            LOG_DESTINATION="file"
            LOG_FILE="$file"
            log "Log soubor '$file' existuje, zapisuji append."
        else
            logError "Do souboru '$file' nelze zapisovat."
            return 1
        fi
    else
        touch "$file" 2>/dev/null
        if [ $? -ne 0 ]; then
            logError "Nelze vytvořit soubor '$file'."
            return 1
        fi
        LOG_DESTINATION="file"
        LOG_FILE="$file"
        log "Log soubor '$file' byl vytvořen."
    fi

    return 0
}

#========================================
# Funkce: vypsat APT updaty
#========================================
vypsat_updaty() {
    if ! command -v apt >/dev/null 2>&1; then
        logError "APT není dostupný."
        return 1
    fi

    log "Provádím apt update..."
    sudo apt update >/tmp/linux_cli_apt.log 2>&1
    if [ $? -ne 0 ]; then
        logError "apt update selhal."
        return 1
    fi

    log "Seznam upgradovatelných balíků:"
    apt list --upgradable 2>/dev/null
    return 0
}

#========================================
# Funkce: apt update + upgrade
#========================================
update_upgrade_balicku() {
    if ! command -v apt >/dev/null 2>&1; then
        logError "APT není dostupný."
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

    log "APT upgrade dokončen."
    return 0
}

#========================================
# Funkce: symlink /bin/linux_cli
#========================================
vytvor_symlink_do_bin() {
    local script_path
    script_path="$(realpath "$0")"
    local target="/bin/linux_cli"

    if [ ! -w /bin ]; then
        logError "Chybí práva do /bin (spusť pomocí sudo)."
        return 1
    fi

    if [ -L "$target" ]; then
        local current_target
        current_target="$(readlink "$target")"
        if [ "$current_target" = "$script_path" ]; then
            log "Symlink již existuje a ukazuje na tento skript."
            return 0
        else
            logError "$target existuje a ukazuje na '$current_target'."
            return 1
        fi
    fi

    if [ -e "$target" ]; then
        logError "$target existuje a není to symlink."
        return 1
    fi

    ln -s "$script_path" "$target"
    if [ $? -eq 0 ]; then
        log "Symlink vytvořen: $target -> $script_path"
        return 0
    fi

    logError "Nepodařilo se vytvořit symlink."
    return 1
}

#========================================
# Funkce: interaktivní link
#========================================
vytvor_link() {
    read -rp "Zadej zdroj: " src
    read -rp "Zadej cíl: " dest
    read -rp "Typ [soft/hard]: " typ

    if [ ! -e "$src" ]; then
        logError "Zdroj neexistuje."
        return 1
    fi

    if [ -e "$dest" ] || [ -L "$dest" ]; then
        logError "Cílový soubor '$dest' již existuje."
        return 1
    fi

    case "$typ" in
        soft)
            if ln -s "$src" "$dest"; then
                log "Soft link vytvořen: $dest -> $src"
            else
                logError "Chyba při tvorbě soft linku."
            fi
            ;;
        hard)
            if ln "$src" "$dest"; then
                log "Hard link vytvořen: $dest -> $src"
            else
                logError "Chyba při tvorbě hard linku."
            fi
            ;;
        *)
            logError "Typ musí být soft/hard."
            return 1
            ;;
    esac
}

#========================================
# Funkce: regex find b.*e.*a.*e
#========================================
najdi_soubory_beae() {
    read -rp "Hledat v adresáři (default .): " dir
    dir="${dir:-.}"

    if [ ! -d "$dir" ]; then
        logError "Není adresář: $dir"
        return 1
    fi

    log "Hledám soubory s obsahem b.*e.*a.*e v '$dir'..."
    find "$dir" -type f -exec grep -lE 'b.*e.*a.*e' {} \; 2>/dev/null
}

#========================================
# Funkce: INFO O PROCESU (PID, PPID, název procesu, niceness, priorita, počet procesů)
#========================================
zobraz_info_procesu() {
    local pid="$$"
    local ppid="$PPID"
    local priority="N/A"
    local niceness="N/A"
    local procname="N/A"
    local total_procs="N/A"

    if command -v ps >/dev/null 2>&1; then
        priority="$(ps -p "$pid" -o pri= | awk '{print $1}')"
        niceness="$(ps -p "$pid" -o ni=  | awk '{print $1}')"
        procname="$(ps -p "$pid" -o comm= 2>/dev/null)"
        total_procs="$(ps -e --no-headers | wc -l)"
    else
        logError "Příkaz 'ps' není dostupný."
        return 1
    fi

    echo "Informace o procesu:"
    echo "  Název procesu         : $procname"
    echo "  PID aktuálního procesu: $pid"
    echo "  PID rodičovského proc.: $ppid"
    echo "  Priorita (PRI)         : $priority"
    echo "  Niceness (NI)          : $niceness"
    echo "  Celkový počet procesů  : $total_procs"

    log "Zobrazeny informace o procesu (NAME=$procname, PID=$pid, PPID=$ppid, PRI=$priority, NI=$niceness, TOTAL=$total_procs)."
}

#========================================
# MENU režim
#========================================
menu() {
    while true; do
        echo ""
        echo "====== MENU linux_cli ======"
        echo "1) Vypsat balíčky k upgradu"
        echo "2) Provest update/upgrade"
        echo "3) Vytvořit symlink /bin/linux_cli"
        echo "4) Vytvořit link (soft/hard)"
        echo "5) Regex hledání b.*e.*a.*e"
        echo "6) Info o procesu (PID, PPID, název, priorita, niceness)"
        echo "q) Konec"
        echo "=============================="
        read -rp "Volba: " v

        case "$v" in
            1) vypsat_updaty ;;
            2) update_upgrade_balicku ;;
            3) vytvor_symlink_do_bin ;;
            4) vytvor_link ;;
            5) najdi_soubory_beae ;;
            6) zobraz_info_procesu ;;
            q) break ;;
            *) echo "Neplatná volba" ;;
        esac
    done
}

#========================================
# Zpracování parametrů
#========================================
parse_args() {
    while [ $# -gt 0 ]; do
        case "$1" in
            -h|--help) show_help; exit 0 ;;
            -a) DO_LIST=1 ;;
            -u) DO_UPGRADE=1 ;;
            -s) DO_SYMLINK=1 ;;
            -l) DO_LINK=1 ;;
            -r) DO_REGEX=1 ;;
            -p) DO_PROCINFO=1 ;;
            -f)
                shift
                nastav_log_soubor "$1" || return 1
                ;;
            *)
                logError "Neznámý parametr: $1"
                return 1
                ;;
        esac
        shift
    done
}

#========================================
# MAIN
#========================================
main() {
    if [ $# -eq 0 ]; then
        menu
        return
    fi

    parse_args "$@" || return

    [ "$DO_LIST" -eq 1 ]     && vypsat_updaty
    [ "$DO_UPGRADE" -eq 1 ]  && update_upgrade_balicku
    [ "$DO_SYMLINK" -eq 1 ]  && vytvor_symlink_do_bin
    [ "$DO_LINK" -eq 1 ]     && vytvor_link
    [ "$DO_REGEX" -eq 1 ]    && najdi_soubory_beae
    [ "$DO_PROCINFO" -eq 1 ] && zobraz_info_procesu
}

#========================================
main "$@"
exit "$EXIT_CODE"

