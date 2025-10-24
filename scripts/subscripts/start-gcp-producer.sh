#!/bin/bash

# GCP Producer Startup Script
# Starts the GCP producer for the multi-cloud architecture

# Common functions
source scripts/subscripts/common.sh

# Configuration
GCP_PRODUCER_SCRIPT="src/producer/gcp_producer.py"
LOG_FILE="logs/gcp_producer.log"

# Check if we're in the right directory
check_directory() {
    if [ ! -f "requirements.txt" ] || [ ! -d "src" ]; then
        print_error "Please run this script from the project root directory"
        exit 1
    fi
}

# Check GCP configuration
check_gcp_config() {
    print_status "Checking GCP configuration..."
    
    # Check if gcloud is installed
    if ! command -v gcloud &> /dev/null; then
        print_error "Google Cloud CLI (gcloud) is not installed!"
        print_status "Please install it first: brew install google-cloud-sdk"
        exit 1
    fi
    
    # Check if authenticated
    if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" | grep -q .; then
        print_error "Not authenticated with Google Cloud!"
        print_status "Please run: gcloud auth login"
        exit 1
    fi
    
    # Check if project is set
    if ! gcloud config get-value project &> /dev/null; then
        print_error "No GCP project configured!"
        print_status "Please run: gcloud config set project YOUR_PROJECT_ID"
        exit 1
    fi
    
    print_success "GCP configuration verified"
}

# Check Python environment
check_python_env() {
    print_status "Checking Python environment..."
    
    # Check if virtual environment exists
    if [ ! -d "venv" ]; then
        print_status "Creating Python virtual environment..."
        python3 -m venv venv
    fi
    
    # Activate virtual environment
    source venv/bin/activate
    
    # Install dependencies if needed
    if [ ! -f "venv/pyvenv.cfg" ] || [ requirements.txt -nt venv/pyvenv.cfg ]; then
        print_status "Installing Python dependencies..."
        pip install -r requirements.txt
    fi
    
    print_success "Python environment ready"
}

# Start GCP producer
start_gcp_producer() {
    print_status "Starting GCP Producer..."
    
    # Create logs directory
    mkdir -p logs
    
    # Activate virtual environment
    source venv/bin/activate
    
    # Start the producer
    print_status "🚀 GCP Producer Configuration:"
    print_status "=============================="
    print_status "Trading Symbol: BTCUSDT"
    print_status "Target: Google Cloud Pub/Sub"
    print_status "Storage: Cloud Storage"
    print_status "Database: Firestore"
    print_status "Logs: $LOG_FILE"
    print_status ""
    print_status "Starting GCP producer process..."
    print_status "Press Ctrl+C to stop the producer"
    
    # Run the producer
    python3 "$GCP_PRODUCER_SCRIPT" 2>&1 | tee "$LOG_FILE"
}

# Main execution
main() {
    print_header "🚀 Starting GCP Producer"
    
    # Check environment
    check_directory
    check_gcp_config
    check_python_env
    
    # Start producer
    start_gcp_producer
}

# Run main function
main "$@"