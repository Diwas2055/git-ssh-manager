#!/usr/bin/env bash
# =============================================================================
# Git SSH Multi-Account Manager
# =============================================================================
# Description: Manages multiple GitHub accounts with SSH keys automatically
# Version: 3.2
# Author: Git SSH Manager Team
# License: MIT
# Requirements: Bash 4.4+, git, ssh, ssh-keygen
# =============================================================================

# -----------------------------------------------------------------------------
# Strict Error Handling
# -----------------------------------------------------------------------------
set -Eeuo pipefail
shopt -s inherit_errexit 2>/dev/null || true

# -----------------------------------------------------------------------------
# Version Check (Bash 4.4+ for inherit_errexit)
# -----------------------------------------------------------------------------
if (( BASH_VERSINFO[0] < 4 || (BASH_VERSINFO[0] == 4 && BASH_VERSINFO[1] < 4) )); then
    echo "Warning: Bash 4.4+ recommended for best compatibility" >&2
fi

# -----------------------------------------------------------------------------
# Constants (readonly for safety)
# -----------------------------------------------------------------------------
readonly SCRIPT_NAME="${BASH_SOURCE[0]##*/}"
readonly SCRIPT_VERSION="3.2"
readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"

# File paths
readonly SSH_DIR="${HOME}/.ssh"
readonly CONFIG_FILE="${HOME}/.git-config-settings"
readonly SSH_CONFIG="${SSH_DIR}/config"
readonly WORK_SSH_KEY="${SSH_DIR}/id_ed25519_work"
readonly PERSONAL_SSH_KEY="${SSH_DIR}/id_ed25519_personal"

# SSH host aliases
readonly WORK_HOST="github-work"
readonly PERSONAL_HOST="github-personal"
readonly DEFAULT_HOST="github.com"

# Associative array for account types
declare -Ar ACCOUNT_INFO=(
    ["work"]="Work"
    ["personal"]="Personal"
)

# Default values (empty to force user configuration)
WORK_FOLDER="${WORK_FOLDER:-}"
WORK_NAME="${WORK_NAME:-}"
WORK_EMAIL="${WORK_EMAIL:-}"
PERSONAL_NAME="${PERSONAL_NAME:-}"
PERSONAL_EMAIL="${PERSONAL_EMAIL:-}"

# -----------------------------------------------------------------------------
# Logging & Output Functions
# -----------------------------------------------------------------------------
declare LOG_LEVEL="${LOG_LEVEL:-INFO}"
declare TRACE_MODE="${TRACE_MODE:-false}"

# Log levels: DEBUG, INFO, WARN, ERROR
_log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp
    timestamp="$(date '+%Y-%m-%d %H:%M:%S')"

    local color
    case "$level" in
        DEBUG)   color="\033[0;34m" ;;
        INFO)    color="\033[0;32m" ;;
        WARN)    color="\033[1;33m" ;;
        ERROR)   color="\033[0;31m" ;;
        *)       color="\033[0m" ;;
    esac

    # Only output if level meets threshold
    local level_num
    case "$LOG_LEVEL" in
        DEBUG)   level_num=0 ;;
        INFO)    level_num=1 ;;
        WARN)    level_num=2 ;;
        ERROR)   level_num=3 ;;
        *)       level_num=1 ;;
    esac

    local current_level_num
    case "$level" in
        DEBUG)   current_level_num=0 ;;
        INFO)    current_level_num=1 ;;
        WARN)    current_level_num=2 ;;
        ERROR)   current_level_num=3 ;;
        *)       current_level_num=1 ;;
    esac

    (( current_level_num >= level_num )) || return 0

    if [[ "$level" == "ERROR" ]]; then
        printf '\033[0;31m✗\033[0m %s\n' "$message" >&2
    else
        printf '\033[0;32m✓\033[0m %s\n' "$message"
    fi
}

log_debug()   { _log DEBUG "$@"; }
log_info()    { _log INFO "$@"; }
log_warn()    { _log WARN "$@"; }
log_error()   { _log ERROR "$@"; }

# Formatted output functions
print_banner() {
    printf '\033[0;36m\033[1m'
    printf '╔══════════════════════════════════════════════════════════════╗\n'
    printf '║         Git SSH Multi-Account Manager v%s              ║\n' "$SCRIPT_VERSION"
    printf '║              Seamless GitHub Account Switching               ║\n'
    printf '╚══════════════════════════════════════════════════════════════╝\n'
    printf '\033[0m\n'
}

print_header() {
    local title="$*"
    printf '\n\033[0;36m\033[1m━━━ %s ━━━\033[0m\n\n' "$title"
}

print_section() {
    printf '\033[1m%s\033[0m\n' "$*"
}

# -----------------------------------------------------------------------------
# Utility Functions
# -----------------------------------------------------------------------------
# Expand ~ to $HOME
expand_path() {
    local path="$1"
    local result="${path/#\~/$HOME}"
    printf '%s' "$result"
}

# Validate email format
is_valid_email() {
    local email="$1"
    [[ "$email" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]
}

# Check if running in git repository
is_git_repository() {
    git rev-parse --git-dir &>/dev/null
}

# Confirm yes/no with default
confirm_yes_no() {
    local prompt="$1"
    local default="${2:-no}"
    local response

    if [[ "$default" == "yes" ]]; then
        read -rp "$(printf '\033[1;33m%s [Y/n]: \033[0m' "$prompt")" response
        [[ ! "$response" =~ ^[Nn]$ ]]
    else
        read -rp "$(printf '\033[1;33m%s [y/N]: \033[0m' "$prompt")" response
        [[ "$response" =~ ^[Yy]$ ]]
    fi
}

confirm_continue() { confirm_yes_no "$1" "no"; }

# -----------------------------------------------------------------------------
# Configuration Management
# -----------------------------------------------------------------------------
load_configuration() {
    if [[ -f "$CONFIG_FILE" ]]; then
        # shellcheck source=/dev/null
        if ! source "$CONFIG_FILE" 2>/dev/null; then
            log_warn "Failed to load configuration file"
            return 1
        fi
        return 0
    fi
    return 1
}

save_configuration() {
    # Ensure config directory exists with proper permissions
    local config_dir
    config_dir="$(dirname -- "$CONFIG_FILE")"
    mkdir -p -- "$config_dir"
    chmod 700 -- "$config_dir"

    # Write configuration using printf for safety
    {
        printf '# Git SSH Configuration Settings\n'
        printf '# Generated: %s\n' "$(date '+%Y-%m-%d %H:%M:%S')"
        [[ -n "$WORK_FOLDER" ]] && printf 'WORK_FOLDER=%q\n' "$WORK_FOLDER"
        [[ -n "$WORK_NAME" ]] && printf 'WORK_NAME=%q\n' "$WORK_NAME"
        [[ -n "$WORK_EMAIL" ]] && printf 'WORK_EMAIL=%q\n' "$WORK_EMAIL"
        [[ -n "$PERSONAL_NAME" ]] && printf 'PERSONAL_NAME=%q\n' "$PERSONAL_NAME"
        [[ -n "$PERSONAL_EMAIL" ]] && printf 'PERSONAL_EMAIL=%q\n' "$PERSONAL_EMAIL"
    } > "$CONFIG_FILE"

    chmod 600 -- "$CONFIG_FILE"
    log_info "Configuration saved to $CONFIG_FILE"
}

# -----------------------------------------------------------------------------
# SSH Key Management
# -----------------------------------------------------------------------------
# Check for required commands
check_dependencies() {
    local missing_deps=()
    for cmd in git ssh ssh-keygen; do
        command -v "$cmd" &>/dev/null || missing_deps+=("$cmd")
    done

    if (( ${#missing_deps[@]} > 0 )); then
        log_error "Missing required dependencies: ${missing_deps[*]}"
        printf '\033[1;33mInstall them with your package manager:\033[0m\n' >&2
        printf '  macOS: brew install git openssh\n' >&2
        printf '  Ubuntu/Debian: sudo apt-get install git openssh-client\n' >&2
        printf '  Arch: sudo pacman -S git openssh\n' >&2
        exit 1
    fi
}

# Ensure SSH directory exists with proper permissions
ensure_ssh_directory() {
    if [[ -d "$SSH_DIR" ]]; then
        return 0
    fi

    mkdir -p -- "$SSH_DIR"
    chmod 700 -- "$SSH_DIR"
    log_info "Created .ssh directory"
}

# Generate SSH key with optional passphrase
generate_ssh_key() {
    local key_path="$1"
    local email="$2"
    local key_type="$3"

    if [[ -f "$key_path" ]]; then
        log_info "$key_type SSH key already exists at $key_path"
        return 0
    fi

    log_info "Generating $key_type SSH key..."

    # Prompt for passphrase (can be empty by pressing Enter)
    if ssh-keygen -t ed25519 -C "$email" -f "$key_path"; then
        chmod 600 -- "$key_path"
        chmod 644 -- "${key_path}.pub"
        log_success "$key_type SSH key generated successfully"
        return 0
    fi

    log_error "Failed to generate $key_type SSH key"
    return 1
}

log_success() { printf '\033[0;32m✓\033[0m %s\n' "$*"; }

# Add key to SSH agent
add_key_to_agent() {
    local key_path="$1"
    local key_type="$2"

    if ssh-add -- "$key_path" 2>/dev/null; then
        log_success "$key_type key added to SSH agent"
    else
        log_warn "Could not add $key_type key to SSH agent (may already be added)"
    fi
}

# Create SSH config file
create_ssh_config() {
    cat > "$SSH_CONFIG" << EOF
# ============================================================================
# GitHub SSH Multi-Account Configuration
# Generated: $(date '+%Y-%m-%d %H:%M:%S')
# ============================================================================

# Work GitHub account
Host $WORK_HOST
    HostName github.com
    User git
    IdentityFile $WORK_SSH_KEY
    IdentitiesOnly yes
    AddKeysToAgent yes

# Personal GitHub account
Host $PERSONAL_HOST
    HostName github.com
    User git
    IdentityFile $PERSONAL_SSH_KEY
    IdentitiesOnly yes
    AddKeysToAgent yes

# Default GitHub (personal)
Host $DEFAULT_HOST
    HostName github.com
    User git
    IdentityFile $PERSONAL_SSH_KEY
    IdentitiesOnly yes
    AddKeysToAgent yes
EOF

    chmod 600 -- "$SSH_CONFIG"
    log_success "SSH config created/updated at $SSH_CONFIG"
}

# Verify SSH key exists
verify_ssh_key() {
    local key_path="$1"
    local key_type="$2"

    if [[ ! -f "$key_path" ]]; then
        log_error "$key_type SSH key not found: $key_path"
        return 1
    fi

    log_success "$key_type SSH key found"
    return 0
}

# Verify SSH config
verify_ssh_config() {
    if [[ ! -f "$SSH_CONFIG" ]]; then
        log_warn "SSH config file not found"
        return 1
    fi

    if ! grep -q "$WORK_HOST" -- "$SSH_CONFIG" || \
       ! grep -q "$PERSONAL_HOST" -- "$SSH_CONFIG"; then
        log_warn "SSH config is incomplete (missing hosts)"
        return 1
    fi

    log_success "SSH config is properly configured"
    return 0
}

# Test SSH connection
test_ssh_connection() {
    local host="$1"
    local account_name="$2"

    log_info "Testing $account_name SSH connection to $host..."

    local output
    output=$(ssh -T -o ConnectTimeout=10 -o StrictHostKeyChecking=accept-new "git@$host" 2>&1)

    if grep -q "successfully authenticated" <<< "$output"; then
        log_success "$account_name SSH connection successful"
        return 0
    fi

    log_error "$account_name SSH connection failed"
    log_info "Add your public key to GitHub: https://github.com/settings/keys"
    return 1
}

# Setup SSH keys
setup_ssh_keys() {
    load_configuration || {
        log_warn "No configuration found. Running setup first..."
        interactive_setup
    }

    print_header "SSH Key Setup"

    ensure_ssh_directory

    generate_ssh_key "$WORK_SSH_KEY" "$WORK_EMAIL" "Work" || return 1
    generate_ssh_key "$PERSONAL_SSH_KEY" "$PERSONAL_EMAIL" "Personal" || return 1

    # Start SSH agent if not running
    if ! ssh-add -l &>/dev/null; then
        eval "$(ssh-agent -s)" &>/dev/null
    fi

    add_key_to_agent "$WORK_SSH_KEY" "Work"
    add_key_to_agent "$PERSONAL_SSH_KEY" "Personal"

    create_ssh_config

    print_header "Next Steps"
    printf '\033[1;33m1. Add SSH keys to GitHub:\033[0m\n\n'
    printf '\033[0;36mWork Account:\033[0m\n'
    printf '   cat %s.pub\n' "$WORK_SSH_KEY"
    printf '   \033[1;33m→ Add to: https://github.com/settings/keys\033[0m\n\n'
    printf '\033[0;36mPersonal Account:\033[0m\n'
    printf '   cat %s.pub\n' "$PERSONAL_SSH_KEY"
    printf '   \033[1;33m→ Add to: https://github.com/settings/keys\033[0m\n\n'
    printf '\033[1;33m2. Test your setup:\033[0m\n'
    printf '   %s diagnose\n' "$SCRIPT_NAME"
}

# -----------------------------------------------------------------------------
# Git Configuration
# -----------------------------------------------------------------------------
configure_git_account() {
    local account_type="$1"
    load_configuration

    local name email ssh_key host
    case "$account_type" in
        work)
            name="$WORK_NAME"
            email="$WORK_EMAIL"
            ssh_key="$WORK_SSH_KEY"
            host="$WORK_HOST"
            ;;
        personal)
            name="$PERSONAL_NAME"
            email="$PERSONAL_EMAIL"
            ssh_key="$PERSONAL_SSH_KEY"
            host="$PERSONAL_HOST"
            ;;
        *)
            log_error "Invalid account type: $account_type"
            return 1
            ;;
    esac

    git config user.name -- "$name"
    git config user.email -- "$email"
    git config core.sshCommand -- "ssh -i $ssh_key -o IdentitiesOnly=yes"

    log_success "${ACCOUNT_INFO[$account_type]} account configured"
    printf '\n  \033[1mUser:\033[0m   \033[0;35m%s\033[0m\n' "$name"
    printf '  \033[1mEmail:\033[0m  \033[0;35m%s\033[0m\n' "$email"
    printf '  \033[1mHost:\033[0m   \033[0;35m%s\033[0m\n' "$host"
}

# Get current remote URL
get_current_remote_url() {
    git remote get-url origin 2>/dev/null || true
}

# Get SSH command
get_ssh_command() {
    git config core.sshCommand 2>/dev/null || echo "default"
}

# Show current configuration
show_current_configuration() {
    print_header "Current Git Configuration"

    local user_name user_email remote_url ssh_cmd
    user_name=$(git config user.name 2>/dev/null || echo "Not set")
    user_email=$(git config user.email 2>/dev/null || echo "Not set")
    remote_url=$(get_current_remote_url)
    ssh_cmd=$(get_ssh_command)

    print_section "User"
    printf '  Name:  \033[0;36m%s\033[0m\n' "$user_name"
    printf '  Email: \033[0;36m%s\033[0m\n' "$user_email"

    if [[ -n "$remote_url" ]]; then
        print_section "Remote"
        printf '  URL: \033[0;36m%s\033[0m\n' "$remote_url"
    fi

    print_section "SSH"
    printf '  Command: \033[0;36m%s\033[0m\n' "$ssh_cmd"
}

# -----------------------------------------------------------------------------
# Context Detection
# -----------------------------------------------------------------------------
detect_context() {
    local current_dir
    current_dir="$(pwd)"

    load_configuration

    if [[ -n "$WORK_FOLDER" && "$current_dir" == "$WORK_FOLDER"* ]]; then
        echo "work"
    else
        echo "personal"
    fi
}

# Select account type interactively
select_account_type() {
    print_header "Select Account Type"
    printf '\033[1;33mCurrent directory:\033[0m \033[0;36m%s\033[0m\n' "$(pwd)"
    printf '\n'

    local remote_url
    remote_url=$(get_current_remote_url)
    if [[ -n "$remote_url" ]]; then
        printf '\033[1;33mRemote URL:\033[0m \033[0;36m%s\033[0m\n' "$remote_url"
        printf '\n'
    fi

    printf '\033[0;32m┌─────────────────────────────────────────────────────┐\033[0m\n'
    printf '\033[0;32m│  \033[1m[1] WORK\033[0m\033[0;32m - Company/Organization repository     │\033[0m\n'
    printf '\033[0;32m│       %s\033[0m\n' "$WORK_EMAIL"
    printf '\033[0;32m└─────────────────────────────────────────────────────┘\033[0m\n'
    printf '\n'
    printf '\033[0;34m┌─────────────────────────────────────────────────────┐\033[0m\n'
    printf '\033[0;34m│  \033[1m[2] PERSONAL\033[0m\033[0;34m - Your personal repository          │\033[0m\n'
    printf '\033[0;34m│       %s\033[0m\n' "$PERSONAL_EMAIL"
    printf '\033[0;34m└─────────────────────────────────────────────────────┘\033[0m\n'
    printf '\n'

    local choice
    while true; do
        read -rp "$(printf '\033[1;33m\033[1mEnter your choice [1/2]: \033[0m')" choice
        case "$choice" in
            1) echo "work"; return 0 ;;
            2) echo "personal"; return 0 ;;
            *) log_error "Invalid choice. Please enter 1 or 2."; printf '\n' ;;
        esac
    done
}

# -----------------------------------------------------------------------------
# Remote URL Management
# -----------------------------------------------------------------------------
update_remote_url() {
    local account_type="$1"
    local current_url
    current_url=$(get_current_remote_url)

    [[ -z "$current_url" ]] && { log_warn "No origin remote found"; return 1; }

    local target_host
    if [[ "$account_type" == "work" ]]; then
        target_host="$WORK_HOST"
    else
        target_host="$PERSONAL_HOST"
    fi

    # Replace host in URL using parameter expansion
    local new_url="$current_url"
    new_url="${new_url//@github.com:/@}"
    new_url${target_host}:="${new_url//@${WORK_HOST}:/@${target_host}:}"
    new_url="${new_url//@${PERSONAL_HOST}:/@${target_host}:}"

    git remote set-url origin -- "$new_url"
    log_success "Remote URL updated"
}

# Fix remote URL
fix_remote_url() {
    local current_url
    current_url=$(get_current_remote_url)

    [[ -z "$current_url" ]] && {
        log_error "No origin remote found"
        log_info "Add a remote first: git remote add origin <url>"
        return 1
    }

    print_header "Remote URL Configuration"
    printf '  Current: \033[0;36m%s\033[0m\n' "$current_url"
    printf '\n'

    local current_type=""
    if [[ "$current_url" == *"@${WORK_HOST}:"* ]]; then
        current_type="work"
        printf '  Status: \033[0;32mConfigured for WORK\033[0m\n'
    elif [[ "$current_url" == *"@${PERSONAL_HOST}:"* ]]; then
        current_type="personal"
        printf '  Status: \033[0;32mConfigured for PERSONAL\033[0m\n'
    elif [[ "$current_url" == *"@github.com:"* ]]; then
        printf '  Status: \033[1;33mUsing plain github.com (needs configuration)\033[0m\n'
    else
        log_success "Remote URL is properly configured"
        return 0
    fi

    printf '\n'
    if [[ -n "$current_type" ]]; then
        confirm_continue "Change the account type?" || {
            log_info "Configuration unchanged"
            return 0
        }
    fi

    local account_type
    account_type=$(select_account_type)

    print_header "Applying Configuration"

    case "$account_type" in
        work)
            update_remote_url "work"
            configure_git_account "work"
            ;;
        personal)
            update_remote_url "personal"
            configure_git_account "personal"
            ;;
    esac
}

# -----------------------------------------------------------------------------
# Repository Operations
# -----------------------------------------------------------------------------
setup_repository() {
    local repo_url="$1"
    [[ -z "$repo_url" ]] && {
        log_error "Repository URL is required"
        log_info "Usage: $SCRIPT_NAME setup <repository-url>"
        return 1
    }

    load_configuration
    local context
    context=$(detect_context)

    # Convert HTTPS to SSH using parameter expansion
    repo_url="${repo_url//https:\/\/github.com\//git@github.com:}"

    # Apply correct host
    if [[ "$context" == "work" ]]; then
        repo_url="${repo_url//github\.com/${WORK_HOST}}"
    else
        repo_url="${repo_url//github\.com/${PERSONAL_HOST}}"
    fi

    log_info "Cloning repository with ${context^^} configuration..."
    printf '  URL: \033[0;36m%s\033[0m\n' "$repo_url"
    printf '\n'

    if git clone -- "$repo_url"; then
        local repo_name
        repo_name="${repo_url##*/}"
        repo_name="${repo_name%.git}"

        if [[ -d "$repo_name" ]]; then
            cd -- "$repo_name"
            configure_git_account "$context"
            log_success "Repository cloned and configured"
            printf '  Location: \033[0;36m%s\033[0m\n' "$(pwd)"
            cd -- "${OLDPWD:-.}" &>/dev/null || true
        fi
    else
        log_error "Failed to clone repository"
        return 1
    fi
}

# -----------------------------------------------------------------------------
# Interactive Setup
# -----------------------------------------------------------------------------
interactive_setup() {
    print_header "Interactive Configuration"

    print_section "Work Folder"
    printf '  Current: \033[0;36m%s\033[0m\n' "${WORK_FOLDER:-<not set>}"
    printf '\n'

    local new_work_folder
    read -rp "Enter work folder path (or press Enter to keep current): " new_work_folder
    if [[ -n "$new_work_folder" ]]; then
        new_work_folder=$(expand_path "$new_work_folder")
        if [[ -e "$new_work_folder" ]]; then
            WORK_FOLDER="$new_work_folder"
            log_success "Work folder updated: $WORK_FOLDER"
        else
            log_error "Path does not exist: $new_work_folder"
        fi
    fi
    printf '\n'

    print_section "Work Account"
    while :; do
        read -rp "Enter your work name: " WORK_NAME
        [[ -n "$WORK_NAME" ]] && break
        log_error "Name cannot be empty"
    done

    while :; do
        read -rp "Enter your work email: " WORK_EMAIL
        [[ -n "$WORK_EMAIL" ]] && is_valid_email "$WORK_EMAIL" && break
        log_error "Invalid email format"
    done
    printf '\n'

    print_section "Personal Account"
    while :; do
        read -rp "Enter your personal name: " PERSONAL_NAME
        [[ -n "$PERSONAL_NAME" ]] && break
        log_error "Name cannot be empty"
    done

    while :; do
        read -rp "Enter your personal email: " PERSONAL_EMAIL
        [[ -n "$PERSONAL_EMAIL" ]] && is_valid_email "$PERSONAL_EMAIL" && break
        log_error "Invalid email format"
    done

    print_header "Configuration Summary"
    printf '  \033[1mWork:\033[0m\n'
    printf '    Folder: \033[0;36m%s\033[0m\n' "${WORK_FOLDER:-<not set>}"
    printf '    Name:   \033[0;36m%s\033[0m\n' "$WORK_NAME"
    printf '    Email:  \033[0;36m%s\033[0m\n' "$WORK_EMAIL"
    printf '\n'
    printf '  \033[1mPersonal:\033[0m\n'
    printf '    Name:   \033[0;36m%s\033[0m\n' "$PERSONAL_NAME"
    printf '    Email:  \033[0;36m%s\033[0m\n' "$PERSONAL_EMAIL"
    printf '\n'

    if confirm_yes_no "Save this configuration?" "yes"; then
        save_configuration
        log_success "Configuration complete!"
        log_info "Next step: Run '$SCRIPT_NAME init'"
    else
        log_warn "Configuration not saved"
    fi
}

# -----------------------------------------------------------------------------
# Auto Configuration
# -----------------------------------------------------------------------------
auto_configure() {
    is_git_repository || {
        log_error "Not a git repository"
        log_info "Run this command inside a git repository or use 'setup' to clone"
        return 1
    }

    load_configuration

    local context
    context=$(detect_context)

    print_header "Auto-Configuration"
    printf '  Context detected: \033[1;33m%s\033[0m\n' "${context^^}"
    printf '  Directory: \033[0;36m%s\033[0m\n' "$(pwd)"
    printf '\n'

    configure_git_account "$context"
    log_success "Configuration complete!"
}

# -----------------------------------------------------------------------------
# Diagnostics
# -----------------------------------------------------------------------------
run_diagnostics() {
    load_configuration

    print_banner
    print_header "System Diagnostics"

    print_section "Configuration"
    printf '  Work Folder:    \033[1;33m%s\033[0m\n' "${WORK_FOLDER:-<not set>}"
    printf '  Work Name:      \033[1;33m%s\033[0m\n' "${WORK_NAME:-<not set>}"
    printf '  Work Email:     \033[1;33m%s\033[0m\n' "${WORK_EMAIL:-<not set>}"
    printf '  Personal Name:  \033[1;33m%s\033[0m\n' "${PERSONAL_NAME:-<not set>}"
    printf '  Personal Email: \033[1;33m%s\033[0m\n' "${PERSONAL_EMAIL:-<not set>}"
    printf '\n'

    print_section "SSH Keys"
    verify_ssh_key "$WORK_SSH_KEY" "Work"
    verify_ssh_key "$PERSONAL_SSH_KEY" "Personal"
    printf '\n'

    print_section "SSH Configuration"
    verify_ssh_config
    printf '\n'

    print_section "GitHub Connections"
    test_ssh_connection "$WORK_HOST" "Work"
    test_ssh_connection "$PERSONAL_HOST" "Personal"
    printf '\n'

    print_section "Current Context"
    local context
    context=$(detect_context)
    printf '  Detected:  \033[1;33m%s\033[0m\n' "${context^^}"
    printf '  Directory: \033[1;33m%s\033[0m\n' "$(pwd)"

    if is_git_repository; then
        printf '\n'
        show_current_configuration
    fi
}

# -----------------------------------------------------------------------------
# Help & Version
# -----------------------------------------------------------------------------
show_version() {
    print_banner
    printf '\033[1mGit SSH Multi-Account Manager\033[0m\n'
    printf 'Version: \033[1;33m%s\033[0m\n' "$SCRIPT_VERSION"
    printf '\n'
}

show_help() {
    print_banner

    printf '\033[1;33mUSAGE\033[0m\n'
    printf '  %s [OPTIONS] <COMMAND> [ARGUMENTS]\n' "$SCRIPT_NAME"
    printf '  %s --path <PATH> <COMMAND>\n' "$SCRIPT_NAME"
    printf '\n'

    printf '\033[1;33mOPTIONS\033[0m\n'
    printf '  --path <PATH>    Override work folder path\n'
    printf '  --trace, -x      Enable trace mode for debugging\n'
    printf '  --help, -h       Show this help message\n'
    printf '  --version, -v    Show version information\n'
    printf '\n'

    printf '\033[1;33mCOMMANDS\033[0m\n'
    printf '  setup-config     Interactive configuration wizard\n'
    printf '  init             Initialize SSH keys and configuration\n'
    printf '  work             Configure for work account\n'
    printf '  personal         Configure for personal account\n'
    printf '  fix-remote       Fix/change remote URL\n'
    printf '  setup <URL>      Clone repository with auto-configuration\n'
    printf '  status           Show current git configuration\n'
    printf '  diagnose         Run comprehensive diagnostics\n'
    printf '  auto             Auto-detect and configure based on path\n'
    printf '  help             Show this help message\n'
    printf '\n'

    printf '\033[1;33mEXAMPLES\033[0m\n'
    printf '  # First-time setup\n'
    printf '  %s setup-config\n' "$SCRIPT_NAME"
    printf '  %s init\n'
    printf '\n'
    printf '  # Auto-configure based on location\n'
    printf '  cd ~/projects/work && %s auto\n' "$SCRIPT_NAME"
    printf '\n'
    printf '  # Override work folder\n'
    printf '  %s --path /custom/path auto\n' "$SCRIPT_NAME"
    printf '\n'
    printf '  # Clone with auto-configuration\n'
    printf '  %s setup git@github.com:user/repo.git\n' "$SCRIPT_NAME"
    printf '\n'
    printf '  # Fix remote URL\n'
    printf '  %s fix-remote\n' "$SCRIPT_NAME"
    printf '\n'
    printf '  # Check everything\n'
    printf '  %s diagnose\n' "$SCRIPT_NAME"
    printf '\n'

    printf '\033[1;33mFILES\033[0m\n'
    printf '  Configuration: %s\n' "$CONFIG_FILE"
    printf '  SSH Config:    %s\n' "$SSH_CONFIG"
    printf '  Work Key:      %s\n' "$WORK_SSH_KEY"
    printf '  Personal Key:  %s\n' "$PERSONAL_SSH_KEY"
    printf '\n'

    printf '\033[1;33mENVIRONMENT\033[0m\n'
    printf '  WORK_FOLDER    Override work folder path (permanent)\n'
    printf '  LOG_LEVEL      Set log level: DEBUG, INFO, WARN, ERROR\n'
    printf '\n'

    printf '\033[1;33mRESOURCES\033[0m\n'
    printf '  GitHub SSH Guide: https://docs.github.com/en/authentication/connecting-to-github-with-ssh\n'
    printf '\n'
}

# -----------------------------------------------------------------------------
# Argument Parsing
# -----------------------------------------------------------------------------
usage() {
    show_help
    exit "${1:-0}"
}

parse_arguments() {
    while (( $# > 0 )); do
        case "$1" in
            --path)
                if [[ -n "${2:-}" && ! "$2" =~ ^- ]]; then
                    local expanded_path
                    expanded_path=$(expand_path "$2")
                    if [[ ! -e "$expanded_path" ]]; then
                        log_error "Path does not exist: $expanded_path"
                        exit 1
                    fi
                    WORK_FOLDER="$expanded_path"
                    shift 2
                else
                    log_error "--path requires a valid path argument"
                    exit 1
                fi
                ;;
            --trace|-x)
                TRACE_MODE="true"
                shift
                ;;
            --help|-h)
                usage 0
                ;;
            --version|-v)
                show_version
                exit 0
                ;;
            --)
                shift
                break
                ;;
            -*)
                log_error "Unknown option: $1"
                usage 1
                ;;
            *)
                break
                ;;
        esac
    done
}

# -----------------------------------------------------------------------------
# Main Entry Point
# -----------------------------------------------------------------------------
main() {
    local command="${1:-auto}"
    shift 2>/dev/null || true

    # Enable trace mode if requested
    if [[ "$TRACE_MODE" == "true" ]]; then
        set -x
    fi

    # Check dependencies first
    check_dependencies

    case "$command" in
        setup-config|config)
            print_banner
            interactive_setup
            ;;
        init|initialize)
            print_banner
            if ! load_configuration; then
                log_warn "No configuration found"
                log_info "Running setup first..."
                printf '\n'
                interactive_setup
                printf '\n'
            fi
            setup_ssh_keys
            ;;
        work)
            is_git_repository || { log_error "Not a git repository"; exit 1; }
            print_banner
            configure_git_account "work"
            ;;
        personal)
            is_git_repository || { log_error "Not a git repository"; exit 1; }
            print_banner
            configure_git_account "personal"
            ;;
        fix-remote|fix)
            is_git_repository || { log_error "Not a git repository"; exit 1; }
            print_banner
            fix_remote_url
            ;;
        setup|clone)
            local repo_url="$1"
            [[ -z "$repo_url" ]] && {
                log_error "Repository URL is required"
                exit 1
            }
            print_banner
            setup_repository "$repo_url"
            ;;
        status|show)
            is_git_repository || { log_error "Not a git repository"; exit 1; }
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
            is_git_repository || {
                print_banner
                log_error "Not a git repository"
                printf '\n'
                show_help
                exit 1
            }
            print_banner
            auto_configure
            ;;
        *)
            print_banner
            log_error "Unknown command: $command"
            printf '\n'
            show_help
            exit 1
            ;;
    esac
}

# -----------------------------------------------------------------------------
# Entry Point
# -----------------------------------------------------------------------------
parse_arguments "$@"
main "$@"
