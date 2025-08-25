#!/bin/bash

# Deploy Lambda functions for BlockchainCore
set -e

echo "🚀 Deploying Lambda functions..."

# Get the project directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to package and deploy a Lambda function
deploy_lambda() {
    local function_name=$1
    local source_dir=$2
    local handler=$3
    local zip_file=$4
    
    print_status "Deploying $function_name..."
    
    # Create build directory
    mkdir -p "$source_dir/build"
    
    # Copy source files
    cp -r "$source_dir"/*.py "$source_dir/build/"
    
    # Install dependencies if requirements.txt exists
    if [ -f "$source_dir/requirements.txt" ]; then
        print_status "Installing dependencies for $function_name..."
        pip install -r "$source_dir/requirements.txt" -t "$source_dir/build/"
    fi
    
    # Create ZIP file
    cd "$source_dir/build"
    zip -r "$zip_file" .
    cd "$PROJECT_DIR"
    
    # Deploy to AWS Lambda
    print_status "Uploading $function_name to AWS Lambda..."
    aws lambda update-function-code \
        --function-name "$function_name" \
        --zip-file "fileb://$source_dir/build/$zip_file"
    
    print_status "$function_name deployed successfully!"
}

# Deploy processor Lambda
deploy_lambda \
    "blockchain-core-processor" \
    "$PROJECT_DIR/src/lambda/processor" \
    "processor.lambda_handler" \
    "processor.zip"

# Deploy anomaly detector Lambda
deploy_lambda \
    "blockchain-core-anomaly-detector" \
    "$PROJECT_DIR/src/lambda/anomaly" \
    "detector.lambda_handler" \
    "anomaly.zip"

print_status "✅ All Lambda functions deployed successfully!"

# Clean up build directories
print_status "Cleaning up build artifacts..."
rm -rf "$PROJECT_DIR/src/lambda/processor/build"
rm -rf "$PROJECT_DIR/src/lambda/anomaly/build"

print_status "🎉 Lambda deployment complete!"
