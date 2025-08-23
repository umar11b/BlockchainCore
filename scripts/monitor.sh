#!/bin/bash

# BlockchainCore Infrastructure Monitoring Script
# Interactive dashboard for monitoring infrastructure status

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

print_header() {
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                    BlockchainCore Monitor                    ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

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

# Check if .env file exists
check_env() {
    if [ ! -f ".env" ]; then
        print_error "Environment file not found!"
        echo "Please run: ./scripts/start-infrastructure.sh"
        exit 1
    fi
    
    # Load environment variables
    export $(cat .env | xargs)
}

# Show menu
show_menu() {
    echo "Select an option:"
    echo ""
    echo "1. SQS Queue Status"
    echo "2. DynamoDB Table Status"
    echo "3. S3 Bucket Status"
    echo "4. Lambda Functions Status"
    echo "5. Recent Lambda Logs"
    echo "6. Producer Status"
    echo "7. Cost Estimate"
    echo "8. All Services Status"
    echo "9. Infrastructure Health Check"
    echo "0. Exit"
    echo ""
}

# Check SQS status
check_sqs() {
    print_status "Checking SQS Queue..."
    
    if [ -z "$SQS_QUEUE_URL" ]; then
        print_error "SQS_QUEUE_URL not found in environment"
        return
    fi
    
    # Get queue attributes
    ATTRIBUTES=$(aws sqs get-queue-attributes \
        --queue-url "$SQS_QUEUE_URL" \
        --attribute-names All \
        --query 'Attributes.{Messages:ApproximateNumberOfMessages,InFlight:ApproximateNumberOfMessagesNotVisible,Delayed:ApproximateNumberOfMessagesDelayed}' \
        --output json 2>/dev/null || echo '{}')
    
    echo "SQS Queue Status:"
    echo "  Messages in queue: $(echo $ATTRIBUTES | jq -r '.Messages // "0"')"
    echo "  Messages in flight: $(echo $ATTRIBUTES | jq -r '.InFlight // "0"')"
    echo "  Delayed messages: $(echo $ATTRIBUTES | jq -r '.Delayed // "0"')"
    echo ""
}

# Check DynamoDB status
check_dynamodb() {
    print_status "Checking DynamoDB Table..."
    
    if [ -z "$DYNAMODB_TABLE_NAME" ]; then
        print_error "DYNAMODB_TABLE_NAME not found in environment"
        return
    fi
    
    # Get table status
    TABLE_STATUS=$(aws dynamodb describe-table \
        --table-name "$DYNAMODB_TABLE_NAME" \
        --query 'Table.{Status:TableStatus,Items:ItemCount,Size:TableSizeBytes}' \
        --output json 2>/dev/null || echo '{}')
    
    echo "DynamoDB Table Status:"
    echo "  Status: $(echo $TABLE_STATUS | jq -r '.Status // "Unknown"')"
    echo "  Items: $(echo $TABLE_STATUS | jq -r '.Items // "0"')"
    echo "  Size: $(echo $TABLE_STATUS | jq -r '.Size // "0"') bytes"
    echo ""
}

# Check S3 status
check_s3() {
    print_status "Checking S3 Bucket..."
    
    if [ -z "$S3_BUCKET_NAME" ]; then
        print_error "S3_BUCKET_NAME not found in environment"
        return
    fi
    
    # Get bucket info
    BUCKET_SIZE=$(aws s3 ls s3://"$S3_BUCKET_NAME" --recursive --summarize 2>/dev/null | tail -1 | awk '{print $3}' || echo "0")
    OBJECT_COUNT=$(aws s3 ls s3://"$S3_BUCKET_NAME" --recursive --summarize 2>/dev/null | tail -2 | head -1 | awk '{print $2}' || echo "0")
    
    echo "S3 Bucket Status:"
    echo "  Bucket: $S3_BUCKET_NAME"
    echo "  Objects: $OBJECT_COUNT"
    echo "  Size: $BUCKET_SIZE bytes"
    echo ""
}

# Check Lambda functions
check_lambda() {
    print_status "Checking Lambda Functions..."
    
    FUNCTIONS=("blockchain-core-processor" "blockchain-core-anomaly-detector")
    
    for func in "${FUNCTIONS[@]}"; do
        echo "Function: $func"
        
        # Get function configuration
        CONFIG=$(aws lambda get-function \
            --function-name "$func" \
            --query 'Configuration.{Runtime:Runtime,Timeout:Timeout,MemorySize:MemorySize,LastModified:LastModified}' \
            --output json 2>/dev/null || echo '{}')
        
        echo "  Runtime: $(echo $CONFIG | jq -r '.Runtime // "Unknown"')"
        echo "  Timeout: $(echo $CONFIG | jq -r '.Timeout // "Unknown"')s"
        echo "  Memory: $(echo $CONFIG | jq -r '.MemorySize // "Unknown"')MB"
        echo "  Last Modified: $(echo $CONFIG | jq -r '.LastModified // "Unknown"')"
        echo ""
    done
}

# Show recent Lambda logs
show_lambda_logs() {
    print_status "Recent Lambda Logs..."
    
    FUNCTIONS=("blockchain-core-processor" "blockchain-core-anomaly-detector")
    
    for func in "${FUNCTIONS[@]}"; do
        echo "=== $func ==="
        
        # Get recent log streams
        LOG_STREAMS=$(aws logs describe-log-streams \
            --log-group-name "/aws/lambda/$func" \
            --order-by LastEventTime \
            --descending \
            --max-items 1 \
            --query 'logStreams[0].logStreamName' \
            --output text 2>/dev/null || echo "")
        
        if [ -n "$LOG_STREAMS" ] && [ "$LOG_STREAMS" != "None" ]; then
            # Get recent events
            aws logs get-log-events \
                --log-group-name "/aws/lambda/$func" \
                --log-stream-name "$LOG_STREAMS" \
                --start-time $(date -d '1 hour ago' +%s)000 \
                --query 'events[*].message' \
                --output text 2>/dev/null | tail -5 || echo "No recent logs"
        else
            echo "No log streams found"
        fi
        echo ""
    done
}

# Check producer status
check_producer() {
    print_status "Checking Producer Status..."
    
    if pgrep -f "src/producer/main.py" > /dev/null; then
        print_success "Producer is running"
        
        # Show recent logs
        if [ -f "logs/producer.log" ]; then
            echo "Recent producer logs:"
            tail -5 logs/producer.log
        fi
    else
        print_warning "Producer is not running"
    fi
    echo ""
}

# Show cost estimate
show_cost_estimate() {
    print_status "Cost Estimate (Last 24 hours)..."
    
    # Get cost data for last 24 hours
    COST=$(aws ce get-cost-and-usage \
        --time-period Start=$(date -d '1 day ago' +%Y-%m-%d),End=$(date +%Y-%m-%d) \
        --granularity DAILY \
        --metrics BlendedCost \
        --group-by Type=DIMENSION,Key=SERVICE \
        --query 'ResultsByTime[0].Groups[?contains(Keys[0].Value, `Lambda`) || contains(Keys[0].Value, `SQS`) || contains(Keys[0].Value, `DynamoDB`) || contains(Keys[0].Value, `S3`)].{Service:Keys[0].Value,Cost:Metrics.BlendedCost.Amount}' \
        --output json 2>/dev/null || echo '[]')
    
    if [ "$COST" != "[]" ]; then
        echo "Service Costs:"
        echo "$COST" | jq -r '.[] | "  \(.Service): $\(.Cost)"'
    else
        echo "No cost data available for last 24 hours"
    fi
    echo ""
}

# Show all services status
show_all_status() {
    print_status "All Services Status..."
    echo ""
    
    check_sqs
    check_dynamodb
    check_s3
    check_lambda
    check_producer
}

# Health check
health_check() {
    print_status "Infrastructure Health Check..."
    echo ""
    
    # Check if all required services are running
    SERVICES_OK=0
    TOTAL_SERVICES=0
    
    # Check SQS
    TOTAL_SERVICES=$((TOTAL_SERVICES + 1))
    if aws sqs get-queue-attributes --queue-url "$SQS_QUEUE_URL" --attribute-names QueueArn &>/dev/null; then
        print_success "SQS Queue: OK"
        SERVICES_OK=$((SERVICES_OK + 1))
    else
        print_error "SQS Queue: FAILED"
    fi
    
    # Check DynamoDB
    TOTAL_SERVICES=$((TOTAL_SERVICES + 1))
    if aws dynamodb describe-table --table-name "$DYNAMODB_TABLE_NAME" &>/dev/null; then
        print_success "DynamoDB Table: OK"
        SERVICES_OK=$((SERVICES_OK + 1))
    else
        print_error "DynamoDB Table: FAILED"
    fi
    
    # Check S3
    TOTAL_SERVICES=$((TOTAL_SERVICES + 1))
    if aws s3 ls s3://"$S3_BUCKET_NAME" &>/dev/null; then
        print_success "S3 Bucket: OK"
        SERVICES_OK=$((SERVICES_OK + 1))
    else
        print_error "S3 Bucket: FAILED"
    fi
    
    # Check Lambda functions
    TOTAL_SERVICES=$((TOTAL_SERVICES + 2))
    for func in "blockchain-core-processor" "blockchain-core-anomaly-detector"; do
        if aws lambda get-function --function-name "$func" &>/dev/null; then
            print_success "Lambda $func: OK"
            SERVICES_OK=$((SERVICES_OK + 1))
        else
            print_error "Lambda $func: FAILED"
        fi
    done
    
    # Check producer
    TOTAL_SERVICES=$((TOTAL_SERVICES + 1))
    if pgrep -f "src/producer/main.py" > /dev/null; then
        print_success "Producer: OK"
        SERVICES_OK=$((SERVICES_OK + 1))
    else
        print_error "Producer: FAILED"
    fi
    
    echo ""
    echo "Health Summary: $SERVICES_OK/$TOTAL_SERVICES services healthy"
    
    if [ $SERVICES_OK -eq $TOTAL_SERVICES ]; then
        print_success "All systems operational!"
    else
        print_warning "Some services need attention"
    fi
    echo ""
}

# Main function
main() {
    print_header
    
    # Check environment
    check_env
    
    while true; do
        show_menu
        read -p "Enter your choice (0-9): " choice
        
        case $choice in
            1)
                check_sqs
                ;;
            2)
                check_dynamodb
                ;;
            3)
                check_s3
                ;;
            4)
                check_lambda
                ;;
            5)
                show_lambda_logs
                ;;
            6)
                check_producer
                ;;
            7)
                show_cost_estimate
                ;;
            8)
                show_all_status
                ;;
            9)
                health_check
                ;;
            0)
                print_status "Exiting monitor..."
                exit 0
                ;;
            *)
                print_error "Invalid option. Please try again."
                ;;
        esac
        
        echo "Press Enter to continue..."
        read
        clear
        print_header
    done
}

# Run main function
main "$@"
