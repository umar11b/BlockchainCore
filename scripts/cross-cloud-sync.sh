#!/bin/bash

# Cross-Cloud Management Script for BlockchainCore
# Manages both AWS and GCP producers simultaneously

# Common functions
source scripts/subscripts/common.sh

# --- Configuration ---
AWS_PRODUCER_SCRIPT="./scripts/subscripts/start-producer.sh"
GCP_PRODUCER_SCRIPT="./scripts/subscripts/start-gcp-producer.sh"

# --- Functions ---

start_all_producers() {
    print_status "Starting Multi-Cloud Architecture..."
    print_status "====================================="
    
    # Start AWS Producer
    print_status "Starting AWS Producer..."
    if [ -f "$AWS_PRODUCER_SCRIPT" ]; then
        nohup "$AWS_PRODUCER_SCRIPT" > logs/aws_producer.log 2>&1 &
        AWS_PID=$!
        echo "$AWS_PID" > .aws_producer_pid
        print_success "AWS Producer started with PID: $AWS_PID"
    else
        print_error "AWS Producer script not found: $AWS_PRODUCER_SCRIPT"
        return 1
    fi

    # Start GCP Producer
    print_status "Starting GCP Producer..."
    if [ -f "$GCP_PRODUCER_SCRIPT" ]; then
        nohup "$GCP_PRODUCER_SCRIPT" > logs/gcp_producer.log 2>&1 &
        GCP_PID=$!
        echo "$GCP_PID" > .gcp_producer_pid
        print_success "GCP Producer started with PID: $GCP_PID"
    else
        print_warning "GCP Producer script not found: $GCP_PRODUCER_SCRIPT"
        print_status "Creating GCP Producer script..."
        create_gcp_producer_script
        if [ -f "$GCP_PRODUCER_SCRIPT" ]; then
            nohup "$GCP_PRODUCER_SCRIPT" > logs/gcp_producer.log 2>&1 &
            GCP_PID=$!
            echo "$GCP_PID" > .gcp_producer_pid
            print_success "GCP Producer started with PID: $GCP_PID"
        else
            print_error "Failed to create GCP Producer script"
            return 1
        fi
    fi

    print_success "Multi-cloud architecture started!"
    print_status "AWS Producer PID: $AWS_PID"
    print_status "GCP Producer PID: $GCP_PID"
    print_status "Check logs/aws_producer.log and logs/gcp_producer.log for output."
}

create_gcp_producer_script() {
    cat > "$GCP_PRODUCER_SCRIPT" << 'EOF'
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
EOF
    chmod +x "$GCP_PRODUCER_SCRIPT"
}

stop_all_producers() {
    print_status "Stopping Multi-Cloud Architecture..."
    print_status "===================================="
    
    # Stop AWS Producer
    if [ -f ".aws_producer_pid" ]; then
        AWS_PID=$(cat .aws_producer_pid)
        if ps -p "$AWS_PID" > /dev/null; then
            kill "$AWS_PID"
            print_success "AWS Producer (PID: $AWS_PID) stopped."
        else
            print_warning "AWS Producer PID file found, but process not running."
        fi
        rm .aws_producer_pid
    else
        print_warning "AWS Producer PID file not found. No AWS producer to stop."
    fi

    # Stop GCP Producer
    if [ -f ".gcp_producer_pid" ]; then
        GCP_PID=$(cat .gcp_producer_pid)
        if ps -p "$GCP_PID" > /dev/null; then
            kill "$GCP_PID"
            print_success "GCP Producer (PID: $GCP_PID) stopped."
        else
            print_warning "GCP Producer PID file found, but process not running."
        fi
        rm .gcp_producer_pid
    else
        print_warning "GCP Producer PID file not found. No GCP producer to stop."
    fi
    
    print_success "Multi-cloud architecture stopped."
}

monitor_producers() {
    print_status "Monitoring Multi-Cloud Producers..."
    print_status "==================================="
    print_status "Press Ctrl+C to exit"
    print_status ""
    
    # Check if log files exist
    if [ -f "logs/aws_producer.log" ] && [ -f "logs/gcp_producer.log" ]; then
        tail -f logs/aws_producer.log logs/gcp_producer.log
    elif [ -f "logs/aws_producer.log" ]; then
        print_warning "Only AWS producer log found"
        tail -f logs/aws_producer.log
    elif [ -f "logs/gcp_producer.log" ]; then
        print_warning "Only GCP producer log found"
        tail -f logs/gcp_producer.log
    else
        print_error "No producer logs found. Start producers first."
        exit 1
    fi
}

check_status() {
    print_status "Multi-Cloud Architecture Status"
    print_status "==============================="
    
    AWS_RUNNING="❌"
    GCP_RUNNING="❌"

    # Check AWS Producer
    if [ -f ".aws_producer_pid" ]; then
        AWS_PID=$(cat .aws_producer_pid)
        if ps -p "$AWS_PID" > /dev/null; then
            AWS_RUNNING="✅ (PID: $AWS_PID)"
        fi
    fi

    # Check GCP Producer
    if [ -f ".gcp_producer_pid" ]; then
        GCP_PID=$(cat .gcp_producer_pid)
        if ps -p "$GCP_PID" > /dev/null; then
            GCP_RUNNING="✅ (PID: $GCP_PID)"
        fi
    fi

    echo "AWS Producer Status:  $AWS_RUNNING"
    echo "GCP Producer Status:  $GCP_RUNNING"
    echo ""
    
    # Show recent activity
    if [ -f "logs/aws_producer.log" ]; then
        echo "AWS Producer Recent Activity:"
        tail -n 3 logs/aws_producer.log
        echo ""
    fi
    
    if [ -f "logs/gcp_producer.log" ]; then
        echo "GCP Producer Recent Activity:"
        tail -n 3 logs/gcp_producer.log
        echo ""
    fi
}

# --- Main Script Logic ---
case "$1" in
    start)
        start_all_producers
        ;;
    stop)
        stop_all_producers
        ;;
    monitor)
        monitor_producers
        ;;
    status)
        check_status
        ;;
    *)
        print_error "Usage: $0 {start|stop|monitor|status}"
        echo ""
        echo "Commands:"
        echo "  start   - Start both AWS and GCP producers"
        echo "  stop    - Stop both AWS and GCP producers"
        echo "  monitor - Monitor logs from both producers"
        echo "  status  - Check status of both producers"
        exit 1
        ;;
esac