#!/bin/bash

# =============================================================================
# Git SSH Multi-Account Manager
# =============================================================================
# Description: Manages multiple GitHub accounts with SSH keys automatically
# Version: 3.0
# Author: Git SSH Manager Team
# License: MIT
# =============================================================================

set -eo pipefail

# =============================================================================
# COLORS AND FORMATTING
# =============================================================================

readonly _RED='\033[0;31m'
readonly _GREEN='\033[0;32m'
readonly _YELLOW='\033[1;33m'
readonly _BLUE='\033[0;34m'
readonly _PURPLE='\033[0;35m'
readonly _CYAN='\033[0;36m'
readonly _NC='\033[0m'
readonly _BOLD='\033[1m'

# =============================================================================
# DEFAULT CONFIGURATION
# =============================================================================

declare -gr WORK_FOLDER="${WORK_FOLDER:-$HOME/Desktop/Krispcall}"
declare -g WORK_NAME="Your Work Name"
declare -g WORK_EMAIL="your-work-email@company.com"
declare -gr WORK_HOST="github-work"

declare -g PERSONAL_NAME="Your Personal Name"
declare -g PERSONAL_EMAIL="your-personal-email@gmail.com"
declare -gr PERSONAL_HOST="github-personal"

declare -gr WORK_SSH_KEY="$HOME/.ssh/id_ed25519_work"
declare -gr PERSONAL_SSH_KEY="$HOME/.ssh/id_ed25519_personal"
declare -gr CONFIG_FILE="$HOME/.git-config-settings"
declare -gr SSH_CONFIG="$HOME/.ssh/config"

declare -gr SCRIPT_NAME="$(basename "$0")"
declare -gr VERSION="3.0"

# =============================================================================
# DEPENDENCY CHECKS
# =============================================================================

check_dependencies() {
    local missing_deps=()

    for cmd in git ssh ssh-keygen; do
        if ! command -v "$cmd" &>/dev/null; then
            missing_deps+=("$cmd")
        fi
    done

    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        echo -e "${_RED}Error: Missing required dependencies: ${missing_deps[*]}${_NC}" >&2
        echo -e "${_YELLOW}Install them with your package manager:${_NC}"
        echo "  macOS: brew install git openssh"
        echo "  Ubuntu/Debian: sudo apt-get install git openssh-client"
        echo "  Arch: sudo pacman -S git openssh"
        exit 1
    fi
}

# =============================================================================
# UTILITY FUNCTIONS
# =============================================================================

print_banner() {
    echo -e "${_CYAN}${_BOLD}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║         Git SSH Multi-Account Manager v${VERSION}              ║"
    echo "║              Seamless GitHub Account Switching               ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${_NC}"
    echo ""
}

print_success() {
    echo -e "${_GREEN}✓${_NC} $*"
}

print_error() {
    echo -e "${_RED}✗${_NC} $*" >&2
}

print_warning() {
    echo -e "${_YELLOW}⚠${_NC} $*"
}

print_info() {
    echo -e "${_BLUE}ℹ${_NC} $*"
}

print_header() {
    echo -e "\n${_CYAN}${_BOLD}━━━ $* ━━━${_NC}\n"
}

print_section() {
    echo -e "${_BOLD}$*${_NC}"
}

is_git_repository() {
    git rev-parse --git-dir &>/dev/null
}

is_valid_email() {
    local email="$1"
    [[ "$email" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]
}

expand_path() {
    local path="$1"
    echo "${path/#\~/$HOME}"
}

confirm_yes_no() {
    local prompt="$1"
    local default="${2:-no}"
    local response

    if [[ "$default" == "yes" ]]; then
        read -p "$(echo -e "${_YELLOW}${prompt} [Y/n]: ${_NC}")" response
        [[ ! "$response" =~ ^[Nn]$ ]]
    else
        read -p "$(echo -e "${_YELLOW}${prompt} [y/N]: ${_NC}")" response
        [[ "$response" =~ ^[Yy]$ ]]
    fi
}

confirm_continue() {
    local prompt="$1"
    confirm_yes_no "$prompt" "no"
}

# =============================================================================
# CONFIGURATION MANAGEMENT
# =============================================================================

load_configuration() {
    if [[ -f "$CONFIG_FILE" ]]; then
        # shellcheck source=/dev/null
        source "$CONFIG_FILE"
        return 0
    fi
    return 1
}

save_configuration() {
    local config_content
    config_content="# Git SSH Configuration Settings"
    config_content+="\n# Generated: $(date '+%Y-%m-%d %H:%M:%S')"
    config_content+="\nWORK_FOLDER=\"$WORK_FOLDER\""
    config_content+="\nWORK_NAME=\"$WORK_NAME\""
    config_content+="\nWORK_EMAIL=\"$WORK_EMAIL\""
    config_content+="\nPERSONAL_NAME=\"$PERSONAL_NAME\""
    config_content+="\nPERSONAL_EMAIL=\"$PERSONAL_EMAIL\""

    echo -e "$config_content" > "$CONFIG_FILE"
    chmod 600 "$CONFIG_FILE"
    print_success "Configuration saved to $CONFIG_FILE"
}

# ====================================================================
# SSH KEY MANAGEMENT
# =============================================================================

ensure_ssh_directory() {
    local ssh_dir="$HOME/.ssh"

    if [[ ! -d "$ssh_dir" ]]; then
        mkdir -p "$ssh_dir"
        chmod 700 "$ssh_dir"
        print_info "Created .ssh directory"
    fi
}

generate_ssh_key() {
    local key_path="$1"
    local email="$2"
    local key_type="$3"

    if [[ -f "$key_path" ]]; then
        print_info "$key_type SSH key already exists at $key_path"
        return 0
    fi

    print_info "Generating $key_type SSH key..."

    if ssh-keygen -t ed25519 -C "$email" -f "$key_path" -N "" &>/dev/null; then
        chmod 600 "$key_path"
        chmod 644 "${key_path}.pub"
        print_success "$key_type SSH key generated successfully"
        return 0
    else
        print_error "Failed to generate $key_type SSH key"
        return 1
    fi
}

add_key_to_agent() {
    local key_path="$1"
    local key_type="$2"

    if ssh-add "$key_path" &>/dev/null; then
        print_success "$key_type key added to SSH agent"
    else
        print_warning "Could not add $key_type key to SSH agent (may already be added)"
    fi
}

create_ssh_config() {
    local config_content

    config_content="# ============================================================================\n"
    config_content+="# GitHub SSH Multi-Account Configuration\n"
    config_content+="# Generated: $(date '+%Y-%m-%d %H:%M:%S')\n"
    config_content+="# ============================================================================\n\n"

    config_content+="# Work GitHub account\n"
    config_content+="Host $WORK_HOST\n"
    config_content+="    HostName github.com\n"
    config_content+="    User git\n"
    config_content+="    IdentityFile $WORK_SSH_KEY\n"
    config_content+="    IdentitiesOnly yes\n"
    config_content+="    AddKeysToAgent yes\n\n"

    config_content+="# Personal GitHub account\n"
    config_content+="Host $PERSONAL_HOST\n"
    config_content+="    HostName github.com\n"
    config_content+="    User git\n"
    config_content+="    IdentityFile $PERSONAL_SSH_KEY\n"
    config_content+="    IdentitiesOnly yes\n"
    config_content+="    AddKeysToAgent yes\n\n"

    config_content+="# Default GitHub (personal)\n"
    config_content+="Host github.com\n"
    config_content+="    HostName github.com\n"
    config_content+="    User git\n"
    config_content+="    IdentityFile $PERSONAL_SSH_KEY\n"
    config_content+="    IdentitiesOnly yes\n"
    config_content+="    AddKeysToAgent yes"

    echo -e "$config_content" > "$SSH_CONFIG"
    chmod 600 "$SSH_CONFIG"
    print_success "SSH config created/updated at $SSH_CONFIG"
}

verify_ssh_key() {
    local key_path="$1"
    local key_type="$2"

    if [[ ! -f "$key_path" ]]; then
        print_error "$key_type SSH key not found: $key_path"
        return 1
    fi

    print_success "$key_type SSH key found"
    return 0
}

verify_ssh_config() {
    if [[ ! -f "$SSH_CONFIG" ]]; then
        print_warning "SSH config file not found"
        return 1
    fi

    if ! grep -q "$WORK_HOST" "$SSH_CONFIG" || ! grep -q "$PERSONAL_HOST" "$SSH_CONFIG"; then
        print_warning "SSH config is incomplete (missing hosts)"
        return 1
    fi

    print_success "SSH config is properly configured"
    return 0
}

test_ssh_connection() {
    local host="$1"
    local account_name="$2"
    local output

    print_info "Testing $account_name SSH connection to $host..."

    output=$(ssh -T -o ConnectTimeout=10 -o StrictHostKeyChecking=no "git@$host" 2>&1)

    if echo "$output" | grep -q "successfully authenticated"; then
        print_success "$account_name SSH connection successful"
        return 0
    fi

    print_error "$account_name SSH connection failed"
    print_info "Add your public key to GitHub: https://github.com/settings/keys"
    return 1
}

setup_ssh_keys() {
    load_configuration

    print_header "SSH Key Setup"

    ensure_ssh_directory

    if ! generate_ssh_key "$WORK_SSH_KEY" "$WORK_EMAIL" "Work"; then
        return 1
    fi

    if ! generate_ssh_key "$PERSONAL_SSH_KEY" "$PERSONAL_EMAIL" "Personal"; then
        return 1
    fi

    eval "$(ssh-agent -s)" &>/dev/null
    add_key_to_agent "$WORK_SSH_KEY" "Work"
    add_key_to_agent "$PERSONAL_SSH_KEY" "Personal"

    create_ssh_config

    print_header "Next Steps"
    echo -e "${_YELLOW}${_BOLD}1. Add SSH keys to GitHub:${_NC}"
    echo ""
    echo -e "${_CYAN}Work Account:${_NC}"
    echo "   cat $WORK_SSH_KEY.pub"
    echo -e "   ${_YELLOW}→ Add to: https://github.com/settings/keys${_NC}"
    echo ""
    echo -e "${_CYAN}Personal Account:${_NC}"
    echo "   cat $PERSONAL_SSH_KEY.pub"
    echo -e "   ${_YELLOW}→ Add to: https://github.com/settings/keys${_NC}"
    echo ""
    echo -e "${_YELLOW}${_BOLD}2. Test your setup:${_NC}"
    echo "   $SCRIPT_NAME diagnose"
}

# =============================================================================
# GIT CONFIGURATION
# =============================================================================

configure_git_account() {
    local account_type="$1"

    load_configuration

    if [[ "$account_type" == "work" ]]; then
        git config user.name "$WORK_NAME"
        git config user.email "$WORK_EMAIL"
        git config core.sshCommand "ssh -i $WORK_SSH_KEY -o IdentitiesOnly=yes"
        print_success "Work account configured"
        echo ""
        echo -e "  ${_BOLD}User:${_NC}   ${_PURPLE}$WORK_NAME${_NC}"
        echo -e "  ${_BOLD}Email:${_NC}  ${_PURPLE}$WORK_EMAIL${_NC}"
        echo -e "  ${_BOLD}Host:${_NC}   ${_PURPLE}$WORK_HOST${_NC}"
    else
        git config user.name "$PERSONAL_NAME"
        git config user.email "$PERSONAL_EMAIL"
        git config core.sshCommand "ssh -i $PERSONAL_SSH_KEY -o IdentitiesOnly=yes"
        print_success "Personal account configured"
        echo ""
        echo -e "  ${_BOLD}User:${_NC}   ${_PURPLE}$PERSONAL_NAME${_NC}"
        echo -e "  ${_BOLD}Email:${_NC}  ${_PURPLE}$PERSONAL_EMAIL${_NC}"
        echo -e "  ${_BOLD}Host:${_NC}   ${_PURPLE}$PERSONAL_HOST${_NC}"
    fi
}

get_current_remote_url() {
    git remote get-url origin 2>/dev/null
}

get_ssh_command() {
    git config core.sshCommand 2>/dev/null || echo "default"
}

show_current_configuration() {
    print_header "Current Git Configuration"

    local user_name user_email remote_url ssh_cmd

    user_name=$(git config user.name 2>/dev/null || echo "Not set")
    user_email=$(git config user.email 2>/dev/null || echo "Not set")
    remote_url=$(get_current_remote_url)
    ssh_cmd=$(get_ssh_command)

    print_section "User"
    echo -e "  Name:  ${_CYAN}$user_name${_NC}"
    echo -e "  Email: ${_CYAN}$user_email${_NC}"

    if [[ -n "$remote_url" ]]; then
        print_section "Remote"
        echo -e "  URL: ${_CYAN}$remote_url${_NC}"
    fi

    print_section "SSH"
    echo -e "  Command: ${_CYAN}$ssh_cmd${_NC}"
}

# =============================================================================
# CONTEXT DETECTION
# =============================================================================

detect_context() {
    local current_dir
    current_dir="$(pwd)"

    load_configuration

    if [[ "$current_dir" == "$WORK_FOLDER"* ]]; then
        echo "work"
    else
        echo "personal"
    fi
}

select_account_type() {
    print_header "Select Account Type"
    echo -e "${_YELLOW}Current directory:${_NC} ${_CYAN}$(pwd)${_NC}"
    echo ""

    local remote_url
    remote_url=$(get_current_remote_url)
    if [[ -n "$remote_url" ]]; then
        echo -e "${_YELLOW}Remote URL:${_NC} ${_CYAN}$remote_url${_NC}"
        echo ""
    fi

    echo -e "${_GREEN}┌─────────────────────────────────────────────────────┐${_NC}"
    echo -e "${_GREEN}│  ${_BOLD}[1] WORK${_NC}${_GREEN} - Company/Organization repository     │${_NC}"
    echo -e "${_GREEN}│       $WORK_EMAIL${_NC}"
    echo -e "${_GREEN}└─────────────────────────────────────────────────────┘${_NC}"
    echo ""
    echo -e "${_BLUE}┌─────────────────────────────────────────────────────┐${_NC}"
    echo -e "${_BLUE}│  ${_BOLD}[2] PERSONAL${_NC}${_BLUE} - Your personal repository          │${_NC}"
    echo -e "${_BLUE}│       $PERSONAL_EMAIL${_NC}"
    echo -e "${_BLUE}└─────────────────────────────────────────────────────┘${_NC}"
    echo ""

    local choice
    while true; do
        read -p "$(echo -e "${_YELLOW}${_BOLD}Enter your choice [1/2]: ${_NC}")" choice

        case "$choice" in
            1)
                echo "work"
                return 0
                ;;
            2)
                echo "personal"
                return 0
                ;;
            *)
                print_error "Invalid choice. Please enter 1 or 2."
                echo ""
                ;;
        esac
    done
}

# =============================================================================
# REMOTE URL MANAGEMENT
# =============================================================================

update_remote_url() {
    local account_type="$1"
    local current_url

    current_url=$(get_current_remote_url)

    if [[ -z "$current_url" ]]; then
        print_warning "No origin remote found"
        return 1
    fi

    local new_url
    if [[ "$account_type" == "work" ]]; then
        new_url=$(echo "$current_url" | sed -e "s/@github\.com:/@$WORK_HOST:/g" -e "s/@$PERSONAL_HOST:/@$WORK_HOST:/g")
    else
        new_url=$(echo "$current_url" | sed -e "s/@github\.com:/@$PERSONAL_HOST:/g" -e "s/@$WORK_HOST:/@$PERSONAL_HOST:/g")
    fi

    git remote set-url origin "$new_url"
    print_success "Remote URL updated"
}

fix_remote_url() {
    local current_url

    current_url=$(get_current_remote_url)

    if [[ -z "$current_url" ]]; then
        print_error "No origin remote found"
        print_info "Add a remote first: git remote add origin <url>"
        return 1
    fi

    print_header "Remote URL Configuration"
    echo -e "  Current: ${_CYAN}$current_url${_NC}"
    echo ""

    local current_type=""
    if [[ "$current_url" == *"@$WORK_HOST:"* ]]; then
        current_type="work"
        echo -e "  Status: ${_GREEN}Configured for WORK${_NC}"
    elif [[ "$current_url" == *"@$PERSONAL_HOST:"* ]]; then
        current_type="personal"
        echo -e "  Status: ${_GREEN}Configured for PERSONAL${_NC}"
    elif [[ "$current_url" == *"@github.com:"* ]]; then
        echo -e "  Status: ${_YELLOW}Using plain github.com (needs configuration)${_NC}"
    else
        print_success "Remote URL is properly configured"
        return 0
    fi

    echo ""

    if [[ -n "$current_type" ]]; then
        if ! confirm_continue "Change the account type?"; then
            print_info "Configuration unchanged"
            return 0
        fi
    fi

    local account_type
    account_type=$(select_account_type)

    print_header "Applying Configuration"

    if [[ "$account_type" == "work" ]]; then
        update_remote_url "work"
        configure_git_account "work"
    else
        update_remote_url "personal"
        configure_git_account "personal"
    fi
}

# =============================================================================
# REPOSITORY OPERATIONS
# =============================================================================

setup_repository() {
    local repo_url="$1"

    if [[ -z "$repo_url" ]]; then
        print_error "Repository URL is required"
        print_info "Usage: $SCRIPT_NAME setup <repository-url>"
        return 1
    fi

    load_configuration

    local context
    context=$(detect_context)

    # Convert HTTPS to SSH
    repo_url=$(echo "$repo_url" | sed 's|https://github.com/|git@github.com:|g')

    # Apply correct host
    if [[ "$context" == "work" ]]; then
        repo_url=$(echo "$repo_url" | sed "s/github\.com/$WORK_HOST/g")
    else
        repo_url=$(echo "$repo_url" | sed "s/github\.com/$PERSONAL_HOST/g")
    fi

    print_info "Cloning repository with ${context^^} configuration..."
    echo -e "  URL: ${_CYAN}$repo_url${_NC}"
    echo ""

    if git clone "$repo_url"; then
        local repo_name
        repo_name=$(basename "$repo_url" .git)

        if [[ -d "$repo_name" ]]; then
            cd "$repo_name"
            configure_git_account "$context"
            print_success "Repository cloned and configured"
            echo -e "  Location: ${_CYAN}$(pwd)${_NC}"
            cd - &>/dev/null
        fi
    else
        print_error "Failed to clone repository"
        return 1
    fi
}

# =============================================================================
# INTERACTIVE SETUP
# =============================================================================

interactive_setup() {
    print_header "Interactive Configuration"

    # Work folder
    print_section "Work Folder"
    echo -e "  Current: ${_CYAN}$WORK_FOLDER${_NC}"
    echo ""

    local new_work_folder
    read -p "Enter work folder path (or press Enter to keep current): " new_work_folder

    if [[ -n "$new_work_folder" ]]; then
        new_work_folder=$(expand_path "$new_work_folder")
        if [[ -e "$new_work_folder" ]]; then
            WORK_FOLDER="$new_work_folder"
            print_success "Work folder updated: $WORK_FOLDER"
        else
            print_error "Path does not exist: $new_work_folder"
        fi
    fi
    echo ""

    # Work account
    print_section "Work Account"

    local new_work_name
    while true; do
        read -p "Enter your work name: " new_work_name
        if [[ -n "$new_work_name" ]]; then
            WORK_NAME="$new_work_name"
            break
        fi
        print_error "Name cannot be empty"
    done

    while true; do
        read -p "Enter your work email: " new_work_email
        if [[ -n "$new_work_email" ]] && is_valid_email "$new_work_email"; then
            WORK_EMAIL="$new_work_email"
            break
        fi
        print_error "Invalid email format"
    done
    echo ""

    # Personal account
    print_section "Personal Account"

    local new_personal_name
    while true; do
        read -p "Enter your personal name: " new_personal_name
        if [[ -n "$new_personal_name" ]]; then
            PERSONAL_NAME="$new_personal_name"
            break
        fi
        print_error "Name cannot be empty"
    done

    while true; do
        read -p "Enter your personal email: " new_personal_email
        if [[ -n "$new_personal_email" ]] && is_valid_email "$new_personal_email"; then
            PERSONAL_EMAIL="$new_personal_email"
            break
        fi
        print_error "Invalid email format"
    done

    # Summary
    print_header "Configuration Summary"
    echo -e "  ${_BOLD}Work:${_NC}"
    echo -e "    Folder: ${_CYAN}$WORK_FOLDER${_NC}"
    echo -e "    Name:   ${_CYAN}$WORK_NAME${_NC}"
    echo -e "    Email:  ${_CYAN}$WORK_EMAIL${_NC}"
    echo ""
    echo -e "  ${_BOLD}Personal:${_NC}"
    echo -e "    Name:   ${_CYAN}$PERSONAL_NAME${_NC}"
    echo -e "    Email:  ${_CYAN}$PERSONAL_EMAIL${_NC}"
    echo ""

    if confirm_yes_no "Save this configuration?" "yes"; then
        save_configuration
        print_success "Configuration complete!"
        print_info "Next step: Run '$SCRIPT_NAME init'"
    else
        print_warning "Configuration not saved"
    fi
}

# =============================================================================
# AUTO CONFIGURATION
# =============================================================================

auto_configure() {
    if ! is_git_repository; then
        print_error "Not a git repository"
        print_info "Run this command inside a git repository or use 'setup' to clone"
        return 1
    fi

    load_configuration

    local context
    context=$(detect_context)

    print_header "Auto-Configuration"
    echo -e "  Context detected: ${_YELLOW}${context^^}${_NC}"
    echo -e "  Directory: ${_CYAN}$(pwd)${_NC}"
    echo ""

    configure_git_account "$context"
    print_success "Configuration complete!"
}

# =============================================================================
# DIAGNOSTICS
# =============================================================================

run_diagnostics() {
    load_configuration

    print_banner
    print_header "System Diagnostics"

    # Configuration
    print_section "Configuration"
    echo -e "  Work Folder:    ${_YELLOW}$WORK_FOLDER${_NC}"
    echo -e "  Work Name:      ${_YELLOW}$WORK_NAME${_NC}"
    echo -e "  Work Email:     ${_YELLOW}$WORK_EMAIL${_NC}"
    echo -e "  Personal Name:  ${_YELLOW}$PERSONAL_NAME${_NC}"
    echo -e "  Personal Email: ${_YELLOW}$PERSONAL_EMAIL${_NC}"
    echo ""

    # SSH Keys
    print_section "SSH Keys"
    verify_ssh_key "$WORK_SSH_KEY" "Work"
    verify_ssh_key "$PERSONAL_SSH_KEY" "Personal"
    echo ""

    # SSH Config
    print_section "SSH Configuration"
    verify_ssh_config
    echo ""

    # Connections
    print_section "GitHub Connections"
    test_ssh_connection "$WORK_HOST" "Work"
    test_ssh_connection "$PERSONAL_HOST" "Personal"
    echo ""

    # Context
    local context
    context=$(detect_context)
    print_section "Current Context"
    echo -e "  Detected:  ${_YELLOW}${context^^}${_NC}"
    echo -e "  Directory: ${_YELLOW}$(pwd)${_NC}"

    if is_git_repository; then
        echo ""
        show_current_configuration
    fi
}

# =============================================================================
# HELP AND VERSION
# =============================================================================

show_version() {
    print_banner
    echo -e "${_BOLD}Git SSH Multi-Account Manager${_NC}"
    echo -e "Version: ${_YELLOW}$VERSION${_NC}"
    echo ""
}

show_help() {
    print_banner

    echo -e "${_YELLOW}${_BOLD}USAGE${_NC}"
    echo "  $SCRIPT_NAME [OPTIONS] <COMMAND> [ARGUMENTS]"
    echo "  $SCRIPT_NAME --path <PATH> <COMMAND>"
    echo ""

    echo -e "${_YELLOW}${_BOLD}OPTIONS${_NC}"
    echo "  --path <PATH>    Override work folder path"
    echo "  --help, -h       Show this help message"
    echo "  --version, -v    Show version information"
    echo ""

    echo -e "${_YELLOW}${_BOLD}COMMANDS${_NC}"
    echo "  setup-config     Interactive configuration wizard"
    echo "  init             Initialize SSH keys and configuration"
    echo "  work             Configure for work account"
    echo "  personal         Configure for personal account"
    echo "  fix-remote       Fix/change remote URL"
    echo "  setup <URL>      Clone repository with auto-configuration"
    echo "  status           Show current git configuration"
    echo "  diagnose         Run comprehensive diagnostics"
    echo "  auto             Auto-detect and configure based on path"
    echo "  help             Show this help message"
    echo ""

    echo -e "${_YELLOW}${_BOLD}EXAMPLES${_NC}"
    echo "  # First-time setup"
    echo "  $SCRIPT_NAME setup-config"
    echo "  $SCRIPT_NAME init"
    echo ""
    echo "  # Auto-configure based on location"
    echo "  cd ~/projects/work && $SCRIPT_NAME auto"
    echo ""
    echo "  # Override work folder"
    echo "  $SCRIPT_NAME --path /custom/path auto"
    echo ""
    echo "  # Clone with auto-configuration"
    echo "  $SCRIPT_NAME setup git@github.com:user/repo.git"
    echo ""
    echo "  # Fix remote URL"
    echo "  $SCRIPT_NAME fix-remote"
    echo ""
    echo "  # Check everything"
    echo "  $SCRIPT_NAME diagnose"
    echo ""

    echo -e "${_YELLOW}${_BOLD}FILES${_NC}"
    echo "  Configuration: $CONFIG_FILE"
    echo "  SSH Config:    $SSH_CONFIG"
    echo "  Work Key:      $WORK_SSH_KEY"
    echo "  Personal Key:  $PERSONAL_SSH_KEY"
    echo ""

    echo -e "${_YELLOW}${_BOLD}RESOURCES${_NC}"
    echo "  GitHub SSH Guide: https://docs.github.com/en/authentication/connecting-to-github-with-ssh"
    echo ""
}

# =============================================================================
# COMMAND PARSING
# =============================================================================

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --path)
                if [[ -n "${2:-}" && ! "$2" =~ ^- ]]; then
                    local expanded_path
                    expanded_path=$(expand_path "$2")
                    if [[ ! -e "$expanded_path" ]]; then
                        print_error "Path does not exist: $expanded_path"
                        exit 1
                    fi
                    OVERRIDE_WORK_FOLDER="$expanded_path"
                    shift 2
                else
                    print_error "--path requires a valid path argument"
                    exit 1
                fi
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            --version|-v)
                show_version
                exit 0
                ;;
            *)
                break
                ;;
        esac
    done
}

# =============================================================================
# MAIN ENTRY POINT
# =============================================================================

main() {
    local command="${1:-auto}"

    # Check dependencies first
    check_dependencies

    # Apply path override if provided
    if [[ -n "$OVERRIDE_WORK_FOLDER" ]]; then
        WORK_FOLDER="$OVERRIDE_WORK_FOLDER"
    fi

    case "$command" in
        setup-config|config)
            print_banner
            interactive_setup
            ;;
        init|initialize)
            print_banner
            if ! load_configuration; then
                print_warning "No configuration found"
                print_info "Running setup first..."
                echo ""
                interactive_setup
                echo ""
            fi
            setup_ssh_keys
            ;;
        work)
            if ! is_git_repository; then
                print_error "Not a git repository"
                exit 1
            fi
            print_banner
            configure_git_account "work"
            ;;
        personal)
            if ! is_git_repository; then
                print_error "Not a git repository"
                exit 1
            fi
            print_banner
            configure_git_account "personal"
            ;;
        fix-remote|fix)
            if ! is_git_repository; then
                print_error "Not a git repository"
                exit 1
            fi
            print_banner
            fix_remote_url
            ;;
        setup|clone)
            local repo_url="$2"
            if [[ -z "$repo_url" ]]; then
                print_error "Repository URL is required"
                print_info "Usage: $SCRIPT_NAME setup <repository-url>"
                exit 1
            fi
            print_banner
            setup_repository "$repo_url"
            ;;
        status|show)
            if ! is_git_repository; then
                print_error "Not a git repository"
                exit 1
            fi
            print_banner
            show_current_configuration
            ;;
        diagnose|test|check)
            run_diagnostics
            ;;
        help)
            show_help
            ;;
        auto|"")
            if ! is_git_repository; then
                print_banner
                print_error "Not a git repository"
                echo ""
                show_help
                exit 1
            fi
            print_banner
            auto_configure
            ;;
        *)
            print_banner
            print_error "Unknown command: $command"
            echo ""
            show_help
            exit 1
            ;;
    esac
}

# Entry point
parse_arguments "$@"
main "$@"
