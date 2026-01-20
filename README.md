# GitHub SSH Multi-Account Manager

<div align="center">

**Version:** 3.2 | **License:** MIT | **Requires:** Bash 4.4+, git, ssh, ssh-keygen

A production-grade bash script for managing multiple GitHub accounts with SSH keys. Designed with defensive programming practices, comprehensive error handling, and cross-platform compatibility.

</div>

## Features

- **Automatic Context Detection** - Detects work/personal based on folder location
- **Multi-Account Support** - Separate SSH keys and git config for work and personal
- **Secure SSH Key Generation** - Ed25519 keys with optional passphrase support
- **Interactive Configuration** - Guided setup wizard for first-time users
- **Built-in Diagnostics** - Test SSH connections and troubleshoot issues
- **Repository Cloning** - Clone repos with automatic account detection
- **Remote URL Fixer** - Convert plain github.com URLs to proper SSH hosts
- **Path Override** - Temporarily override work folder with `--path` flag
- **Debug Mode** - Trace execution with `--trace` flag
- **Configurable Logging** - Control output verbosity with `LOG_LEVEL`

## Quick Start

### 1. Download and Setup

```bash
# Download the script
curl -O https://raw.githubusercontent.com/Diwas2055/git-ssh-manager/main/git-ssh-manager.sh

# Make it executable
chmod +x git-ssh-manager.sh

# Optional: Move to PATH for global access
sudo mv git-ssh-manager.sh /usr/local/bin/git-ssh-manager
```

### 2. Interactive Configuration

```bash
# Run the interactive setup
./git-ssh-manager.sh setup-config
```

This will prompt you to configure:
- Work folder path (e.g., `~/Desktop/Work`)
- Work name and email
- Personal name and email

### 3. Initialize SSH Keys

```bash
# Generate SSH keys and configure everything
./git-ssh-manager.sh init
```

### 4. Add SSH Keys to GitHub

```bash
# View and add public keys to GitHub
cat ~/.ssh/id_ed25519_work.pub
cat ~/.ssh/id_ed25519_personal.pub
```

## Usage

### Automatic Context Detection

```bash
./git-ssh-manager.sh
./git-ssh-manager.sh auto
```

Automatically detects your context and applies the correct SSH configuration.

### Path Override

```bash
# Override work folder temporarily
./git-ssh-manager.sh --path /custom/path auto

# Force work config in any directory
./git-ssh-manager.sh --path ~/work/projects work
```

### Fix Existing Repositories

```bash
cd /path/to/your/repo
./git-ssh-manager.sh fix-remote
```

### Clone Repository with Auto-Config

```bash
# SSH URL
./git-ssh-manager.sh setup git@github.com:company/repo.git

# HTTPS URL (auto-converted)
./git-ssh-manager.sh setup https://github.com/company/repo.git
```

### Run Diagnostics

```bash
./git-ssh-manager.sh diagnose
```

Checks configuration, SSH keys, connections, and context detection.

### Debug Mode

```bash
# Enable trace output
./git-ssh-manager.sh --trace diagnose

# Or set LOG_LEVEL
LOG_LEVEL=DEBUG ./git-ssh-manager.sh status
```

## Command Reference

| Command | Description |
|---------|-------------|
| `setup-config` | Interactive configuration wizard |
| `init` | Generate SSH keys and initialize configuration |
| `work` | Force work account configuration |
| `personal` | Force personal account configuration |
| `fix-remote` | Fix/change remote URL |
| `setup <url>` | Clone repository with auto-configuration |
| `status` | Show current git configuration |
| `diagnose` | Run comprehensive diagnostics |
| `auto` | Auto-detect and configure based on path |

### Options

| Option | Description |
|--------|-------------|
| `--path <PATH>` | Override work folder path |
| `--trace, -x` | Enable trace mode for debugging |
| `--help, -h` | Show help message |
| `--version, -v` | Show version information |

## Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `WORK_FOLDER` | Path to work projects folder | Empty (configurable) |
| `LOG_LEVEL` | Logging verbosity: DEBUG, INFO, WARN, ERROR | INFO |
| `WORK_NAME` | Work git username | Empty |
| `WORK_EMAIL` | Work git email | Empty |
| `PERSONAL_NAME` | Personal git username | Empty |
| `PERSONAL_EMAIL` | Personal git email | Empty |

## File Locations

```
~/.ssh/id_ed25519_work           # Work private key
~/.ssh/id_ed25519_work.pub       # Work public key
~/.ssh/id_ed25519_personal       # Personal private key
~/.ssh/id_ed25519_personal.pub   # Personal public key
~/.ssh/config                    # SSH configuration
~/.git-config-settings           # Script configuration
```

## SSH Configuration

The script creates SSH host aliases in `~/.ssh/config`:

```ssh
# Work GitHub account
Host github-work
    HostName github.com
    User git
    IdentityFile ~/.ssh/id_ed25519_work
    IdentitiesOnly yes
    AddKeysToAgent yes

# Personal GitHub account
Host github-personal
    HostName github.com
    User git
    IdentityFile ~/.ssh/id_ed25519_personal
    IdentitiesOnly yes
    AddKeysToAgent yes
```

## How It Works

### Context Detection

The script detects which account to use based on your current directory:

```
~/Desktop/Work/          → Work account
~/work/projects/         → Work account (if configured)
~/projects/personal/     → Personal account
~/Documents/hobby/       → Personal account
```

### Remote URL Transformation

**Before:**
```
git@github.com:company/repo.git
```

**After:**
```
git@github-work:company/repo.git        # Work repos
git@github-personal:user/repo.git       # Personal repos
```

This ensures the correct SSH key is used automatically.

## Troubleshooting

### SSH Connection Issues

```bash
# Test SSH connections
ssh -T git@github-work
ssh -T git@github-personal

# Run diagnostics
./git-ssh-manager.sh diagnose
```

### Permission Denied

```bash
# Check SSH agent
ssh-add -l

# Add keys to agent
ssh-add ~/.ssh/id_ed25519_work
ssh-add ~/.ssh/id_ed25519_personal

# Fix permissions
chmod 700 ~/.ssh
chmod 600 ~/.ssh/id_ed25519_*
chmod 644 ~/.ssh/id_ed25519_*.pub
chmod 600 ~/.ssh/config
```

### Missing Dependencies

```bash
# macOS
brew install git openssh

# Ubuntu/Debian
sudo apt-get install git openssh-client

# Arch
sudo pacman -S git openssh
```

## Advanced Usage

### Shell Aliases

```bash
# Add to ~/.bashrc or ~/.zshrc
alias gs='git-ssh-manager.sh status'
alias gwork='git-ssh-manager.sh work'
alias gpersonal='git-ssh-manager.sh personal'
alias gdiag='git-ssh-manager.sh diagnose'
```

### Batch Clone

```bash
# Clone multiple repositories
repos=("company/repo1" "company/repo2" "company/repo3")
for repo in "${repos[@]}"; do
    git-ssh-manager.sh setup "https://github.com/$repo.git"
done
```

### Bulk Fix Repositories

```bash
#!/usr/bin/env bash
# Fix all repositories in a folder
for dir in ~/Desktop/Work/*/; do
    if [[ -d "$dir/.git" ]]; then
        cd -- "$dir"
        git-ssh-manager.sh fix-remote
    fi
done
```

## Shell Integration

### Git Hook

Add to `.git/hooks/post-checkout` for auto-configuration:

```bash
#!/usr/bin/env bash
/path/to/git-ssh-manager.sh
```

### IDE Integration (VS Code)

```json
{
    "terminal.integrated.shellArgs.linux": [
        "-c",
        "/path/to/git-ssh-manager.sh && exec $SHELL"
    ]
}
```

## Development

### Running Tests

```bash
# Check syntax
bash -n git-ssh-manager.sh

# Enable trace mode
./git-ssh-manager.sh --trace diagnose

# Check all commands
./git-ssh-manager.sh help
./git-ssh-manager.sh version
./git-ssh-manager.sh status
```

### Code Quality

```bash
# Format with shfmt (if available)
shfmt -i 2 -ci -bn -sr -kp git-ssh-manager.sh

# Lint with shellcheck (if available)
shellcheck -e SC2034 git-ssh-manager.sh
```

## Version History

### v3.2 (Current)

- **Defensive Programming**: Added `set -Eeuo pipefail` and `inherit_errexit`
- **Safe Variable Handling**: All expansions properly quoted
- **Enhanced Logging**: Configurable log levels (DEBUG, INFO, WARN, ERROR)
- **Debug Mode**: Trace execution with `--trace` flag
- **Improved Input Validation**: Email format and path validation
- **Better Error Messages**: Descriptive error messages with context
- **Bash 4.4+ Support**: Version checking and feature detection
- **ShellCheck Compliant**: Passes static analysis with enable=all

### v3.1

- Fixed `WORK_FOLDER` readonly variable issue
- Improved SSH key generation
- Better security with `StrictHostKeyChecking=accept-new`
- Reduced subprocess calls

### v3.0

- Initial release with multi-account support
- Interactive configuration wizard
- Automatic context detection

## Requirements

- **Bash:** 4.4 or higher (5.x recommended)
- **git:** Any recent version
- **ssh:** OpenSSH client
- **ssh-keygen:** OpenSSH key generation tool

## License

MIT License - see LICENSE file for details.

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make changes following shell style guidelines
4. Test with `bash -n` and shellcheck
5. Submit a pull request

## Support

1. Run diagnostics: `./git-ssh-manager.sh diagnose`
2. Enable trace mode: `./git-ssh-manager.sh --trace <command>`
3. Check troubleshooting section above
4. Open an issue with diagnostic output

---

**Happy coding!**
