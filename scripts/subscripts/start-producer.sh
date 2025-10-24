#!/bin/bash

# Producer Startup Subscript
# Called by start-infrastructure.sh

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if .env file exists
check_env_file() {
    print_status "Checking environment configuration..."
    
    if [ ! -f ".env" ]; then
        print_error ".env file not found!"
        echo ""
        echo "Please run the infrastructure startup script first:"
        echo "  ./scripts/start-infrastructure.sh"
        exit 1
    fi
    
    print_success "Environment file found"
}

# Load environment variables
load_environment() {
    print_status "Loading environment variables..."
    
    # Source the .env file
    set -a  # automatically export all variables
    source .env
    set +a
    
    # Check required variables
    required_vars=("SQS_QUEUE_URL" "S3_BUCKET_NAME" "DYNAMODB_TABLE_NAME")
    
    for var in "${required_vars[@]}"; do
        if [ -z "${!var}" ]; then
            print_error "Required environment variable $var is not set!"
            exit 1
        fi
    done
    
    print_success "Environment variables loaded"
}

# Check if infrastructure is running
check_infrastructure() {
    print_status "Checking infrastructure status..."
    
    # Check SQS queue
    if ! aws sqs get-queue-attributes --queue-url "$SQS_QUEUE_URL" --attribute-names QueueArn &>/dev/null; then
        print_error "SQS queue not found or not accessible!"
        echo "Please ensure infrastructure is running: ./scripts/start-infrastructure.sh"
        exit 1
    fi
    
    # Check S3 bucket
    if ! aws s3 ls "s3://$S3_BUCKET_NAME" &>/dev/null; then
        print_error "S3 bucket not found or not accessible!"
        echo "Please ensure infrastructure is running: ./scripts/start-infrastructure.sh"
        exit 1
    fi
    
    # Check DynamoDB table
    if ! aws dynamodb describe-table --table-name "$DYNAMODB_TABLE_NAME" &>/dev/null; then
        print_error "DynamoDB table not found or not accessible!"
        echo "Please ensure infrastructure is running: ./scripts/start-infrastructure.sh"
        exit 1
    fi
    
    print_success "Infrastructure is running"
}

# Check Python dependencies
check_dependencies() {
    print_status "Checking Python dependencies..."
    
    # Check if required packages are installed
    required_packages=("boto3" "websockets")
    
    # Check if virtual environment exists
    if [ -d "venv" ]; then
        print_status "Using virtual environment..."
        source venv/bin/activate
    fi
    
    for package in "${required_packages[@]}"; do
        if ! python3 -c "import $package" &>/dev/null; then
            print_error "Python package '$package' not found!"
            echo "Please install dependencies: pip install -r requirements.txt"
            exit 1
        fi
    done
    
    print_success "Python dependencies satisfied"
}

# Start the producer
start_producer() {
    print_status "Starting producer..."
    
    echo ""
    echo "🚀 Producer Configuration:"
    echo "=========================="
    echo "SQS Queue: $SQS_QUEUE_URL"
    echo "S3 Bucket: $S3_BUCKET_NAME"
    echo "DynamoDB Table: $DYNAMODB_TABLE_NAME"
    echo "Trading Symbol: ${TRADING_SYMBOL:-BTCUSDT}"
    echo ""
    
    # Create logs directory if it doesn't exist
    mkdir -p logs
    
    # Start the producer with logging
    print_status "Starting producer process..."
    echo "Logs will be written to: logs/producer.log"
    echo ""
    echo "Press Ctrl+C to stop the producer"
    echo ""
    
    # Start the producer (with virtual environment if available)
    if [ -d "venv" ]; then
        source venv/bin/activate
    fi
    python3 src/producer/main.py 2>&1 | tee logs/producer.log
}

# Main execution
main() {
    check_env_file
    load_environment
    check_infrastructure
    check_dependencies
    start_producer
}

# Handle Ctrl+C gracefully
trap 'echo ""; print_warning "Producer stopped by user"; exit 0' INT

# Run main function
main "$@"
