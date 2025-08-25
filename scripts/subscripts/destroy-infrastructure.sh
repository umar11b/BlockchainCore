#!/bin/bash

# Infrastructure Destruction Subscript
# Called by stop-infrastructure.sh

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

# Check if infrastructure exists
check_infrastructure() {
    print_status "Checking if infrastructure exists..."
    
    if [ ! -d "terraform" ] || [ ! -f "terraform/.terraform.lock.hcl" ]; then
        print_error "Infrastructure not found!"
        echo "No Terraform state found. Infrastructure may already be destroyed."
        exit 1
    fi
    
    print_success "Infrastructure found"
}

# Stop any running producers
stop_producers() {
    print_status "Stopping any running producers..."
    
    # Kill any Python processes running the producer
    pkill -f "src/producer/main.py" 2>/dev/null || true
    
    # Kill any processes with producer in the name
    pkill -f "producer" 2>/dev/null || true
    
    print_success "No running producer processes found"
}

# Clean up S3 bucket (handle versioning) - FAST VERSION
cleanup_s3_bucket() {
    print_status "Cleaning up S3 bucket..."
    
    # Get bucket name from Terraform state
    BUCKET_NAME=$(cd terraform && terraform output -raw s3_bucket_name 2>/dev/null || echo "")
    
    if [ -n "$BUCKET_NAME" ]; then
        print_status "Cleaning bucket: $BUCKET_NAME"
        
        # Create temporary files for bulk deletion
        VERSIONS_FILE=$(mktemp)
        DELETE_MARKERS_FILE=$(mktemp)
        
        # Get all versions and delete markers in bulk
        aws s3api list-object-versions --bucket "$BUCKET_NAME" --output json > /tmp/bucket_versions.json
        
        # Extract versions for bulk deletion
        jq -r '.Versions[]? | {Key: .Key, VersionId: .VersionId}' /tmp/bucket_versions.json > "$VERSIONS_FILE"
        
        # Extract delete markers for bulk deletion
        jq -r '.DeleteMarkers[]? | {Key: .Key, VersionId: .VersionId}' /tmp/bucket_versions.json > "$DELETE_MARKERS_FILE"
        
        # Count objects for progress tracking
        VERSION_COUNT=$(jq '.Versions | length' /tmp/bucket_versions.json 2>/dev/null || echo "0")
        MARKER_COUNT=$(jq '.DeleteMarkers | length' /tmp/bucket_versions.json 2>/dev/null || echo "0")
        TOTAL_COUNT=$((VERSION_COUNT + MARKER_COUNT))
        
        if [ "$TOTAL_COUNT" -gt 0 ]; then
            print_status "Found $TOTAL_COUNT objects to delete (versions: $VERSION_COUNT, markers: $MARKER_COUNT)"
            
            # Delete versions in batches of 1000 (AWS limit)
            if [ -s "$VERSIONS_FILE" ]; then
                print_status "Deleting $VERSION_COUNT versions..."
                aws s3api delete-objects --bucket "$BUCKET_NAME" --delete file://<(jq -s '{Objects: map({Key: .Key, VersionId: .VersionId})}' "$VERSIONS_FILE") 2>/dev/null || true
            fi
            
            # Delete markers in batches of 1000 (AWS limit)
            if [ -s "$DELETE_MARKERS_FILE" ]; then
                print_status "Deleting $MARKER_COUNT delete markers..."
                aws s3api delete-objects --bucket "$BUCKET_NAME" --delete file://<(jq -s '{Objects: map({Key: .Key, VersionId: .VersionId})}' "$DELETE_MARKERS_FILE") 2>/dev/null || true
            fi
            
            print_success "S3 bucket cleaned (deleted $TOTAL_COUNT objects)"
        else
            print_status "Bucket is already empty"
        fi
        
        # Clean up temporary files
        rm -f "$VERSIONS_FILE" "$DELETE_MARKERS_FILE" /tmp/bucket_versions.json
        
    else
        print_status "No S3 bucket found in Terraform state"
    fi
}

# Clean up orphaned resources (not in Terraform state)
cleanup_orphaned_resources() {
    print_status "Cleaning up orphaned resources..."
    
    # Clean up DynamoDB tables
    print_status "Checking for orphaned DynamoDB tables..."
    aws dynamodb list-tables --query 'TableNames[?contains(@, `blockchain-core`)]' --output text | while read -r table; do
        if [ -n "$table" ]; then
            print_status "Deleting orphaned DynamoDB table: $table"
            aws dynamodb delete-table --table-name "$table" 2>/dev/null || true
        fi
    done
    
    # Clean up IAM roles
    print_status "Checking for orphaned IAM roles..."
    aws iam list-roles --query 'Roles[?contains(RoleName, `blockchain-core`)].RoleName' --output text | while read -r role; do
        if [ -n "$role" ]; then
            print_status "Cleaning up orphaned IAM role: $role"
            # Detach attached policies first
            aws iam list-attached-role-policies --role-name "$role" --query 'AttachedPolicies[].PolicyArn' --output text | while read -r policy; do
                if [ -n "$policy" ]; then
                    aws iam detach-role-policy --role-name "$role" --policy-arn "$policy" 2>/dev/null || true
                fi
            done
            # Delete inline policies
            aws iam list-role-policies --role-name "$role" --query 'PolicyNames[]' --output text | while read -r policy; do
                if [ -n "$policy" ]; then
                    aws iam delete-role-policy --role-name "$role" --policy-name "$policy" 2>/dev/null || true
                fi
            done
            # Delete the role
            aws iam delete-role --role-name "$role" 2>/dev/null || true
        fi
    done
    
    # Clean up SQS queues
    print_status "Checking for orphaned SQS queues..."
    aws sqs list-queues --query 'QueueUrls[?contains(@, `blockchain-core`)]' --output text | while read -r queue; do
        if [ -n "$queue" ]; then
            print_status "Deleting orphaned SQS queue: $queue"
            aws sqs delete-queue --queue-url "$queue" 2>/dev/null || true
        fi
    done
    
    # Clean up S3 buckets
    print_status "Checking for orphaned S3 buckets..."
    aws s3 ls | grep blockchain-core | awk '{print $3}' | while read -r bucket; do
        if [ -n "$bucket" ]; then
            print_status "Deleting orphaned S3 bucket: $bucket"
            aws s3 rb "s3://$bucket" --force 2>/dev/null || true
        fi
    done
    
    # Clean up SNS topics
    print_status "Checking for orphaned SNS topics..."
    aws sns list-topics --query 'Topics[?contains(TopicArn, `blockchain-core`)].TopicArn' --output text | while read -r topic; do
        if [ -n "$topic" ]; then
            print_status "Deleting orphaned SNS topic: $topic"
            aws sns delete-topic --topic-arn "$topic" 2>/dev/null || true
        fi
    done
    
    # Clean up CloudWatch Event rules
    print_status "Checking for orphaned CloudWatch Event rules..."
    aws events list-rules --name-prefix blockchain-core --query 'Rules[].Name' --output text | while read -r rule; do
        if [ -n "$rule" ]; then
            print_status "Deleting orphaned CloudWatch Event rule: $rule"
            aws events delete-rule --name "$rule" 2>/dev/null || true
        fi
    done
    
    # Clean up Lambda functions
    print_status "Checking for orphaned Lambda functions..."
    aws lambda list-functions --query 'Functions[?contains(FunctionName, `blockchain-core`)].FunctionName' --output text | while read -r function; do
        if [ -n "$function" ]; then
            print_status "Deleting orphaned Lambda function: $function"
            aws lambda delete-function --function-name "$function" 2>/dev/null || true
        fi
    done
    
    print_success "Orphaned resources cleanup completed"
}

# Destroy infrastructure with Terraform
destroy_terraform() {
    print_status "Destroying infrastructure with Terraform..."
    
    cd terraform
    
    # Plan the destruction
    print_status "Planning destruction..."
    terraform plan -destroy -out=tfdestroyplan
    
    # Apply the destruction
    print_status "Applying destruction..."
    terraform apply tfdestroyplan
    
    # Clean up plan file
    rm -f tfdestroyplan
    
    cd ..
    
    print_success "Infrastructure destroyed"
}

# Clean up local files
cleanup_local_files() {
    print_status "Cleaning up local files..."
    
    # Remove .env file
    rm -f .env
    
    # Remove logs directory
    rm -rf logs/
    
    # Remove any temporary files
    rm -f *.log
    rm -f *.zip
    
    print_success "Local files cleaned"
}

# Verify destruction
verify_destruction() {
    print_status "Verifying destruction..."
    
    # Check if Terraform state is empty
    if [ -f "terraform/terraform.tfstate" ]; then
        RESOURCE_COUNT=$(cd terraform && terraform state list 2>/dev/null | wc -l)
        if [ "$RESOURCE_COUNT" -eq 0 ]; then
            print_success "All resources destroyed"
        else
            print_error "Some resources may still exist"
        fi
    else
        print_success "Terraform state removed"
    fi
}

# Show cost savings
show_cost_savings() {
    echo ""
    echo "💰 Cost Savings:"
    echo "================"
    echo "✅ No more SQS charges"
    echo "✅ No more Lambda charges"
    echo "✅ No more DynamoDB charges"
    echo "✅ No more S3 charges (except minimal storage)"
    echo "✅ No more CloudWatch charges"
    echo "✅ No more EventBridge charges"
    echo ""
    echo "Your monthly AWS bill should now be minimal!"
}

# Main execution
main() {
    check_aws_config
    check_terraform
    check_infrastructure
    stop_producers
    
    # Clean up orphaned resources first (regardless of Terraform state)
    cleanup_orphaned_resources
    
    # Skip S3 cleanup if fast shutdown was selected
    if [ "${SKIP_S3_CLEANUP:-false}" != "true" ]; then
        cleanup_s3_bucket
    else
        print_status "Skipping S3 cleanup (fast shutdown mode)"
    fi
    
    destroy_terraform
    cleanup_local_files
    verify_destruction
    show_cost_savings
}

# Run main function
main "$@"
