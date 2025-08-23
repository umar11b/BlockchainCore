#!/bin/bash

# BlockchainCore Infrastructure Startup Script
# This script deploys AWS infrastructure and starts the data producer

set -e  # Exit on any error

echo "🚀 Starting BlockchainCore Infrastructure..."

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

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Deploy infrastructure using subscript
deploy_infrastructure() {
    print_status "Deploying infrastructure..."
    ./scripts/subscripts/deploy-infrastructure.sh
}

# Start producer using subscript
start_producer() {
    print_status "Starting data producer..."
    ./scripts/subscripts/start-producer.sh &
    PRODUCER_PID=$!
    print_success "Producer started with PID: $PRODUCER_PID"
}

# Main execution
main() {
    echo "=========================================="
    echo "  BlockchainCore Complete Startup"
    echo "=========================================="
    echo ""
    
    # Deploy infrastructure
    deploy_infrastructure
    
    # Start producer in background
    start_producer
    
    echo ""
    echo "🎉 Infrastructure deployed successfully!"
    echo ""
    echo "📊 To monitor: ./scripts/monitor.sh"
    echo "🛑 To stop: ./scripts/stop-infrastructure.sh"
    echo ""
    echo "The producer is now running in the background."
    echo "Check logs/producer.log for producer output."
}

# Run main function
main "$@"
