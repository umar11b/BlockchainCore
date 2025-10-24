#!/bin/bash

# BlockchainCore Infrastructure Shutdown Script
# This script safely destroys the AWS infrastructure to stop costs

set -e  # Exit on any error

echo "🛑 Stopping BlockchainCore Infrastructure..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
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

# Confirm destruction
confirm_destruction() {
    echo ""
    print_warning "⚠️  WARNING: This will destroy ALL infrastructure and data!"
    print_warning "   This action cannot be undone."
    echo ""
    echo "Options:"
    echo "  'yes'     - Full cleanup (including S3 bucket)"
    echo "  'fast'    - Quick shutdown (skip S3 cleanup)"
    echo "  'force'   - Force destroy (skip confirmation, full cleanup)"
    echo "  'cancel'  - Cancel operation"
    echo ""
    read -p "Choose option: " confirm
    
    if [ "$confirm" = "cancel" ]; then
        print_status "Destruction cancelled by user"
        exit 0
    elif [ "$confirm" = "fast" ]; then
        export SKIP_S3_CLEANUP=true
        print_status "Fast shutdown selected - S3 cleanup will be skipped"
    elif [ "$confirm" = "force" ]; then
        print_status "Force destroy selected - full cleanup with no confirmation"
        # No SKIP_S3_CLEANUP export, so S3 cleanup will run
    elif [ "$confirm" != "yes" ]; then
        print_status "Destruction cancelled by user"
        exit 0
    fi
}

# Destroy infrastructure using subscript
destroy_infrastructure() {
    print_status "Destroying infrastructure..."
    ./scripts/subscripts/destroy-infrastructure.sh
}

# Main execution
main() {
    echo "=========================================="
    echo "  BlockchainCore Complete Shutdown"
    echo "=========================================="
    echo ""
    
    # Confirm before destroying
    confirm_destruction
    
    # Destroy everything
    destroy_infrastructure
    
    echo ""
    echo "🎉 Complete shutdown finished!"
    echo ""
    echo "✅ All AWS resources have been destroyed"
    echo "✅ All producer processes have been stopped"
    echo "✅ All local files have been cleaned up"
    echo "✅ Your monthly costs should now be minimal"
    echo ""
    echo "To restart everything: ./scripts/start-infrastructure.sh"
}

# Run main function
main "$@"
