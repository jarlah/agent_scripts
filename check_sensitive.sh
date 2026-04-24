#!/bin/bash

# Scans a directory for obviously sensitive files and prompts the user
# to confirm before the directory is mounted into the Claude container.
#
# Usage: check_sensitive_files <dir>
# Returns 0 if safe to proceed (clean, or user confirmed), non-zero otherwise.

check_sensitive_files() {
    local dir="$1"

    if [ -z "$dir" ] || [ ! -d "$dir" ]; then
        echo "check_sensitive_files: ugyldig katalog: ${dir:-<tom>}" >&2
        return 2
    fi

    # Directory names to skip entirely while scanning.
    local prune_dirs=(
        .git node_modules vendor target build dist
        .venv venv .tox .next .cache __pycache__
    )

    # Filename / glob patterns considered sensitive.
    local sensitive_names=(
        ".env" ".env.*"
        ".netrc" ".pgpass" ".git-credentials"
        ".npmrc" ".pypirc"
        "id_rsa" "id_dsa" "id_ecdsa" "id_ed25519"
        "*.pem" "*.key" "*.p12" "*.pfx" "*.keystore" "*.jks"
        "credentials" "credentials.json"
        "secrets.yml" "secrets.yaml" "secrets.json"
        "service-account*.json" "*-key.json"
    )

    # Filenames that match a sensitive pattern but are safe to ignore.
    local allowlist_names=(
        ".env.example" ".env.sample" ".env.template"
        ".env.dist" ".env.defaults"
    )

    local find_args=(
        "$dir"
        -maxdepth 4
    )

    # Prune common vendor/build directories.
    local first=1
    find_args+=( \( )
    for d in "${prune_dirs[@]}"; do
        if [ $first -eq 1 ]; then
            find_args+=( -name "$d" )
            first=0
        else
            find_args+=( -o -name "$d" )
        fi
    done
    find_args+=( \) -prune -o )

    # Match any sensitive filename pattern.
    find_args+=( -type f \( )
    first=1
    for pat in "${sensitive_names[@]}"; do
        if [ $first -eq 1 ]; then
            find_args+=( -name "$pat" )
            first=0
        else
            find_args+=( -o -name "$pat" )
        fi
    done
    find_args+=( \) -print )

    local matches=()
    while IFS= read -r path; do
        local base="${path##*/}"
        local skip=0
        for allow in "${allowlist_names[@]}"; do
            if [ "$base" = "$allow" ]; then
                skip=1
                break
            fi
        done
        [ $skip -eq 0 ] && matches+=("$path")
    done < <(find "${find_args[@]}" 2>/dev/null)

    if [ ${#matches[@]} -eq 0 ]; then
        return 0
    fi

    echo >&2
    echo "Advarsel: fant filer som ser sensitive ut i $dir:" >&2
    printf '  %s\n' "${matches[@]}" >&2
    echo >&2
    echo "Disse filene blir eksponert for Claude inne i containeren." >&2

    if [ ! -t 0 ]; then
        echo "Ingen TTY — avbryter for sikkerhets skyld. Bruk -r for read-only eller fjern filene." >&2
        return 1
    fi

    local reply
    read -r -p "Fortsette likevel? [y/N] " reply </dev/tty
    case "$reply" in
        y|Y|yes|YES) return 0 ;;
        *) echo "Avbrutt." >&2; return 1 ;;
    esac
}
