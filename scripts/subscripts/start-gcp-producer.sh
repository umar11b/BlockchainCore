#!/bin/bash

# GCP Producer Script
# Starts the GCP producer for multi-cloud architecture

# Common functions
source scripts/subscripts/common.sh

# Check if GCP environment is set up
check_gcp_environment() {
    if [ -z "$GCP_PROJECT_ID" ]; then
        print_error "GCP_PROJECT_ID environment variable is not set!"
        print_status "Please run: ./scripts/setup-gcp.sh"
        exit 1
    fi
    
    if [ -z "$GCP_PUBSUB_TOPIC" ]; then
        print_error "GCP_PUBSUB_TOPIC environment variable is not set!"
        print_status "Please run: ./scripts/deploy-gcp.sh"
        exit 1
    fi
}

# Start GCP Producer
start_gcp_producer() {
    print_status "Starting GCP Producer..."
    print_status "GCP Project: $GCP_PROJECT_ID"
    print_status "Pub/Sub Topic: $GCP_PUBSUB_TOPIC"
    
    # Activate virtual environment if it exists
    if [ -d "venv" ]; then
        print_status "Using virtual environment..."
        source venv/bin/activate
    fi
    
    # Start the GCP producer
    python3 src/producer/gcp_producer.py
}

# Main execution
check_gcp_environment
start_gcp_producer
