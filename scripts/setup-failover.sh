#!/bin/bash

# BlockchainCore Auto-Failover Setup Script
# Sets up automatic AWS to GCP failover system

# Common functions
source scripts/subscripts/common.sh

# Configuration
HEALTH_CHECK_INTERVAL=30
MAX_FAILURES=3

# --- Setup Functions ---

setup_health_monitoring() {
    print_status "Setting up health monitoring system..."
    
    # Create logs directory
    mkdir -p logs
    
    # Make scripts executable
    chmod +x scripts/health-monitor.sh
    chmod +x scripts/cross-cloud-sync.sh
    chmod +x scripts/subscripts/start-gcp-producer.sh
    
    print_success "Health monitoring system configured"
}

configure_failover_settings() {
    print_status "Configuring failover settings..."
    
    # Create failover configuration file
    cat > config/failover.yaml << EOF
# BlockchainCore Auto-Failover Configuration

# Health Check Settings
health_check:
  interval: ${HEALTH_CHECK_INTERVAL}  # seconds
  timeout: 10                        # seconds
  max_failures: ${MAX_FAILURES}      # consecutive failures before failover

# Cloud Priority (which cloud to use first)
cloud_priority:
  primary: "aws"
  secondary: "gcp"

# Notification Settings
notifications:
  enabled: true
  log_file: "logs/failover.log"
  # Add Slack, email, etc. here if needed

# Monitoring Settings
monitoring:
  aws_services:
    - "sqs"
    - "lambda"
    - "dynamodb"
  gcp_services:
    - "pubsub"
    - "cloudfunctions"
    - "firestore"
EOF

    print_success "Failover settings configured"
}

create_systemd_service() {
    print_status "Creating systemd service for auto-start..."
    
    # Create systemd service file
    sudo tee /etc/systemd/system/blockchain-core-failover.service > /dev/null << EOF
[Unit]
Description=BlockchainCore Auto-Failover System
After=network.target

[Service]
Type=simple
User=$USER
WorkingDirectory=$(pwd)
ExecStart=$(pwd)/scripts/health-monitor.sh start
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

    # Reload systemd and enable service
    sudo systemctl daemon-reload
    sudo systemctl enable blockchain-core-failover.service
    
    print_success "Systemd service created and enabled"
    print_status "Service will start automatically on boot"
}

# --- Quick Start Functions ---

quick_start_with_failover() {
    print_header "🚀 Quick Start with Auto-Failover"
    
    # Setup failover system
    setup_health_monitoring
    configure_failover_settings
    
    # Start with failover
    print_status "Starting multi-cloud architecture with auto-failover..."
    ./scripts/cross-cloud-sync.sh start-failover
    
    print_success "Auto-failover system is now active!"
    print_status "AWS is running as primary, GCP will take over if AWS fails"
}

# --- Testing Functions ---

test_failover_system() {
    print_header "🧪 Testing Failover System"
    
    print_status "Testing health monitoring..."
    ./scripts/health-monitor.sh status
    
    print_status "Testing manual failover to GCP..."
    ./scripts/cross-cloud-sync.sh failover-gcp
    
    sleep 5
    
    print_status "Testing manual failover back to AWS..."
    ./scripts/cross-cloud-sync.sh failover-aws
    
    print_success "Failover system test completed"
}

# --- Main Script Logic ---

case "${1:-}" in
    "setup")
        print_header "🔧 Setting up Auto-Failover System"
        setup_health_monitoring
        configure_failover_settings
        print_success "Auto-failover system setup complete!"
        print_status "Run './scripts/setup-failover.sh start' to begin"
        ;;
    
    "start")
        quick_start_with_failover
        ;;
    
    "test")
        test_failover_system
        ;;
    
    "install-service")
        create_systemd_service
        ;;
    
    "status")
        print_header "📊 Failover System Status"
        ./scripts/cross-cloud-sync.sh health-status
        ;;
    
    "help"|"-h"|"--help")
        echo "BlockchainCore Auto-Failover Setup"
        echo ""
        echo "Usage:"
        echo "  ./scripts/setup-failover.sh setup          - Setup failover system"
        echo "  ./scripts/setup-failover.sh start          - Quick start with failover"
        echo "  ./scripts/setup-failover.sh test           - Test failover system"
        echo "  ./scripts/setup-failover.sh install-service - Install systemd service"
        echo "  ./scripts/setup-failover.sh status         - Show system status"
        echo "  ./scripts/setup-failover.sh help           - Show this help"
        echo ""
        echo "Features:"
        echo "  - Automatic AWS to GCP failover"
        echo "  - Health monitoring and detection"
        echo "  - Manual failover controls"
        echo "  - Systemd service for auto-start"
        echo "  - Comprehensive logging and notifications"
        exit 0
        ;;
    
    *)
        print_error "Unknown command: ${1:-}"
        echo "Use './scripts/setup-failover.sh help' for usage information"
        exit 1
        ;;
esac
