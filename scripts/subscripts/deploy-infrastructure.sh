#!/bin/bash

# Infrastructure Deployment Subscript
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

# Check AWS configuration
check_aws_config() {
    print_status "Checking AWS configuration..."
    
    if ! aws sts get-caller-identity &>/dev/null; then
        print_error "AWS CLI not configured or credentials not set!"
        echo "Please run: aws configure"
        exit 1
    fi
    
    print_success "AWS CLI configured"
}

# Check Terraform installation
check_terraform() {
    print_status "Checking Terraform installation..."
    
    if ! command -v terraform &>/dev/null; then
        print_error "Terraform not found!"
        echo "Please install Terraform: https://www.terraform.io/downloads"
        exit 1
    fi
    
    print_success "Terraform found: $(terraform version | head -n1)"
}

# Initialize Terraform
init_terraform() {
    print_status "Initializing Terraform..."
    
    cd terraform-aws
    
    if ! terraform init; then
        print_error "Terraform initialization failed!"
        exit 1
    fi
    
    cd ..
    
    print_success "Terraform initialized"
}

# Deploy infrastructure
deploy_infrastructure() {
    print_status "Deploying infrastructure..."
    
    cd terraform-aws
    
    # Plan the deployment
    print_status "Planning deployment..."
    if ! terraform plan -out=tfplan; then
        print_error "Terraform plan failed!"
        exit 1
    fi
    
    # Apply the deployment
    print_status "Applying deployment..."
    if ! terraform apply tfplan; then
        print_error "Terraform apply failed!"
        exit 1
    fi
    
    # Clean up plan file
    rm -f tfplan
    
    cd ..
    
    print_success "Infrastructure deployed successfully!"
}

# Get deployment outputs
get_outputs() {
    print_status "Getting deployment outputs..."
    
    cd terraform-aws
    
    # Get environment variables
    echo ""
    echo "📋 Environment Variables for Producer:"
    echo "======================================"
    terraform output -json environment_variables | jq -r 'to_entries[] | "export \(.key)=\"\(.value)\""'
    
    # Get important URLs
    echo ""
    echo "🔗 Important URLs:"
    echo "=================="
    echo "SQS Queue URL: $(terraform output -raw sqs_queue_url)"
    echo "S3 Bucket: $(terraform output -raw s3_bucket_name)"
    echo "DynamoDB Table: $(terraform output -raw dynamodb_table_name)"
    
    cd ..
    
    print_success "Deployment outputs retrieved"
}

# Create .env file
create_env_file() {
    print_status "Creating .env file for producer..."
    
    cd terraform-aws
    
    # Create .env file with environment variables (with export keywords)
    terraform output -json environment_variables | jq -r 'to_entries[] | "export \(.key)=\(.value)"' > ../.env
    
    cd ..
    
    print_success "Created .env file"
}

# Main execution
main() {
    check_aws_config
    check_terraform
    init_terraform
    deploy_infrastructure
    get_outputs
    create_env_file
}

# Run main function
main "$@"
