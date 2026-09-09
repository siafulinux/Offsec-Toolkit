#!/usr/bin/env bash

###############################################################################
# OffSec-Toolkit
# Version: 3.0.0
#
# Purpose:
#   Installs a practical collection of penetration-testing, security-auditing,
#   OSINT, wireless, password-auditing and web-security tools on Debian-based
#   Linux systems.
#
# Supported:
#   Debian / Ubuntu / Kali / Parrot and compatible Debian-based distributions.
#
# Designed to be:
#   - Idempotent
#   - Environment-aware
#   - Safe to re-run
#   - User-aware when executed through sudo
#   - Able to detect manually installed tools
#   - Friendly to existing Kali / Parrot installations
#   - Conservative with system upgrades
#   - Free from repository modifications
#   - Easy to maintain
#
# Project:
#   OffSec-Toolkit
#
# CLI:
#   OTK
#
# Usage:
#   chmod +x offsec-toolkit.sh
#   ./offsec-toolkit.sh
#
# Options:
#   --upgrade          Allow apt update + dist-upgrade
#   --no-upgrade       Skip all system upgrades
#   --no-wordlists     Skip large wordlist downloads
#   --no-ptf           Skip PenTesters Framework
#   --no-burp          Skip Burp Suite
#   --no-metasploit    Skip Metasploit
#   --no-cron          Do not configure monthly apt updates
#   --help             Display help
#
# IMPORTANT:
#   These tools are intended for systems, networks and applications that you
#   own or are explicitly authorized to test.
#
# OTK NEVER:
#   - Adds Kali repositories to Debian
#   - Adds Parrot repositories to Debian
#   - Replaces existing APT repositories
#   - Installs Kali/Parrot metapackages
#   - Removes existing security tools
#   - Deliberately overwrites existing tool installations
###############################################################################

set -Eeuo pipefail

###############################################################################
# VERSION / IDENTITY
###############################################################################

VERSION="3.0.0"
PROJECT_NAME="OffSec-Toolkit"
CLI_NAME="OTK"
SCRIPT_NAME="$(basename "$0")"

###############################################################################
# COLORS
###############################################################################

RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
MAGENTA='\033[1;35m'
CYAN='\033[1;36m'
WHITE='\033[1;37m'
RESET='\033[0m'
BOLD='\033[1m'

###############################################################################
# CONFIGURATION
###############################################################################

# Conservative default:
# Full system upgrades require --upgrade.
NO_UPGRADE=true

NO_WORDLISTS=false
NO_PTF=false
NO_BURP=false
NO_METASPLOIT=false
NO_CRON=false

INSTALL_BASE="/opt/security-tools"
WORDLIST_DIR="/usr/share/wordlists"

LOG_DIR="/var/log"
LOG_FILE="${LOG_DIR}/offsec-toolkit-install.log"

###############################################################################
# SYSTEM INFORMATION
###############################################################################

OS_NAME="Unknown"
OS_ID="unknown"
OS_VERSION=""
OS_FAMILY="unknown"

APT_UPDATED=false

###############################################################################
# ORIGINAL USER
###############################################################################

REAL_USER=""
REAL_HOME=""

###############################################################################
# STATUS TRACKING
###############################################################################

declare -a INSTALLED_TOOLS=()
declare -a SKIPPED_TOOLS=()
declare -a FAILED_TOOLS=()
declare -a OPTION_SKIPPED_TOOLS=()

###############################################################################
# LOGGING
###############################################################################

setup_logging() {
    mkdir -p "$LOG_DIR"
    touch "$LOG_FILE"
    chmod 600 "$LOG_FILE"

    exec > >(tee -a "$LOG_FILE") 2>&1
}

###############################################################################
# UI
###############################################################################

banner() {
    clear 2>/dev/null || true

    echo
    echo -e "${RED} ██████╗ ████████╗██╗  ██╗${RESET}"
    echo -e "${GREEN}██╔═══██╗╚══██╔══╝██║ ██╔╝${RESET}"
    echo -e "${YELLOW}██║   ██║   ██║   █████╔╝ ${RESET}"
    echo -e "${BLUE}██║   ██║   ██║   ██╔═██╗ ${RESET}"
    echo -e "${MAGENTA}╚██████╔╝   ██║   ██║  ██╗${RESET}"
    echo -e "${CYAN} ╚═════╝    ╚═╝   ╚═╝  ╚═╝${RESET}"
    echo
    echo -e "${BOLD}${WHITE}             OTK${RESET}"
    echo -e "${BOLD}${WHITE}       OFFSEC-TOOLKIT${RESET}"
    echo -e "${WHITE}          v${VERSION}${RESET}"
    echo
}

section() {
    echo
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${BOLD}${WHITE} $1${RESET}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
}

info() {
    echo -e "${BLUE}[*]${RESET} $1"
}

success() {
    echo -e "${GREEN}[+]${RESET} $1"
}

warning() {
    echo -e "${YELLOW}[!]${RESET} $1"
}

error() {
    echo -e "${RED}[✗]${RESET} $1"
}

step() {
    echo -e "${GREEN}[+]${RESET} ${BOLD}$1${RESET}"
}

skip() {
    echo -e "${CYAN}[=]${RESET} $1"
}

###############################################################################
# ERROR HANDLING
###############################################################################

on_error() {
    local exit_code=$?
    local line_no=$1

    echo
    error "An unexpected error occurred on line ${line_no}."
    error "Exit code: ${exit_code}"
    error "Log file: ${LOG_FILE}"
    exit "$exit_code"
}

trap 'on_error $LINENO' ERR

###############################################################################
# HELP
###############################################################################

show_help() {
    cat <<EOF

${BOLD}${PROJECT_NAME} ${VERSION}${RESET}
${BOLD}CLI:${RESET} ${CLI_NAME}

A Debian-based offensive-security toolkit installer.

Usage:
    sudo ./${SCRIPT_NAME} [options]

Options:

    --upgrade
        Allow OTK to run:
            apt-get update
            apt-get dist-upgrade

        This is disabled by default, especially on existing Kali
        and Parrot installations.

    --no-upgrade
        Explicitly disable system upgrades.

    --no-wordlists
        Skip SecLists and additional wordlist downloads.

    --no-ptf
        Skip TrustedSec PenTesters Framework.

    --no-burp
        Skip Burp Suite Community Edition.

    --no-metasploit
        Skip Metasploit Framework.

    --no-cron
        Do not configure the monthly APT update job.

    --help, -h
        Display this help message.

Examples:

    sudo ./${SCRIPT_NAME}

    sudo ./${SCRIPT_NAME} --upgrade

    sudo ./${SCRIPT_NAME} --no-wordlists --no-ptf

    sudo ./${SCRIPT_NAME} --no-burp --no-metasploit

Notes:

    OTK does not modify existing APT repositories.

    OTK checks for tools that are already installed through APT,
    manually installed in PATH, or located in known installation
    directories.

    OTK is designed to install missing components rather than
    duplicate existing installations.

EOF
}

###############################################################################
# ARGUMENT PARSING
###############################################################################

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case "$1" in

            --upgrade)
                NO_UPGRADE=false
                ;;

            --no-upgrade)
                NO_UPGRADE=true
                ;;

            --no-wordlists)
                NO_WORDLISTS=true
                ;;

            --no-ptf)
                NO_PTF=true
                ;;

            --no-burp)
                NO_BURP=true
                ;;

            --no-metasploit)
                NO_METASPLOIT=true
                ;;

            --no-cron)
                NO_CRON=true
                ;;

            --help|-h)
                show_help
                exit 0
                ;;

            *)
                error "Unknown option: $1"
                echo
                show_help
                exit 1
                ;;
        esac

        shift
    done
}

###############################################################################
# USER DETECTION
###############################################################################

determine_real_user() {

    if [[ -n "${SUDO_USER:-}" && "${SUDO_USER}" != "root" ]]; then
        REAL_USER="$SUDO_USER"
    elif [[ "$(id -u)" -ne 0 ]]; then
        REAL_USER="$(id -un)"
    else
        #
        # If somebody runs:
        #
        #     sudo -i
        #     ./offsec-toolkit.sh
        #
        # SUDO_USER may not be available.
        #
        # In that situation we try to identify the login user.
        #
        REAL_USER="${USER:-root}"
    fi

    if ! getent passwd "$REAL_USER" >/dev/null 2>&1; then
        error "Unable to determine user account: ${REAL_USER}"
        exit 1
    fi

    REAL_HOME="$(getent passwd "$REAL_USER" | cut -d: -f6)"

    if [[ -z "$REAL_HOME" || ! -d "$REAL_HOME" ]]; then
        error "Unable to determine home directory for: ${REAL_USER}"
        exit 1
    fi
}

###############################################################################
# ROOT / SUDO
###############################################################################

ensure_root() {

    if [[ "$(id -u)" -eq 0 ]]; then
        return 0
    fi

    if ! command -v sudo >/dev/null 2>&1; then
        error "This script requires root privileges."
        error "sudo is not installed."
        exit 1
    fi

    info "Root privileges are required."
    info "Re-running OTK through sudo..."

    exec sudo -E bash "$0" "$@"
}

###############################################################################
# SYSTEM DETECTION
###############################################################################

detect_system() {

    if [[ ! -f /etc/os-release ]]; then
        error "Unable to identify the operating system."
        exit 1
    fi

    # shellcheck disable=SC1091
    source /etc/os-release

    OS_NAME="${PRETTY_NAME:-Unknown}"
    OS_ID="${ID:-unknown}"
    OS_VERSION="${VERSION_ID:-}"

    case "$OS_ID" in

        debian)
            OS_FAMILY="debian"
            ;;

        ubuntu)
            OS_FAMILY="ubuntu"
            ;;

        kali)
            OS_FAMILY="kali"
            ;;

        parrot)
            OS_FAMILY="parrot"
            ;;

        linuxmint|pop)
            OS_FAMILY="debian-derived"
            ;;

        *)
            if command -v apt-get >/dev/null 2>&1; then
                OS_FAMILY="debian-compatible"

                warning "Unrecognized Debian-based distribution:"
                warning "  ${OS_NAME}"
                warning "Continuing because apt-get is available."
            else
                error "This installer requires a Debian-based distribution."
                exit 1
            fi
            ;;
    esac
}

###############################################################################
# ENVIRONMENT SUMMARY
###############################################################################

show_environment() {

    section "ENVIRONMENT"

    echo
    echo " Distribution : ${OS_NAME}"
    echo " User         : ${REAL_USER}"
    echo " Install base : ${INSTALL_BASE}"
    echo " Wordlists    : ${WORDLIST_DIR}"

    if [[ "$NO_UPGRADE" == true ]]; then
        echo " System mode  : Conservative"
    else
        echo " System mode  : Upgrade enabled"
    fi

    echo

    case "$OS_FAMILY" in

        kali)
            warning "Existing Kali environment detected."
            echo
            echo " OTK will:"
            echo "   ✓ Detect existing tools"
            echo "   ✓ Install only missing components"
            echo "   ✓ Preserve existing installations"
            echo "   ✓ Preserve existing repositories"
            echo "   ✓ Avoid Kali metapackages"
            echo
            echo " OTK will NOT:"
            echo "   ✗ Add repositories"
            echo "   ✗ Replace Kali configuration"
            echo "   ✗ Remove existing tools"
            echo "   ✗ Automatically dist-upgrade"
            ;;

        parrot)
            warning "Existing Parrot environment detected."
            echo
            echo " OTK will:"
            echo "   ✓ Detect existing tools"
            echo "   ✓ Install only missing components"
            echo "   ✓ Preserve existing installations"
            echo "   ✓ Preserve existing repositories"
            echo
            echo " OTK will NOT:"
            echo "   ✗ Add repositories"
            echo "   ✗ Replace Parrot configuration"
            echo "   ✗ Remove existing tools"
            echo "   ✗ Automatically dist-upgrade"
            ;;

        *)
            info "Debian-compatible environment detected."
            echo
            echo " OTK will install missing components without replacing"
            echo " existing tools or APT repositories."
            ;;
    esac

    echo

    if [[ "$NO_UPGRADE" == true ]]; then
        warning "Full system upgrades are disabled by default."
        info "Use --upgrade if you explicitly want a system upgrade."
    fi
}

###############################################################################
# APT
###############################################################################

apt_update() {

    if [[ "$APT_UPDATED" == true ]]; then
        return 0
    fi

    step "Updating package lists..."

    if apt-get update; then
        APT_UPDATED=true
        success "Package lists updated."
        return 0
    fi

    error "apt update failed."
    return 1
}

###############################################################################
# PACKAGE / COMMAND DETECTION
###############################################################################

package_installed() {

    local package="$1"

    dpkg-query \
        -W \
        -f='${Status}' \
        "$package" 2>/dev/null |
        grep -q "install ok installed"
}

command_exists() {

    local command_name="$1"

    command -v "$command_name" >/dev/null 2>&1
}

path_exists_executable() {

    local path="$1"

    [[ -x "$path" ]]
}

tool_already_available() {

    local command_name="${1:-}"
    shift || true

    if [[ -n "$command_name" ]] && command_exists "$command_name"; then
        return 0
    fi

    local path

    for path in "$@"; do
        if path_exists_executable "$path"; then
            return 0
        fi
    done

    return 1
}

###############################################################################
# PACKAGE INSTALLATION
###############################################################################

install_package() {

    local package="$1"
    local display_name="${2:-$package}"
    local command_name="${3:-}"

    shift 3 || true

    local known_path

    #
    # First check the actual APT package.
    #
    if package_installed "$package"; then

        info "${display_name} is already installed through APT."
        SKIPPED_TOOLS+=("$display_name")
        return 0
    fi

    #
    # Then check for manually installed binaries.
    #
    if [[ -n "$command_name" ]] &&
       command_exists "$command_name"; then

        info "${display_name} already exists in PATH."
        info "Detected: $(command -v "$command_name")"
        SKIPPED_TOOLS+=("$display_name")
        return 0
    fi

    for known_path in "$@"; do

        if path_exists_executable "$known_path"; then

            info "${display_name} already exists."
            info "Detected: ${known_path}"
            SKIPPED_TOOLS+=("$display_name")
            return 0
        fi

    done

    step "Installing ${display_name}..."

    if apt-get install -y "$package"; then

        success "${display_name} installed."
        INSTALLED_TOOLS+=("$display_name")

    else

        error "Failed to install ${display_name}."
        FAILED_TOOLS+=("$display_name")

        #
        # Do NOT abort the entire installer because one package failed.
        #
        return 0
    fi
}

###############################################################################
# SYSTEM UPDATE
###############################################################################

update_system() {

    if [[ "$NO_UPGRADE" == true ]]; then

        section "SYSTEM UPDATE"

        info "Full system upgrade is disabled."
        info "OTK will install required packages without performing"
        info "apt-get dist-upgrade."

        return 0
    fi

    section "SYSTEM UPDATE"

    apt_update || {
        warning "Unable to update package lists."
        warning "Continuing with package installation."
    }

    step "Upgrading installed packages..."

    if apt-get dist-upgrade -y; then
        success "System upgrade completed."
    else
        warning "dist-upgrade encountered an issue."
        warning "Continuing with OTK installation."
    fi

    apt-get autoremove -y || true
}

###############################################################################
# ESSENTIAL PACKAGES
###############################################################################

install_essentials() {

    section "ESSENTIAL PACKAGES"

    apt_update || {
        warning "Package lists could not be refreshed."
        warning "APT installations may fail."
    }

    local packages=(
        ca-certificates
        curl
        wget
        git
        gnupg
        unzip
        zip
        tar
        gzip
        bzip2
        xz-utils
        build-essential
        pkg-config
        software-properties-common
        python3
        python3-pip
        python3-venv
        python3-dev
        pipx
        jq
        net-tools
        iproute2
        dnsutils
        whois
        traceroute
        tcpdump
        lsof
        procps
        psmisc
        tree
        python3-pexpect
    )

    step "Installing common dependencies..."

    local package

    for package in "${packages[@]}"; do

        if package_installed "$package"; then
            continue
        fi

        if apt-get install -y "$package" >/dev/null 2>&1; then
            INSTALLED_TOOLS+=("$package")
        else
            warning "Unable to install dependency: ${package}"
            FAILED_TOOLS+=("$package")
        fi

    done

    success "Essential package check completed."

    #
    # pipx is user-scoped.
    #
    if command -v pipx >/dev/null 2>&1; then

        sudo -u "$REAL_USER" \
            env HOME="$REAL_HOME" \
            pipx ensurepath >/dev/null 2>&1 || true

    fi
}

###############################################################################
# PRIVACY / ANONYMITY
###############################################################################

install_privacy_tools() {

    section "PRIVACY / ANONYMITY"

    install_package \
        "proxychains4" \
        "ProxyChains" \
        "proxychains4" \
        "/usr/bin/proxychains4"

    install_package \
        "tor" \
        "Tor" \
        "tor" \
        "/usr/bin/tor"

    if systemctl list-unit-files 2>/dev/null |
       grep -q '^tor.service'; then

        step "Checking Tor service..."

        if systemctl is-enabled tor >/dev/null 2>&1; then
            info "Tor is already enabled."
        else
            systemctl enable tor >/dev/null 2>&1 || true
        fi

        if systemctl is-active tor >/dev/null 2>&1; then
            info "Tor is already running."
        else
            systemctl start tor >/dev/null 2>&1 || \
                warning "Unable to start Tor automatically."
        fi
    fi
}

###############################################################################
# NETWORK SCANNING
###############################################################################

install_scanning_tools() {

    section "NETWORK SCANNING"

    install_package \
        "nmap" \
        "Nmap" \
        "nmap" \
        "/usr/bin/nmap"

    install_package \
        "masscan" \
        "Masscan" \
        "masscan" \
        "/usr/bin/masscan"

    install_package \
        "nikto" \
        "Nikto" \
        "nikto" \
        "/usr/bin/nikto"

    install_package \
        "gobuster" \
        "GoBuster" \
        "gobuster" \
        "/usr/bin/gobuster"
}

###############################################################################
# METASPLOIT
###############################################################################

install_metasploit() {

    if [[ "$NO_METASPLOIT" == true ]]; then
        info "Metasploit disabled by --no-metasploit."
        OPTION_SKIPPED_TOOLS+=("Metasploit Framework")
        return 0
    fi

    section "METASPLOIT FRAMEWORK"

    if tool_already_available \
        "msfconsole" \
        "/usr/bin/msfconsole" \
        "/opt/metasploit-framework/bin/msfconsole"; then

        info "Metasploit Framework is already installed."
        info "Existing installation detected."
        SKIPPED_TOOLS+=("Metasploit Framework")
        return 0
    fi

    step "Installing Metasploit Framework..."

    local installer
    installer="$(mktemp /tmp/msfinstall.XXXXXX)"

    if curl -fsSL \
        "https://raw.githubusercontent.com/rapid7/metasploit-omnibus/master/config/templates/metasploit-framework-wrappers/msfupdate.erb" \
        -o "$installer"; then

        chmod 755 "$installer"

        if "$installer"; then

            success "Metasploit Framework installed."
            INSTALLED_TOOLS+=("Metasploit Framework")

        else

            error "Metasploit installation failed."
            FAILED_TOOLS+=("Metasploit Framework")

        fi

    else

        error "Unable to download the Metasploit installer."
        FAILED_TOOLS+=("Metasploit Framework")
    fi

    rm -f "$installer"

    if command -v msfdb >/dev/null 2>&1; then

        info "Initializing Metasploit database..."

        msfdb init >/dev/null 2>&1 || \
            warning "Metasploit database initialization returned an error."
    fi
}

###############################################################################
# PASSWORD / HASH AUDITING
###############################################################################

install_password_tools() {

    section "PASSWORD / HASH AUDITING"

    install_package \
        "hashid" \
        "HashID" \
        "hashid" \
        "/usr/bin/hashid"

    install_package \
        "hashcat" \
        "Hashcat" \
        "hashcat" \
        "/usr/bin/hashcat"

    install_package \
        "john" \
        "John the Ripper" \
        "john" \
        "/usr/bin/john"

    install_package \
        "hydra" \
        "THC Hydra" \
        "hydra" \
        "/usr/bin/hydra"
}

###############################################################################
# WEB SECURITY
###############################################################################

install_web_tools() {

    section "WEB SECURITY"

    install_package \
        "sqlmap" \
        "SQLmap" \
        "sqlmap" \
        "/usr/bin/sqlmap"

    install_burp
}

###############################################################################
# BURP SUITE
###############################################################################

install_burp() {

    if [[ "$NO_BURP" == true ]]; then
        info "Burp Suite disabled by --no-burp."
        OPTION_SKIPPED_TOOLS+=("Burp Suite Community")
        return 0
    fi

    section "BURP SUITE"

    #
    # Check common executable names.
    #
    if command_exists "burpsuite" ||
       command_exists "burpsuite_community"; then

        info "Burp Suite already exists in PATH."
        SKIPPED_TOOLS+=("Burp Suite Community")
        return 0
    fi

    #
    # Check common installation locations.
    #
    if find /opt /usr/local /usr/share \
        -maxdepth 3 \
        -type f \
        \( -iname "BurpSuiteCommunity" \
           -o -iname "burpsuite" \
           -o -iname "burpsuite_community" \) \
        -perm -111 \
        2>/dev/null |
        grep -q .; then

        info "Existing Burp Suite installation detected."
        SKIPPED_TOOLS+=("Burp Suite Community")
        return 0
    fi

    #
    # Current PortSwigger Linux installer.
    #
    local burp_version="2026.8"
    local burp_file="burpsuite_linux_v2026_8.sh"

    local burp_url="https://portswigger.net/burp/releases/download?product=community&version=2026.8&type=Linux"

    step "Downloading Burp Suite Community Edition ${burp_version}..."

    local installer
    installer="$(mktemp "/tmp/${burp_file}.XXXXXX")"

    if ! curl -fL \
        "$burp_url" \
        -o "$installer"; then

        error "Unable to download Burp Suite."
        FAILED_TOOLS+=("Burp Suite Community")
        rm -f "$installer"
        return 0
    fi

    chmod 755 "$installer"

    echo
    warning "The PortSwigger Linux installer is interactive."
    info "The installer will now launch."
    info "Choose the installation location when prompted."
    echo

    step "Launching Burp Suite installer..."

    if "$installer"; then

        success "Burp Suite installer completed."
        INSTALLED_TOOLS+=("Burp Suite Community")

    else

        warning "Burp Suite installer exited with an error."
        FAILED_TOOLS+=("Burp Suite Community")
    fi

    rm -f "$installer"
}

###############################################################################
# WIRELESS / PACKET ANALYSIS
###############################################################################

install_wireless_tools() {

    section "WIRELESS / PACKET ANALYSIS"

    install_package \
        "wireshark" \
        "Wireshark" \
        "wireshark" \
        "/usr/bin/wireshark"

    install_package \
        "tshark" \
        "TShark" \
        "tshark" \
        "/usr/bin/tshark"

    install_package \
        "bettercap" \
        "Bettercap" \
        "bettercap" \
        "/usr/bin/bettercap"

    install_package \
        "aircrack-ng" \
        "Aircrack-ng" \
        "aircrack-ng" \
        "/usr/bin/aircrack-ng"

    install_package \
        "wifite" \
        "Wifite" \
        "wifite" \
        "/usr/bin/wifite"

    #
    # Wireshark group.
    #
    if getent group wireshark >/dev/null 2>&1; then

        if id -nG "$REAL_USER" |
           tr ' ' '\n' |
           grep -qx "wireshark"; then

            info "${REAL_USER} is already a member of the wireshark group."

        else

            if usermod -aG wireshark "$REAL_USER"; then
                success "Added ${REAL_USER} to the wireshark group."
                info "Log out and back in for the group membership to apply."
            else
                warning "Unable to add ${REAL_USER} to the wireshark group."
            fi

        fi
    fi
}

###############################################################################
# OSINT / RECON
###############################################################################

install_osint_tools() {

    section "OSINT / RECONNAISSANCE"

    install_package \
        "recon-ng" \
        "Recon-ng" \
        "recon-ng" \
        "/usr/bin/recon-ng"

    install_sherlock
    install_theharvester
}

###############################################################################
# SHERLOCK
###############################################################################

install_sherlock() {

    if tool_already_available \
        "sherlock" \
        "${REAL_HOME}/.local/bin/sherlock" \
        "/usr/local/bin/sherlock"; then

        info "Sherlock is already installed."
        SKIPPED_TOOLS+=("Sherlock")
        return 0
    fi

    if ! command -v pipx >/dev/null 2>&1; then
        warning "pipx is unavailable. Cannot install Sherlock."
        FAILED_TOOLS+=("Sherlock")
        return 0
    fi

    step "Installing Sherlock..."

    if sudo -u "$REAL_USER" \
        env HOME="$REAL_HOME" \
        pipx install sherlock-project; then

        success "Sherlock installed."
        INSTALLED_TOOLS+=("Sherlock")

    else

        warning "Unable to install Sherlock with pipx."
        FAILED_TOOLS+=("Sherlock")
    fi
}

###############################################################################
# THEHARVESTER
###############################################################################

install_theharvester() {

    if tool_already_available \
        "theHarvester" \
        "theharvester" \
        "${REAL_HOME}/.local/bin/theHarvester" \
        "${REAL_HOME}/.local/bin/theharvester" \
        "/usr/local/bin/theHarvester"; then

        info "theHarvester is already installed."
        SKIPPED_TOOLS+=("theHarvester")
        return 0
    fi

    if ! command -v pipx >/dev/null 2>&1; then
        warning "pipx is unavailable. Cannot install theHarvester."
        FAILED_TOOLS+=("theHarvester")
        return 0
    fi

    step "Installing theHarvester..."

    #
    # Use pipx isolation rather than modifying Debian's system Python.
    #
    if sudo -u "$REAL_USER" \
        env HOME="$REAL_HOME" \
        pipx install theHarvester; then

        success "theHarvester installed."
        INSTALLED_TOOLS+=("theHarvester")

    else

        warning "pipx installation of theHarvester failed."
        warning "The current upstream release may require a newer Python version."
        warning "This does not affect the rest of the OTK installation."
        FAILED_TOOLS+=("theHarvester")
    fi
}

###############################################################################
# PENETRATION TESTERS FRAMEWORK
###############################################################################

install_ptf() {

    if [[ "$NO_PTF" == true ]]; then
        info "PTF disabled by --no-ptf."
        OPTION_SKIPPED_TOOLS+=("PenTesters Framework")
        return 0
    fi

    section "PENETRATION TESTERS FRAMEWORK"

    local ptf_dir="${INSTALL_BASE}/ptf"
    local ptf_launcher="/usr/local/bin/ptf"

    #
    # Existing PTF installation.
    #
    if [[ -d "${ptf_dir}/.git" ]]; then

        info "PTF is already installed."
        info "Checking for updates..."

        if git -C "$ptf_dir" pull --ff-only; then
            success "PTF repository updated."
        else
            warning "Unable to update the existing PTF repository."
        fi

        #
        # Make sure launcher exists.
        #
        create_ptf_launcher

        SKIPPED_TOOLS+=("PenTesters Framework")
        return 0
    fi

    #
    # Also detect an independently installed ptf command.
    #
    if command_exists "ptf" &&
       [[ "$(command -v ptf)" != "$ptf_launcher" ]]; then

        info "An existing PTF installation was found in PATH."
        info "Detected: $(command -v ptf)"
        SKIPPED_TOOLS+=("PenTesters Framework")
        return 0
    fi

    step "Installing TrustedSec PenTesters Framework..."

    mkdir -p "$INSTALL_BASE"

    if git clone \
        --depth 1 \
        "https://github.com/trustedsec/ptf.git" \
        "$ptf_dir"; then

        chmod +x "${ptf_dir}/ptf"

        create_ptf_launcher

        success "PenTesters Framework installed."
        INSTALLED_TOOLS+=("PenTesters Framework")

        echo
        info "PTF is installed but OTK will NOT automatically install"
        info "every available PTF module."
        info "Launch it with:"
        echo
        echo "    ptf"
        echo

    else

        error "Unable to clone PTF."
        FAILED_TOOLS+=("PenTesters Framework")
    fi
}

###############################################################################
# PTF LAUNCHER
###############################################################################

create_ptf_launcher() {

    local ptf_dir="${INSTALL_BASE}/ptf"
    local ptf_launcher="/usr/local/bin/ptf"

    if [[ ! -f "${ptf_dir}/ptf" ]]; then
        warning "PTF launcher could not be created because ptf was not found."
        return 0
    fi

    cat > "$ptf_launcher" <<EOF
#!/usr/bin/env bash
exec /usr/bin/python3 "${ptf_dir}/ptf" "\$@"
EOF

    chmod 755 "$ptf_launcher"
}

###############################################################################
# WORDLISTS
###############################################################################

install_wordlists() {

    if [[ "$NO_WORDLISTS" == true ]]; then
        info "Wordlists disabled by --no-wordlists."
        OPTION_SKIPPED_TOOLS+=("Wordlists")
        return 0
    fi

    section "WORDLISTS"

    mkdir -p "$WORDLIST_DIR"

    install_seclists
    install_dirbuster_wordlists
    install_usernames_wordlist
    install_rockyou
}

###############################################################################
# SECLISTS
###############################################################################

install_seclists() {

    local destination="${WORDLIST_DIR}/SecLists"

    #
    # Existing Git repository.
    #
    if [[ -d "${destination}/.git" ]]; then

        info "SecLists already exists."
        info "Updating existing SecLists repository..."

        if git -C "$destination" pull --ff-only; then
            success "SecLists updated."
        else
            warning "Unable to update SecLists."
        fi

        SKIPPED_TOOLS+=("SecLists")
        return 0
    fi

    #
    # Existing non-Git installation.
    #
    if [[ -d "$destination" ]]; then

        info "SecLists directory already exists."
        info "Preserving existing contents."
        SKIPPED_TOOLS+=("SecLists")
        return 0
    fi

    step "Installing SecLists..."

    if git clone \
        --depth 1 \
        "https://github.com/danielmiessler/SecLists.git" \
        "$destination"; then

        success "SecLists installed."
        INSTALLED_TOOLS+=("SecLists")

    else

        error "Unable to install SecLists."
        FAILED_TOOLS+=("SecLists")
    fi
}

###############################################################################
# DIRBUSTER WORDLISTS
###############################################################################

install_dirbuster_wordlists() {

    local destination="${WORDLIST_DIR}/dirbuster"

    if [[ -d "$destination" ]] &&
       find "$destination" \
           -type f \
           -print -quit \
           2>/dev/null |
       grep -q .; then

        info "DirBuster wordlists already exist."
        SKIPPED_TOOLS+=("DirBuster wordlists")
        return 0
    fi

    step "Installing DirBuster wordlists..."

    local temp_dir="/tmp/otk-dirbuster-wordlists"

    rm -rf "$temp_dir"
    mkdir -p "$destination"

    if git clone \
        --depth 1 \
        "https://github.com/daviddias/node-dirbuster.git" \
        "$temp_dir"; then

        if [[ -d "${temp_dir}/lists" ]]; then

            cp -a \
                "${temp_dir}/lists/." \
                "$destination/"

            success "DirBuster wordlists installed."
            INSTALLED_TOOLS+=("DirBuster wordlists")

        else

            warning "DirBuster repository did not contain expected lists."
            FAILED_TOOLS+=("DirBuster wordlists")
        fi

    else

        warning "Unable to download DirBuster wordlists."
        FAILED_TOOLS+=("DirBuster wordlists")
    fi

    rm -rf "$temp_dir"
}

###############################################################################
# USERNAMES
###############################################################################

install_usernames_wordlist() {

    local destination="${WORDLIST_DIR}/usernames.txt"

    if [[ -s "$destination" ]]; then

        info "usernames.txt already exists."
        SKIPPED_TOOLS+=("usernames.txt")
        return 0
    fi

    step "Installing usernames.txt..."

    if curl -fL \
        "https://raw.githubusercontent.com/jeanphorn/wordlist/master/usernames.txt" \
        -o "$destination"; then

        sed -i 's/\r$//' "$destination"

        success "usernames.txt installed."
        INSTALLED_TOOLS+=("usernames.txt")

    else

        error "Unable to download usernames.txt."
        FAILED_TOOLS+=("usernames.txt")
        rm -f "$destination"
    fi
}

###############################################################################
# ROCKYOU
###############################################################################

install_rockyou() {

    local destination="${WORDLIST_DIR}/rockyou.txt"
    local archive="/tmp/otk-rockyou.txt.gz"

    if [[ -s "$destination" ]]; then

        info "rockyou.txt already exists."
        SKIPPED_TOOLS+=("rockyou.txt")
        return 0
    fi

    step "Installing rockyou.txt..."

    rm -f "$archive"

    if curl -fL \
        "https://github.com/praetorian-code/Hob0Rules/raw/master/wordlists/rockyou.txt.gz" \
        -o "$archive"; then

        if gzip -dc "$archive" > "$destination"; then

            success "rockyou.txt installed."
            INSTALLED_TOOLS+=("rockyou.txt")

        else

            error "Unable to decompress rockyou.txt."
            FAILED_TOOLS+=("rockyou.txt")
            rm -f "$destination"
        fi

    else

        error "Unable to download rockyou.txt."
        FAILED_TOOLS+=("rockyou.txt")
    fi

    rm -f "$archive"
}

###############################################################################
# WORDLIST PERMISSIONS
###############################################################################

fix_wordlist_permissions() {

    section "WORDLIST PERMISSIONS"

    if [[ -d "$WORDLIST_DIR" ]]; then

        chmod -R a+rX "$WORDLIST_DIR" || true

        success "Wordlists are readable by normal users."
    fi
}

###############################################################################
# MONTHLY APT UPDATES
###############################################################################

setup_monthly_updates() {

    if [[ "$NO_CRON" == true ]]; then
        info "Monthly update job disabled by --no-cron."
        return 0
    fi

    section "AUTOMATIC MONTHLY UPDATES"

    local cron_file="/etc/cron.d/offsec-toolkit-update"

    #
    # The cron job deliberately uses apt-get upgrade rather than
    # dist-upgrade. This keeps the automated maintenance conservative.
    #
    cat > "$cron_file" <<'EOF'
# OffSec-Toolkit
# Monthly Debian package maintenance.
#
# OTK intentionally uses "upgrade" rather than "dist-upgrade" here.
#
# Runs at 03:00 on the first day of every month.

0 3 1 * * root /usr/bin/apt-get update -qq && /usr/bin/apt-get upgrade -y -qq >> /var/log/offsec-toolkit-apt.log 2>&1
EOF

    chmod 644 "$cron_file"

    success "Monthly APT update job configured."
    info "Cron file: ${cron_file}"
    info "APT maintenance log: /var/log/offsec-toolkit-apt.log"
}

###############################################################################
# CLEANUP
###############################################################################

cleanup() {

    section "SYSTEM CLEANUP"

    apt-get autoclean -y >/dev/null 2>&1 || true

    #
    # Do not perform autoremove here.
    #
    # On an established security distribution, automatically removing
    # packages can have unintended consequences.
    #
    rm -f /tmp/msfinstall.* 2>/dev/null || true
    rm -rf /tmp/otk-dirbuster-wordlists 2>/dev/null || true
    rm -f /tmp/otk-rockyou.txt.gz 2>/dev/null || true

    success "Temporary installation files cleaned."
}

###############################################################################
# SUMMARY HELPERS
###############################################################################

print_array() {

    local title="$1"
    shift

    echo -e "${BOLD}${WHITE}${title}${RESET}"

    if [[ $# -eq 0 ]]; then
        echo "  None"
        return
    fi

    local item

    for item in "$@"; do
        echo "  • ${item}"
    done
}

###############################################################################
# INSTALLATION SUMMARY
###############################################################################

installation_summary() {

    section "OTK INSTALLATION SUMMARY"

    echo
    echo -e "${BOLD}${WHITE}Environment:${RESET}"
    echo "  Distribution : ${OS_NAME}"
    echo "  User         : ${REAL_USER}"
    echo "  OTK version  : ${VERSION}"
    echo

    print_array "Installed:" "${INSTALLED_TOOLS[@]}"
    echo

    print_array "Already present / skipped:" "${SKIPPED_TOOLS[@]}"
    echo

    print_array "Disabled by options:" "${OPTION_SKIPPED_TOOLS[@]}"
    echo

    print_array "Failed:" "${FAILED_TOOLS[@]}"

    echo
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

    if [[ "${#FAILED_TOOLS[@]}" -eq 0 ]]; then

        echo -e "${GREEN}${BOLD} OTK installation completed successfully.${RESET}"

    else

        echo -e "${YELLOW}${BOLD} OTK installation completed with some failures.${RESET}"
        echo
        warning "Review the failed components above."
        warning "The remaining installation was allowed to continue."
    fi

    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
}

###############################################################################
# FINAL INFORMATION
###############################################################################

final_information() {

    echo
    echo -e "${BOLD}${WHITE}Useful locations:${RESET}"
    echo

    echo "  OffSec-Toolkit:"
    echo "    ${INSTALL_BASE}"
    echo

    echo "  Wordlists:"
    echo "    ${WORDLIST_DIR}"
    echo

    echo "  Installation log:"
    echo "    ${LOG_FILE}"
    echo

    echo "  PTF:"
    echo "    ptf"
    echo

    echo "  Metasploit:"
    echo "    msfconsole"
    echo

    echo "  Nmap:"
    echo "    nmap"
    echo

    echo "  Hashcat:"
    echo "    hashcat"
    echo

    echo "  John:"
    echo "    john"
    echo

    echo "  OTK:"
    echo "    ${PROJECT_NAME}"
    echo

    if [[ "$OS_FAMILY" == "kali" ||
          "$OS_FAMILY" == "parrot" ]]; then

        echo -e "${YELLOW}Existing security distribution detected:${RESET}"
        echo "  OTK preserved the existing distribution configuration."
        echo "  No external security repositories were added."
        echo "  No security-distribution metapackages were installed."
        echo
    fi

    echo -e "${YELLOW}IMPORTANT:${RESET}"
    echo "  Some tools require additional configuration before use."
    echo "  If you were added to a new group, log out and back in."
    echo

    echo -e "${GREEN}${BOLD}OTK installation complete.${RESET}"
    echo
    echo "  Test only systems, networks and applications you own"
    echo "  or are explicitly authorized to assess."
    echo
}

###############################################################################
# MAIN
###############################################################################

main() {

    #
    # Parse options before privilege escalation.
    #
    parse_arguments "$@"

    #
    # Determine the real user before becoming root.
    #
    determine_real_user

    #
    # Re-execute through sudo if necessary.
    #
    ensure_root "$@"

    #
    # Determine the environment BEFORE displaying it.
    #
    detect_system

    #
    # Logging begins after root access has been established.
    #
    setup_logging

    banner

    show_environment

    echo
    echo -e "${BOLD}${WHITE}OTK is ready to configure this system.${RESET}"
    echo
    echo "The tools installed by this script are intended for:"
    echo "  • Authorized security testing"
    echo "  • System administration"
    echo "  • Security research"
    echo "  • Education"
    echo

    if [[ "$NO_WORDLISTS" == false ]]; then
        warning "Wordlist downloads may consume significant disk space."
    fi

    echo

    read -rp "Press Enter to continue or CTRL-C to exit."

    echo

    info "Distribution: ${OS_NAME}"
    info "Environment:  ${OS_FAMILY}"
    info "User:         ${REAL_USER}"
    info "Running as:   root"

    #
    # OTK-owned base directory.
    #
    mkdir -p "$INSTALL_BASE"

    #
    # Keep the directory owned by the real user.
    #
    chown "$REAL_USER:$REAL_USER" "$INSTALL_BASE" || true

    #
    # Installation sequence.
    #
    update_system

    install_essentials

    install_privacy_tools
    install_scanning_tools
    install_metasploit
    install_password_tools
    install_web_tools
    install_wireless_tools
    install_osint_tools
    install_ptf
    install_wordlists

    fix_wordlist_permissions

    cleanup

    setup_monthly_updates

    installation_summary
    final_information
}

###############################################################################
# SCRIPT ENTRY POINT
###############################################################################

main "$@"
