#!/bin/bash

# GCP Setup Script for BlockchainCore Multi-Cloud Architecture
# This script helps set up GCP for the multi-cloud deployment

set -e

# Colors for output
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

# Check if gcloud is installed
check_gcloud() {
    if ! command -v gcloud &> /dev/null; then
        print_error "Google Cloud CLI (gcloud) is not installed!"
        print_status "Please install it from: https://cloud.google.com/sdk/docs/install"
        print_status ""
        print_status "For macOS:"
        print_status "  brew install google-cloud-sdk"
        print_status ""
        print_status "For Linux:"
        print_status "  curl https://sdk.cloud.google.com | bash"
        exit 1
    fi
    print_success "Google Cloud CLI found"
}

# Authenticate with Google Cloud
authenticate() {
    print_status "Authenticating with Google Cloud..."
    
    if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" | grep -q .; then
        print_status "Please authenticate with Google Cloud..."
        gcloud auth login
    else
        print_success "Already authenticated with Google Cloud"
    fi
}

# Set up project
setup_project() {
    print_status "Setting up GCP project..."
    
    # List available projects
    print_status "Available projects:"
    gcloud projects list --format="table(projectId,name)"
    
    # Get project ID from user
    read -p "Enter your GCP Project ID: " PROJECT_ID
    
    if [ -z "$PROJECT_ID" ]; then
        print_error "Project ID is required!"
        exit 1
    fi
    
    # Set project
    gcloud config set project "$PROJECT_ID"
    print_success "Project set to: $PROJECT_ID"
    
    # Enable billing (check if billing is enabled)
    print_status "Checking billing status..."
    if ! gcloud billing projects describe "$PROJECT_ID" &>/dev/null; then
        print_warning "Billing is not enabled for this project!"
        print_status "Please enable billing at: https://console.cloud.google.com/billing"
        print_status "Or run: gcloud billing accounts list"
        read -p "Press Enter after enabling billing..."
    else
        print_success "Billing is enabled"
    fi
}

# Install required dependencies
install_dependencies() {
    print_status "Installing required dependencies..."
    
    # Check if Python 3 is installed
    if ! command -v python3 &> /dev/null; then
        print_error "Python 3 is not installed!"
        print_status "Please install Python 3 from: https://python.org"
        exit 1
    fi
    
    # Check if pip is installed
    if ! command -v pip3 &> /dev/null; then
        print_error "pip3 is not installed!"
        print_status "Please install pip3"
        exit 1
    fi
    
    # Install Google Cloud libraries
    print_status "Installing Google Cloud libraries..."
    pip3 install google-cloud-pubsub google-cloud-firestore google-cloud-storage
    
    print_success "Dependencies installed"
}

# Create service account (optional)
create_service_account() {
    print_status "Creating service account for Cloud Functions..."
    
    read -p "Do you want to create a service account? (y/n): " CREATE_SA
    
    if [ "$CREATE_SA" = "y" ] || [ "$CREATE_SA" = "Y" ]; then
        SA_NAME="blockchain-core-sa"
        SA_EMAIL="${SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"
        
        # Create service account
        gcloud iam service-accounts create "$SA_NAME" \
            --display-name="BlockchainCore Service Account" \
            --description="Service account for BlockchainCore multi-cloud architecture"
        
        # Create key file
        gcloud iam service-accounts keys create "gcp-key.json" \
            --iam-account="$SA_EMAIL"
        
        print_success "Service account created: $SA_EMAIL"
        print_status "Key file saved as: gcp-key.json"
        print_warning "Keep this key file secure and never commit it to version control!"
        
        # Set environment variable
        export GOOGLE_APPLICATION_CREDENTIALS="$(pwd)/gcp-key.json"
        echo "export GOOGLE_APPLICATION_CREDENTIALS=\"$(pwd)/gcp-key.json\"" >> ~/.bashrc
        
        print_status "Environment variable set for current session"
        print_status "Run 'source ~/.bashrc' to make it permanent"
    else
        print_status "Skipping service account creation"
        print_status "Using default application credentials"
    fi
}

# Test GCP setup
test_setup() {
    print_status "Testing GCP setup..."
    
    # Test authentication
    if gcloud auth list --filter=status:ACTIVE --format="value(account)" | grep -q .; then
        print_success "Authentication working"
    else
        print_error "Authentication failed"
        exit 1
    fi
    
    # Test project access
    if gcloud config get-value project &>/dev/null; then
        print_success "Project access working"
    else
        print_error "Project access failed"
        exit 1
    fi
    
    # Test Python libraries
    if python3 -c "import google.cloud.pubsub_v1" &>/dev/null; then
        print_success "Python libraries working"
    else
        print_error "Python libraries not working"
        exit 1
    fi
    
    print_success "GCP setup test completed successfully!"
}

# Main setup function
main() {
    print_status "🚀 Setting up GCP for Multi-Cloud Architecture"
    print_status "================================================"
    
    check_gcloud
    authenticate
    setup_project
    install_dependencies
    create_service_account
    test_setup
    
    print_success "🎉 GCP Setup Complete!"
    print_status "================================================"
    print_status "Next steps:"
    print_status "1. Deploy GCP infrastructure: ./scripts/deploy-gcp.sh"
    print_status "2. Start multi-cloud architecture: ./scripts/cross-cloud-sync.sh start"
    print_status "3. Monitor status: ./scripts/cross-cloud-sync.sh monitor"
    print_status ""
    print_status "Useful commands:"
    print_status "  gcloud auth list                    # Check authentication"
    print_status "  gcloud config list                  # Check configuration"
    print_status "  gcloud projects list                # List projects"
    print_status "  gcloud services list --enabled     # List enabled services"
}

# Run main function
main "$@"
