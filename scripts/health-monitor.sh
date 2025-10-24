#!/bin/bash

# BlockchainCore Health Monitor & Auto-Failover System
# Monitors AWS infrastructure and automatically switches to GCP on failure

# Common functions
source scripts/subscripts/common.sh

# Configuration
HEALTH_CHECK_INTERVAL=30  # seconds
AWS_TIMEOUT=10           # seconds
GCP_TIMEOUT=10          # seconds
MAX_FAILURES=3          # consecutive failures before failover
FAILOVER_LOG="logs/failover.log"

# State tracking
FAILURE_COUNT=0
LAST_HEALTHY_CLOUD="aws"
CURRENT_CLOUD="aws"
FAILOVER_TRIGGERED=false

# Create logs directory
mkdir -p logs

# --- Health Check Functions ---

check_aws_health() {
    print_status "Checking AWS health..."
    
    # Check SQS
    if ! aws sqs get-queue-attributes \
        --queue-url "$SQS_QUEUE_URL" \
        --attribute-names All \
        --output text >/dev/null 2>&1; then
        print_error "AWS SQS health check failed"
        return 1
    fi
    
    # Check Lambda
    if ! aws lambda get-function \
        --function-name blockchain-core-processor \
        --output text >/dev/null 2>&1; then
        print_error "AWS Lambda health check failed"
        return 1
    fi
    
    # Check DynamoDB
    if ! aws dynamodb describe-table \
        --table-name blockchain-core-ohlcv-data \
        --output text >/dev/null 2>&1; then
        print_error "AWS DynamoDB health check failed"
        return 1
    fi
    
    print_success "AWS health check passed"
    return 0
}

check_gcp_health() {
    print_status "Checking GCP health..."
    
    # Check Pub/Sub topic
    if ! gcloud pubsub topics describe blockchain-core-trade-data \
        --format="value(name)" >/dev/null 2>&1; then
        print_error "GCP Pub/Sub health check failed"
        return 1
    fi
    
    # Check Cloud Function
    if ! gcloud functions describe blockchain-core-processor \
        --format="value(name)" >/dev/null 2>&1; then
        print_error "GCP Cloud Function health check failed"
        return 1
    fi
    
    # Check Firestore
    if ! gcloud firestore databases describe \
        --database="(default)" \
        --format="value(name)" >/dev/null 2>&1; then
        print_error "GCP Firestore health check failed"
        return 1
    fi
    
    print_success "GCP health check passed"
    return 0
}

# --- Failover Functions ---

trigger_aws_to_gcp_failover() {
    print_warning "🚨 AWS FAILURE DETECTED - Triggering GCP Failover"
    
    # Log the failover event
    echo "$(date): AWS to GCP failover triggered" >> "$FAILOVER_LOG"
    
    # Stop AWS producer if running
    if [ -f ".aws_producer_pid" ]; then
        AWS_PID=$(cat .aws_producer_pid)
        if kill -0 "$AWS_PID" 2>/dev/null; then
            print_status "Stopping AWS producer (PID: $AWS_PID)"
            kill "$AWS_PID"
            rm -f .aws_producer_pid
        fi
    fi
    
    # Start GCP producer
    print_status "Starting GCP producer as failover..."
    if [ -f "scripts/subscripts/start-gcp-producer.sh" ]; then
        nohup ./scripts/subscripts/start-gcp-producer.sh > logs/gcp_failover.log 2>&1 &
        GCP_PID=$!
        echo "$GCP_PID" > .gcp_producer_pid
        print_success "GCP producer started as failover (PID: $GCP_PID)"
    else
        print_error "GCP producer script not found!"
        return 1
    fi
    
    # Update state
    CURRENT_CLOUD="gcp"
    FAILOVER_TRIGGERED=true
    FAILURE_COUNT=0
    
    # Send notification (if configured)
    send_failover_notification "AWS" "GCP"
}

trigger_gcp_to_aws_failover() {
    print_warning "🚨 GCP FAILURE DETECTED - Triggering AWS Failover"
    
    # Log the failover event
    echo "$(date): GCP to AWS failover triggered" >> "$FAILOVER_LOG"
    
    # Stop GCP producer if running
    if [ -f ".gcp_producer_pid" ]; then
        GCP_PID=$(cat .gcp_producer_pid)
        if kill -0 "$GCP_PID" 2>/dev/null; then
            print_status "Stopping GCP producer (PID: $GCP_PID)"
            kill "$GCP_PID"
            rm -f .gcp_producer_pid
        fi
    fi
    
    # Start AWS producer
    print_status "Starting AWS producer as failover..."
    if [ -f "scripts/subscripts/start-producer.sh" ]; then
        nohup ./scripts/subscripts/start-producer.sh > logs/aws_failover.log 2>&1 &
        AWS_PID=$!
        echo "$AWS_PID" > .aws_producer_pid
        print_success "AWS producer started as failover (PID: $AWS_PID)"
    else
        print_error "AWS producer script not found!"
        return 1
    fi
    
    # Update state
    CURRENT_CLOUD="aws"
    FAILOVER_TRIGGERED=true
    FAILURE_COUNT=0
    
    # Send notification (if configured)
    send_failover_notification "GCP" "AWS"
}

# --- Notification Functions ---

send_failover_notification() {
    local from_cloud="$1"
    local to_cloud="$2"
    
    print_status "Sending failover notification: $from_cloud → $to_cloud"
    
    # Log to file
    echo "$(date): Failover: $from_cloud → $to_cloud" >> "$FAILOVER_LOG"
    
    # Could integrate with Slack, email, etc.
    # For now, just log the event
    print_success "Failover notification sent"
}

# --- Main Health Monitoring Loop ---

start_health_monitoring() {
    print_header "🏥 Starting BlockchainCore Health Monitor"
    print_status "Health check interval: ${HEALTH_CHECK_INTERVAL}s"
    print_status "Max failures before failover: $MAX_FAILURES"
    print_status "Current cloud: $CURRENT_CLOUD"
    echo ""
    
    while true; do
        # Check current cloud health
        if [ "$CURRENT_CLOUD" = "aws" ]; then
            if check_aws_health; then
                FAILURE_COUNT=0
                LAST_HEALTHY_CLOUD="aws"
            else
                FAILURE_COUNT=$((FAILURE_COUNT + 1))
                print_warning "AWS health check failed ($FAILURE_COUNT/$MAX_FAILURES)"
                
                if [ "$FAILURE_COUNT" -ge "$MAX_FAILURES" ]; then
                    trigger_aws_to_gcp_failover
                fi
            fi
        else
            if check_gcp_health; then
                FAILURE_COUNT=0
                LAST_HEALTHY_CLOUD="gcp"
            else
                FAILURE_COUNT=$((FAILURE_COUNT + 1))
                print_warning "GCP health check failed ($FAILURE_COUNT/$MAX_FAILURES)"
                
                if [ "$FAILURE_COUNT" -ge "$MAX_FAILURES" ]; then
                    trigger_gcp_to_aws_failover
                fi
            fi
        fi
        
        # Wait before next check
        sleep "$HEALTH_CHECK_INTERVAL"
    done
}

# --- Manual Failover Functions ---

manual_failover_to_gcp() {
    print_status "Manual failover to GCP requested"
    trigger_aws_to_gcp_failover
}

manual_failover_to_aws() {
    print_status "Manual failover to AWS requested"
    trigger_gcp_to_aws_failover
}

# --- Status Functions ---

show_health_status() {
    print_header "📊 BlockchainCore Health Status"
    
    echo "Current Cloud: $CURRENT_CLOUD"
    echo "Last Healthy Cloud: $LAST_HEALTHY_CLOUD"
    echo "Failure Count: $FAILURE_COUNT/$MAX_FAILURES"
    echo "Failover Triggered: $FAILOVER_TRIGGERED"
    echo ""
    
    # Check AWS status
    print_status "AWS Status:"
    if check_aws_health; then
        print_success "✅ AWS is healthy"
    else
        print_error "❌ AWS is unhealthy"
    fi
    
    # Check GCP status
    print_status "GCP Status:"
    if check_gcp_health; then
        print_success "✅ GCP is healthy"
    else
        print_error "❌ GCP is unhealthy"
    fi
    
    # Show recent failover events
    if [ -f "$FAILOVER_LOG" ]; then
        echo ""
        print_status "Recent Failover Events:"
        tail -5 "$FAILOVER_LOG" 2>/dev/null || echo "No failover events recorded"
    fi
}

# --- Command Line Interface ---

case "${1:-}" in
    "start")
        start_health_monitoring
        ;;
    "status")
        show_health_status
        ;;
    "failover-gcp")
        manual_failover_to_gcp
        ;;
    "failover-aws")
        manual_failover_to_aws
        ;;
    "help"|"-h"|"--help")
        echo "BlockchainCore Health Monitor & Auto-Failover"
        echo ""
        echo "Usage:"
        echo "  ./scripts/health-monitor.sh start        - Start health monitoring"
        echo "  ./scripts/health-monitor.sh status      - Show current status"
        echo "  ./scripts/health-monitor.sh failover-gcp - Manual failover to GCP"
        echo "  ./scripts/health-monitor.sh failover-aws - Manual failover to AWS"
        echo "  ./scripts/health-monitor.sh help        - Show this help"
        echo ""
        echo "Features:"
        echo "  - Automatic health monitoring"
        echo "  - Auto-failover on cloud failure"
        echo "  - Manual failover controls"
        echo "  - Health status reporting"
        echo "  - Failover event logging"
        exit 0
        ;;
    *)
        print_error "Unknown command: ${1:-}"
        echo "Use './scripts/health-monitor.sh help' for usage information"
        exit 1
        ;;
esac
