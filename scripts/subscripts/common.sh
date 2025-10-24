#!/bin/bash

# Common functions for BlockchainCore scripts

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Print functions
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo -e "${BLUE}$1${NC}"
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check if file exists
file_exists() {
    [ -f "$1" ]
}

# Check if directory exists
dir_exists() {
    [ -d "$1" ]
}

# Create directory if it doesn't exist
create_dir() {
    if [ ! -d "$1" ]; then
        mkdir -p "$1"
        print_status "Created directory: $1"
    fi
}

# Check if process is running
is_process_running() {
    ps -p "$1" > /dev/null 2>&1
}

# Get current timestamp
get_timestamp() {
    date '+%Y-%m-%d %H:%M:%S'
}

# Log message with timestamp
log_message() {
    echo "[$(get_timestamp)] $1"
}

# Check if running as root
check_root() {
    if [ "$EUID" -eq 0 ]; then
        print_warning "Running as root. This is not recommended for security reasons."
    fi
}

# Validate environment variable
validate_env_var() {
    if [ -z "${!1}" ]; then
        print_error "$1 environment variable is not set!"
        return 1
    fi
    return 0
}

# Check AWS CLI configuration
check_aws_cli() {
    if ! command_exists aws; then
        print_error "AWS CLI is not installed!"
        return 1
    fi
    
    if ! aws sts get-caller-identity >/dev/null 2>&1; then
        print_error "AWS CLI is not configured or credentials are invalid!"
        return 1
    fi
    
    print_success "AWS CLI configured"
    return 0
}

# Check GCP CLI configuration
check_gcp_cli() {
    if ! command_exists gcloud; then
        print_error "Google Cloud CLI is not installed!"
        return 1
    fi
    
    if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" | grep -q .; then
        print_error "Google Cloud CLI is not authenticated!"
        return 1
    fi
    
    print_success "Google Cloud CLI configured"
    return 0
}

# Check Terraform installation
check_terraform() {
    if ! command_exists terraform; then
        print_error "Terraform is not installed!"
        return 1
    fi
    
    TERRAFORM_VERSION=$(terraform version -json | jq -r '.terraform_version' 2>/dev/null || terraform version | head -n1 | cut -d' ' -f2)
    print_success "Terraform found: $TERRAFORM_VERSION"
    return 0
}

# Check Python installation
check_python() {
    if ! command_exists python3; then
        print_error "Python 3 is not installed!"
        return 1
    fi
    
    PYTHON_VERSION=$(python3 --version)
    print_success "Python found: $PYTHON_VERSION"
    return 0
}

# Check Node.js installation
check_nodejs() {
    if ! command_exists node; then
        print_error "Node.js is not installed!"
        return 1
    fi
    
    NODE_VERSION=$(node --version)
    print_success "Node.js found: $NODE_VERSION"
    return 0
}

# Wait for user input
wait_for_user() {
    read -p "Press Enter to continue..."
}

# Confirm action
confirm_action() {
    local message="$1"
    read -p "$message (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        return 0
    else
        return 1
    fi
}

# Cleanup function for traps
cleanup() {
    print_status "Cleaning up..."
    # Add cleanup logic here
}

# Set up signal handlers
setup_signal_handlers() {
    trap cleanup EXIT INT TERM
}

# Check if port is in use
check_port() {
    local port="$1"
    if lsof -Pi :$port -sTCP:LISTEN -t >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Get available port
get_available_port() {
    local start_port="$1"
    local port=$start_port
    while check_port $port; do
        port=$((port + 1))
    done
    echo $port
}

# Format bytes to human readable
format_bytes() {
    local bytes="$1"
    if [ $bytes -lt 1024 ]; then
        echo "${bytes}B"
    elif [ $bytes -lt 1048576 ]; then
        echo "$((bytes / 1024))KB"
    elif [ $bytes -lt 1073741824 ]; then
        echo "$((bytes / 1048576))MB"
    else
        echo "$((bytes / 1073741824))GB"
    fi
}

# Check if string is empty
is_empty() {
    [ -z "$1" ]
}

# Check if string is not empty
is_not_empty() {
    [ -n "$1" ]
}

# Trim whitespace
trim() {
    echo "$1" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
}

# Convert to lowercase
to_lower() {
    echo "$1" | tr '[:upper:]' '[:lower:]'
}

# Convert to uppercase
to_upper() {
    echo "$1" | tr '[:lower:]' '[:upper:]'
}

# Check if string contains substring
contains() {
    [[ "$1" == *"$2"* ]]
}

# Check if string starts with prefix
starts_with() {
    [[ "$1" == "$2"* ]]
}

# Check if string ends with suffix
ends_with() {
    [[ "$1" == *"$2" ]]
}

# Generate random string
generate_random_string() {
    local length="${1:-8}"
    openssl rand -hex $((length / 2))
}

# Generate UUID
generate_uuid() {
    if command_exists uuidgen; then
        uuidgen
    else
        python3 -c "import uuid; print(uuid.uuid4())"
    fi
}

# Check if file is executable
is_executable() {
    [ -x "$1" ]
}

# Make file executable
make_executable() {
    chmod +x "$1"
    print_status "Made $1 executable"
}

# Check if file is readable
is_readable() {
    [ -r "$1" ]
}

# Check if file is writable
is_writable() {
    [ -w "$1" ]
}

# Get file size
get_file_size() {
    if [ -f "$1" ]; then
        stat -f%z "$1" 2>/dev/null || stat -c%s "$1" 2>/dev/null || echo "0"
    else
        echo "0"
    fi
}

# Get file modification time
get_file_mtime() {
    if [ -f "$1" ]; then
        stat -f%m "$1" 2>/dev/null || stat -c%Y "$1" 2>/dev/null || echo "0"
    else
        echo "0"
    fi
}

# Check if file is newer than another file
is_newer() {
    local file1="$1"
    local file2="$2"
    [ $(get_file_mtime "$file1") -gt $(get_file_mtime "$file2") ]
}

# Backup file
backup_file() {
    local file="$1"
    if [ -f "$file" ]; then
        cp "$file" "${file}.backup.$(date +%Y%m%d_%H%M%S)"
        print_status "Backed up $file"
    fi
}

# Restore file from backup
restore_file() {
    local file="$1"
    local backup=$(ls -t "${file}.backup."* 2>/dev/null | head -n1)
    if [ -f "$backup" ]; then
        cp "$backup" "$file"
        print_status "Restored $file from $backup"
    else
        print_error "No backup found for $file"
        return 1
    fi
}

# List backup files
list_backups() {
    local file="$1"
    ls -la "${file}.backup."* 2>/dev/null || print_warning "No backups found for $file"
}

# Clean old backups
clean_old_backups() {
    local file="$1"
    local keep="${2:-5}"
    ls -t "${file}.backup."* 2>/dev/null | tail -n +$((keep + 1)) | xargs rm -f
    print_status "Cleaned old backups for $file (keeping $keep most recent)"
}
