# 🚀 GitHub SSH Multi-Account Manager v3.0

A comprehensive bash script that automatically manages multiple GitHub accounts with SSH keys. Perfect for developers who need to switch between work and personal GitHub accounts seamlessly.

## ✨ Features

- 🔧 **Automatic Configuration**: Detects context based on your current directory
- 🏢 **Multi-Account Support**: Separate work and personal GitHub configurations
- 🔑 **SSH Key Management**: Generates, configures, and manages SSH keys automatically
- 📁 **Smart Folder Detection**: Auto-switches between accounts based on folder structure
- 🛠️ **Interactive Setup**: Easy-to-use configuration wizard
- 🔍 **Built-in Diagnostics**: Test and troubleshoot SSH connections
- 📋 **Repository Cloning**: Clone repos with automatic account detection
- 🔄 **Remote URL Fixer**: Automatically converts plain `github.com` URLs to proper SSH hosts
- ⚡ **Zero Manual Config**: Set it once, use it everywhere
- 🚩 **Path Override**: Use `--path` flag to temporarily override work folder

## 📦 Requirements

- `git` - Git version control
- `ssh` - OpenSSH client
- `ssh-keygen` - SSH key generation utility
- Bash 4.0+

## 📦 Quick Start

### 1. Download and Setup

```bash
# Download the script
curl -O https://raw.githubusercontent.com/your-repo/git-ssh-manager.sh
# Or save the script as 'git-ssh-manager.sh'

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
- Work folder path (e.g., `~/Desktop/Work` or `~/Company`)
- Work name and email
- Personal name and email

### 3. Initialize SSH Keys

```bash
# Generate SSH keys and configure everything
./git-ssh-manager.sh init
```

### 4. Add SSH Keys to GitHub

The script will show you the public keys to add:

```bash
# Copy work key to clipboard (macOS)
cat ~/.ssh/id_ed25519_work.pub | pbcopy

# Copy personal key to clipboard (macOS)
cat ~/.ssh/id_ed25519_personal.pub | pbcopy
```

Add these keys to your respective GitHub accounts:
1. Go to GitHub → Settings → SSH and GPG keys → New SSH key
2. Paste the appropriate key for each account

## 🎯 Usage

### Automatic Context Detection

Simply run the script in any git repository:

```bash
./git-ssh-manager.sh
# or
./git-ssh-manager.sh auto
```

The script automatically:
- Detects if you're in a work or personal folder
- Applies the correct SSH configuration
- Updates git user name and email
- Configures the remote URL with the appropriate SSH host

### Path Override

Use the `--path` flag to temporarily override the work folder:

```bash
# Override work folder for this session
./git-ssh-manager.sh --path /custom/path auto
./git-ssh-manager.sh --path ~/work/projects work
./git-ssh-manager.sh --path /workspace diagnose
```

The path must exist, or an error will be shown.

### Fix Existing Repositories

If you have repositories with plain `github.com` URLs or accidentally configured them wrong:

```bash
cd /path/to/your/repo

# Check current remote
git remote -v
# origin  git@github.com:user/repo.git (fetch)
# origin  git@github.com:user/repo.git (push)

# Fix the remote URL
./git-ssh-manager.sh fix-remote
```

**Interactive prompt will show:**
```
╔════════════════════════════════════════════════════════╗
║         Which GitHub account owns this repo?           ║
╚════════════════════════════════════════════════════════╝

Current directory: /path/to/your/repo
Remote URL: git@github.com:user/repo.git

┌─────────────────────────────────────────────────────┐
│  [1] WORK - Company/Organization repository         │
│       Use your work GitHub account credentials      │
│       Example: john.doe@company.com                 │
└─────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────┐
│  [2] PERSONAL - Your personal repository            │
│       Use your personal GitHub account credentials  │
│       Example: john@gmail.com                       │
└─────────────────────────────────────────────────────┘

Enter your choice [1/2]:
```

### Fixing Mistakes (Changed Personal to Work or Vice Versa)

If you accidentally configured a repository with the wrong account:

```bash
cd /path/to/wrongly-configured-repo

# Run fix-remote again
./git-ssh-manager.sh fix-remote

# Output will show:
# ✓ Currently configured as: WORK (or PERSONAL)
# Do you want to change the account type?
# Change configuration? [y/N]: y

# Then choose the correct account type
```

The script will:
1. Detect the current configuration
2. Ask if you want to change it
3. Switch to the correct SSH host
4. Update all git settings accordingly

### Manual Commands

```bash
# Auto-configure based on current directory
./git-ssh-manager.sh
./git-ssh-manager.sh auto

# Force work configuration
./git-ssh-manager.sh work

# Force personal configuration
./git-ssh-manager.sh personal

# Show current git configuration
./git-ssh-manager.sh status

# Clone repository with auto-config
./git-ssh-manager.sh setup https://github.com/company/repo.git

# Fix remote URL for existing repo
./git-ssh-manager.sh fix-remote

# Run diagnostics
./git-ssh-manager.sh diagnose

# Interactive configuration setup
./git-ssh-manager.sh setup-config

# Initialize SSH keys
./git-ssh-manager.sh init

# Show help
./git-ssh-manager.sh help
./git-ssh-manager.sh --help
./git-ssh-manager.sh -h

# Show version
./git-ssh-manager.sh version
./git-ssh-manager.sh --version
./git-ssh-manager.sh -v
```

### Repository Cloning

Clone repositories with automatic configuration:

```bash
# These are all equivalent:
./git-ssh-manager.sh setup git@github.com:company/repo.git
./git-ssh-manager.sh setup https://github.com/company/repo.git
./git-ssh-manager.sh setup company/repo
```

The script will:
- Convert HTTPS URLs to SSH
- Use the appropriate SSH host based on context
- Clone into the correct folder structure
- Apply the right git configuration

## 🏗️ How It Works

### Folder-Based Context Detection

```
~/Desktop/Work/          → Work account
~/Desktop/Work/project1/ → Work account
~/Desktop/Krispcall/     → Work account (configurable)
~/projects/personal/     → Personal account
~/Documents/hobby/       → Personal account
```

### SSH Configuration

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

# Default GitHub (personal)
Host github.com
    HostName github.com
    User git
    IdentityFile ~/.ssh/id_ed25519_personal
    IdentitiesOnly yes
    AddKeysToAgent yes
```

### Git Remote URLs

**Before (problematic):**
```
git@github.com:company/repo.git
```

**After (proper):**
```
git@github-work:company/repo.git    # For work repos
git@github-personal:user/repo.git   # For personal repos
```

This ensures the correct SSH key is used automatically!

## 🔄 Complete Workflow Example

### Setting Up a New System

```bash
# 1. Download and setup the script
chmod +x git-ssh-manager.sh

# 2. Configure your accounts
./git-ssh-manager.sh setup-config
# Enter work folder: ~/Desktop/Work
# Enter work name: John Doe
# Enter work email: john.doe@company.com
# Enter personal name: John Doe
# Enter personal email: john@gmail.com

# 3. Initialize SSH keys
./git-ssh-manager.sh init

# 4. Copy and add public keys to GitHub (both accounts)
cat ~/.ssh/id_ed25519_work.pub
cat ~/.ssh/id_ed25519_personal.pub

# 5. Test the setup
./git-ssh-manager.sh diagnose
```

### Fixing Existing Repositories

```bash
# Navigate to your existing repo
cd ~/Desktop/Work/my-project

# Check current remote
git remote -v
# origin  git@github.com:company/my-project.git (fetch)

# Fix the remote URL
./git-ssh-manager.sh fix-remote
# Script asks: Is this work or personal?
# Choose: 1 (Work)

# Verify the fix
git remote -v
# origin  git@github-work:company/my-project.git (fetch)

# Now you can push/pull normally
git push origin main
```

### Daily Usage

```bash
# Work project
cd ~/Desktop/Work/company-project
./git-ssh-manager.sh                    # Auto-configures for work
git pull origin main
git checkout -b feature/awesome-feature
# ... make changes ...
git add .
git commit -m "Implement awesome feature"
git push -u origin feature/awesome-feature

# Personal project
cd ~/projects/personal/my-blog
./git-ssh-manager.sh                    # Auto-configures for personal
git pull origin main
git checkout -b post/new-article
# ... write blog post ...
git add .
git commit -m "Add new blog post"
git push -u origin post/new-article
```

## ⚙️ Configuration

### Command Line Options

```bash
--path <PATH>    Override work folder path (must exist)
--help, -h       Show help message
--version, -v    Show version information
```

### Environment Variables

Override the work folder temporarily:
```bash
WORK_FOLDER=~/MyCompany ./git-ssh-manager.sh
```

### Configuration File

Settings are saved in `~/.git-config-settings`:

```bash
# Git SSH Configuration Settings
WORK_FOLDER="/Users/username/Desktop/Work"
WORK_NAME="John Doe"
WORK_EMAIL="john.doe@company.com"
PERSONAL_NAME="John Doe"
PERSONAL_EMAIL="john@personal.com"
```

### Default File Locations

```
~/.ssh/id_ed25519_work           # Work private key
~/.ssh/id_ed25519_work.pub       # Work public key
~/.ssh/id_ed25519_personal       # Personal private key
~/.ssh/id_ed25519_personal.pub   # Personal public key
~/.ssh/config                    # SSH configuration
~/.git-config-settings           # Script configuration
```

## 🔍 Diagnostics

Run comprehensive diagnostics:

```bash
./git-ssh-manager.sh diagnose
```

This checks:
- ✅ Configuration settings
- 🔑 SSH key existence
- 📝 SSH config file
- 🌐 GitHub SSH connections
- 📍 Current context detection

## 🛠️ Troubleshooting

### SSH Connection Issues

```bash
# Test SSH connections manually
ssh -T git@github-work
ssh -T git@github-personal

# Check SSH agent
ssh-add -l

# Add keys to SSH agent
ssh-add ~/.ssh/id_ed25519_work
ssh-add ~/.ssh/id_ed25519_personal
```

### Permission Issues

```bash
# Fix SSH directory permissions
chmod 700 ~/.ssh
chmod 600 ~/.ssh/id_ed25519_*
chmod 644 ~/.ssh/id_ed25519_*.pub
chmod 600 ~/.ssh/config
```

### Git Remote Issues

```bash
# Check current remote
git remote -v

# Use the fix-remote command
./git-ssh-manager.sh fix-remote

# Or manually update remote URL
git remote set-url origin git@github-work:company/repo.git
```

### "Permission denied (publickey)" Error

This usually means:
1. SSH key not added to GitHub account
2. Wrong SSH key being used
3. SSH agent not running

**Solution:**
```bash
# Run diagnostics to identify the issue
./git-ssh-manager.sh diagnose

# Make sure keys are in SSH agent
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_ed25519_work
ssh-add ~/.ssh/id_ed25519_personal

# Test connection
ssh -T git@github-work
ssh -T git@github-personal
```

### Missing Dependencies

If you see "Missing required dependencies" error:

```bash
# macOS
brew install git openssh

# Ubuntu/Debian
sudo apt-get install git openssh-client

# Arch Linux
sudo pacman -S git openssh
```

## 🎨 Customization

### Custom Work Folder Detection

Edit the `detect_context()` function to add custom logic:

```bash
function detect_context() {
    local current_dir="$(pwd)"

    # Custom detection logic
    if [[ "$current_dir" =~ /work/ ]] || [[ "$current_dir" =~ /company/ ]]; then
        echo "work"
    else
        echo "personal"
    fi
}
```

### Additional SSH Hosts

Add more accounts by extending the SSH config:

```ssh
# Freelance account
Host github-freelance
    HostName github.com
    User git
    IdentityFile ~/.ssh/id_ed25519_freelance
    IdentitiesOnly yes
    AddKeysToAgent yes
```

## 📱 Integration Tips

### Shell Alias

Add to your `.bashrc` or `.zshrc`:

```bash
alias gitswitch='/path/to/git-ssh-manager.sh'
alias gs='gitswitch status'
alias gsetup='gitswitch setup'
alias gfix='gitswitch fix-remote'
alias gwork='gitswitch work'
alias gpersonal='gitswitch personal'
alias gdiag='gitswitch diagnose'
```

Then reload your shell:
```bash
source ~/.bashrc  # or ~/.zshrc
```

Now you can use short commands:
```bash
gs                           # Check status
gsetup repo-url             # Clone and setup repo
gfix                        # Fix remote URL
gwork                       # Force work config
gpersonal                   # Force personal config
gdiag                       # Run diagnostics
gitswitch setup-config      # Interactive setup
```

### Git Hooks

Auto-run on repository initialization:

```bash
# In .git/hooks/post-checkout
#!/bin/bash
/path/to/git-ssh-manager.sh
```

### IDE Integration

For VS Code, add to your workspace settings:

```json
{
    "terminal.integrated.shellArgs.osx": [
        "-c",
        "/path/to/git-ssh-manager.sh && exec $SHELL"
    ]
}
```

## 🚀 Advanced Usage

### Batch Repository Setup

```bash
# Clone multiple repositories
repos=("company/repo1" "company/repo2" "company/repo3")
for repo in "${repos[@]}"; do
    ./git-ssh-manager.sh setup "https://github.com/$repo.git"
done
```

### Using Path Override for Different Projects

```bash
# Work on client projects with different folders
./git-ssh-manager.sh --path ~/Clients/ClientA work
./git-ssh-manager.sh --path ~/Clients/ClientB work
./git-ssh-manager.sh --path ~/PersonalProjects personal
```

### Automated Deployment

```bash
#!/bin/bash
# Deploy script

# Ensure correct configuration
./git-ssh-manager.sh work

# Deploy
git add .
git commit -m "Deploy: $(date)"
git push origin main
```

### Bulk Fix Existing Repositories

```bash
#!/bin/bash
# Fix all repositories in a folder

for dir in ~/Desktop/Work/*/; do
    if [ -d "$dir/.git" ]; then
        echo "Processing: $dir"
        cd "$dir"
        /path/to/git-ssh-manager.sh fix-remote
        cd ..
    fi
done
```

## 📋 Command Reference

| Command | Description |
|---------|-------------|
| `./git-ssh-manager.sh` | Auto-configure based on current directory |
| `./git-ssh-manager.sh auto` | Same as above, explicit |
| `./git-ssh-manager.sh setup-config` | Interactive configuration setup |
| `./git-ssh-manager.sh init` | Initialize SSH keys and configuration |
| `./git-ssh-manager.sh work` | Force work configuration |
| `./git-ssh-manager.sh personal` | Force personal configuration |
| `./git-ssh-manager.sh fix-remote` | Fix remote URL (convert github.com to proper host) |
| `./git-ssh-manager.sh setup <url>` | Clone repository with appropriate config |
| `./git-ssh-manager.sh status` | Show current configuration |
| `./git-ssh-manager.sh diagnose` | Run full SSH diagnostics |
| `./git-ssh-manager.sh help` | Show help information |
| `./git-ssh-manager.sh version` | Show version information |

### Options

| Option | Description |
|--------|-------------|
| `--path <PATH>` | Override work folder path |
| `--help, -h` | Show help message |
| `--version, -v` | Show version information |

## 🔧 Configuration Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `WORK_FOLDER` | Path to work projects folder | `$HOME/Desktop/Krispcall` |
| `WORK_NAME` | Your work Git username | `"Your Work Name"` |
| `WORK_EMAIL` | Your work Git email | `"your-work-email@company.com"` |
| `PERSONAL_NAME` | Your personal Git username | `"Your Personal Name"` |
| `PERSONAL_EMAIL` | Your personal Git email | `"your-personal-email@gmail.com"` |
| `WORK_SSH_KEY` | Path to work SSH private key | `$HOME/.ssh/id_ed25519_work` |
| `PERSONAL_SSH_KEY` | Path to personal SSH private key | `$HOME/.ssh/id_ed25519_personal` |
| `WORK_HOST` | SSH host alias for work | `github-work` |
| `PERSONAL_HOST` | SSH host alias for personal | `github-personal` |

## 🎯 Real-World Use Cases

### Case 1: New Developer Setup
```bash
# Day 1 at new company
./git-ssh-manager.sh setup-config
./git-ssh-manager.sh init
# Add keys to GitHub accounts
./git-ssh-manager.sh diagnose

# Clone company repos
cd ~/Desktop/Work
./git-ssh-manager.sh setup https://github.com/company/main-app.git
./git-ssh-manager.sh setup https://github.com/company/api-service.git
```

### Case 2: Fixing Existing Repositories
```bash
# You have 10 work repos with wrong configuration
cd ~/Desktop/Work/repo1
./git-ssh-manager.sh fix-remote  # Choose work

cd ~/Desktop/Work/repo2
./git-ssh-manager.sh fix-remote  # Choose work

# Or use the bulk fix script from Advanced Usage
```

### Case 3: Freelancer with Multiple Clients
```bash
# Configure for main work
./git-ssh-manager.sh setup-config

# For other clients, use path override or manual configuration
cd ~/Clients/ClientA/project
./git-ssh-manager.sh --path ~/Clients/ClientA work

# Or force configuration directly
cd ~/Clients/ClientB/project
./git-ssh-manager.sh work
```

### Case 4: Multiple Personal Projects
```bash
# Use path override to classify different personal project folders
./git-ssh-manager.sh --path ~/OpenSource/status
./git-ssh-manager.sh --path ~/Learning/status
./git-ssh-manager.sh --path ~/Hobby/status
```

## ❓ FAQ

### Q: What if I have more than 2 GitHub accounts?
**A:** You can extend the script by:
1. Adding more SSH keys in the configuration
2. Creating additional SSH hosts in `~/.ssh/config`
3. Modifying the `detect_context()` function for more contexts

### Q: Can I use this with GitLab, Bitbucket, etc.?
**A:** Yes! Just modify the `HostName` in the SSH config to point to your Git host.

### Q: Will this affect my global Git configuration?
**A:** No, the script only modifies **local** repository configurations. Your global config remains untouched.

### Q: What if I'm not in a work or personal folder?
**A:** The script will use the personal configuration by default. You can override this with:
```bash
./git-ssh-manager.sh work
# or with path override
./git-ssh-manager.sh --path /work/path work
```

### Q: Can I use HTTPS instead of SSH?
**A:** This script is specifically designed for SSH. For HTTPS, you'd need credential managers instead.

### Q: What does the `--path` flag do?
**A:** It temporarily overrides the `WORK_FOLDER` variable, allowing you to classify a directory as a "work" folder even if it's not in your configured work folder location.

### Q: The script says dependencies are missing. What should I do?
**A:** Install the required packages:
- macOS: `brew install git openssh`
- Ubuntu/Debian: `sudo apt-get install git openssh-client`
- Arch: `sudo pacman -S git openssh`

## 📄 License

This script is open source and available under the MIT License.

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch: `git checkout -b feature-name`
3. Commit changes: `git commit -am 'Add feature'`
4. Push to branch: `git push origin feature-name`
5. Submit a Pull Request

## 📞 Support

If you encounter issues:

1. Run diagnostics: `./git-ssh-manager.sh diagnose`
2. Check the troubleshooting section
3. Open an issue on GitHub
4. Include the diagnostic output in your issue

## 🎉 Credits

Created for developers who juggle multiple GitHub accounts and want a seamless, automated solution.

**Happy coding! 🚀**

---

## 📚 Additional Resources

- [GitHub SSH Documentation](https://docs.github.com/en/authentication/connecting-to-github-with-ssh)
- [SSH Config File Documentation](https://www.ssh.com/academy/ssh/config)
- [Git Configuration Documentation](https://git-scm.com/docs/git-config)

## 🔔 Stay Updated

Star this repository to receive updates and improvements!
