#!/bin/bash


# Ukol lekce 6


LOG_DESTINATION="stdout"
LOG_FILE=""
EXIT_CODE=0

DO_LIST=0
DO_UPGRADE=0
DO_SYMLINK=0
DO_LINK=0
DO_REGEX=0

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

show_help() {
    cat <<EOF
Použití: $0 [volby]

Volby (mohou se kombinovat):
  -h, --help        Zobrazí tuto nápovědu
  -a                Vypíše balíčky, které mají dostupný update (APT)
  -u                Provede update/upgrade balíčků (APT)
  -s                Vytvoří soft link /bin/linux_cli na tento skript
  -l                Interaktivně vytvoří link (soft/hard) dle zadání uživatele
  -r                Najde soubory obsahující písmena 'b','e','a','e' v tomto pořadí (b.*e.*a.*e)
  -f SOUBOR         Logování do souboru SOUBOR (pokud existuje, bude se appendovat)

Příklady:
  $0 -a
  $0 -a -f log_output.txt
  $0 -a -s -u
EOF
}

nastav_log_soubor() {
    local file="$1"

    if [ -z "$file" ]; then
        logError "Nebyl zadán název log souboru za parametrem -f."
        return 1
    fi

    if [ -e "$file" ]; then
        if [ -w "$file" ]; then
            LOG_DESTINATION="file"
            LOG_FILE="$file"
            log "Log soubor '$file' existuje, budu zapisovat (append)."
        else
            logError "Log soubor '$file' existuje, ale není zapisovatelný."
            return 1
        fi
    else
        touch "$file" 2>/dev/null
        if [ $? -ne 0 ]; then
            logError "Nepodařilo se vytvořit log soubor '$file'."
            return 1
        fi
        LOG_DESTINATION="file"
        LOG_FILE="$file"
        log "Log soubor '$file' byl vytvořen."
    fi

    return 0
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
    return 0
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
    return 0
}

vytvor_symlink_do_bin() {
    local script_path
    script_path="$(realpath "$0")"
    local target="/bin/linux_cli"

    if [ ! -w /bin ]; then
        logError "Nemám právo zapisovat do /bin. Spusť skript pomocí sudo."
        return 1
    fi

    if [ -L "$target" ]; then
        local current_target
        current_target="$(readlink "$target")"
        if [ "$current_target" = "$script_path" ]; then
            log "Symlink $target již existuje a ukazuje na tento skript."
            return 0
        else
            logError "Symlink $target již existuje, ale ukazuje na '$current_target'."
            return 1
        fi
    elif [ -e "$target" ]; then
        logError "$target již existuje a není to symlink."
        return 1
    fi

    ln -s "$script_path" "$target"
    if [ $? -eq 0 ]; then
        log "Symlink $target -> $script_path byl vytvořen."
        return 0
    else
        logError "Nepodařilo se vytvořit symlink $target."
        return 1
    fi
}

vytvor_link() {
    read -rp "Zadej zdroj (existing soubor/adresář): " src
    read -rp "Zadej cílovou cestu (jméno linku): " dest
    read -rp "Typ linku [soft/hard]: " typ

    if [ ! -e "$src" ]; then
        logError "Zdroj '$src' neexistuje."
        return 1
    fi

    if [ -e "$dest" ] || [ -L "$dest" ]; then
        logError "Cílový soubor '$dest' již existuje."
        return 1
    fi

    case "$typ" in
        soft|symbolic)
            ln -s "$src" "$dest" 2>/dev/null
            if [ $? -eq 0 ]; then
                log "Soft link vytvořen: $dest -> $src"
                return 0
            else
                logError "Nepodařilo se vytvořit soft link."
                return 1
            fi
            ;;
        hard)
            ln "$src" "$dest" 2>/dev/null
            if [ $? -eq 0 ]; then
                log "Hard link vytvořen: $dest -> $src"
                return 0
            else
                logError "Nepodařilo se vytvořit hard link."
                return 1
            fi
            ;;
        *)
            logError "Neznámý typ linku: $typ (použij 'soft' nebo 'hard')."
            return 1
            ;;
    esac
}

najdi_soubory_beae() {
    read -rp "Zadej adresář, odkud hledat (výchozí je aktuální .): " dir
    dir="${dir:-.}"

    if [ ! -d "$dir" ]; then
        logError "'$dir' není adresář."
        return 1
    fi

    log "Hledám soubory v '$dir', které obsahují vzor b.*e.*a.*e ..."
    find "$dir" -type f -exec grep -lE 'b.*e.*a.*e' {} \; 2>/dev/null
    return 0
}

parse_args() {
    while [ $# -gt 0 ]; do
        case "$1" in
            -h|--help)
                show_help
                exit 0
                ;;
            -a)
                DO_LIST=1
                ;;
            -u)
                DO_UPGRADE=1
                ;;
            -s)
                DO_SYMLINK=1
                ;;
            -l)
                DO_LINK=1
                ;;
            -r)
                DO_REGEX=1
                ;;
            -f)
                shift
                if [ $# -eq 0 ]; then
                    logError "Za parametrem -f musí následovat název souboru."
                    return 1
                fi
                nastav_log_soubor "$1" || return 1
                ;;
            *)
                logError "Neznámý parametr: $1"
                return 1
                ;;
        esac
        shift
    done
    return 0
}

main() {
    if [ $# -eq 0 ]; then
        show_help
        EXIT_CODE=1
        return
    fi

    parse_args "$@"
    if [ $? -ne 0 ]; then
        return
    fi

    if [ "$DO_LIST" -eq 1 ]; then
        vypsat_updaty || true
    fi

    if [ "$DO_UPGRADE" -eq 1 ]; then
        update_upgrade_balicku || true
    fi

    if [ "$DO_SYMLINK" -eq 1 ]; then
        vytvor_symlink_do_bin || true
    fi

    if [ "$DO_LINK" -eq 1 ]; then
        vytvor_link || true
    fi

    if [ "$DO_REGEX" -eq 1 ]; then
        najdi_soubory_beae || true
    fi
}

main "$@"
exit "$EXIT_CODE"

