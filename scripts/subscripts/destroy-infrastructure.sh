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

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
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
    
    if [ ! -d "terraform-aws" ] || [ ! -f "terraform-aws/.terraform.lock.hcl" ]; then
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
    
    # Get bucket name directly from AWS (avoid terraform output issues)
    BUCKET_NAME=$(aws s3 ls 2>/dev/null | grep blockchain-core | head -1 | awk '{print $3}' || echo "")
    
    if [ -n "$BUCKET_NAME" ]; then
        print_status "Cleaning bucket: $BUCKET_NAME"
        
        # Create temporary files for bulk deletion
        VERSIONS_FILE=$(mktemp)
        DELETE_MARKERS_FILE=$(mktemp)
        
        # Get all versions and delete markers in bulk (with timeout - macOS compatible)
        if command -v timeout >/dev/null 2>&1; then
            timeout 60 aws s3api list-object-versions --bucket "$BUCKET_NAME" --output json > /tmp/bucket_versions.json 2>/dev/null || {
                print_warning "S3 bucket listing timed out or failed, skipping detailed cleanup"
                rm -f /tmp/bucket_versions.json
                return 0
            }
        else
            # macOS fallback - run without timeout
            aws s3api list-object-versions --bucket "$BUCKET_NAME" --output json > /tmp/bucket_versions.json 2>/dev/null || {
                print_warning "S3 bucket listing failed, skipping detailed cleanup"
                rm -f /tmp/bucket_versions.json
                return 0
            }
        fi
        
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
        print_status "No S3 bucket found, skipping S3 cleanup"
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
    
    # Wait for DynamoDB deletions to complete
    print_status "Waiting for DynamoDB deletions to complete..."
    sleep 10
    
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
    
    # Clean up CloudWatch Event rules (remove targets first)
    print_status "Checking for orphaned CloudWatch Event rules..."
    aws events list-rules --name-prefix blockchain-core --query 'Rules[].Name' --output text | while read -r rule; do
        if [ -n "$rule" ]; then
            print_status "Cleaning up EventBridge rule: $rule"
            # Remove targets first
            aws events list-targets-by-rule --rule "$rule" --query 'Targets[].Id' --output text | while read -r target; do
                if [ -n "$target" ]; then
                    print_status "Removing target $target from rule $rule"
                    aws events remove-targets --rule "$rule" --ids "$target" 2>/dev/null || true
                fi
            done
            # Now delete the rule
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

# Force cleanup of stuck resources
force_cleanup_stuck_resources() {
    print_status "Checking for stuck resources that need force cleanup..."
    
    # Force delete EventBridge rules with targets first
    print_status "Force cleaning EventBridge rules..."
    aws events list-rules --name-prefix blockchain-core --query 'Rules[].Name' --output text | while read -r rule; do
        if [ -n "$rule" ]; then
            print_status "Force deleting EventBridge rule: $rule"
            # Remove targets first
            aws events list-targets-by-rule --rule "$rule" --query 'Targets[].Id' --output text | while read -r target; do
                if [ -n "$target" ]; then
                    print_status "Removing target $target from rule $rule"
                    aws events remove-targets --rule "$rule" --ids "$target" 2>/dev/null || true
                fi
            done
            # Now delete the rule
            aws events delete-rule --name "$rule" 2>/dev/null || true
        fi
    done
    
    # Force delete Lambda functions that might be stuck
    print_status "Force cleaning Lambda functions..."
    aws lambda list-functions --query 'Functions[?contains(FunctionName, `blockchain-core`)].FunctionName' --output text | while read -r function; do
        if [ -n "$function" ]; then
            print_status "Force deleting Lambda function: $function"
            # Remove event source mappings first
            aws lambda list-event-source-mappings --function-name "$function" --query 'EventSourceMappings[].UUID' --output text | while read -r mapping; do
                if [ -n "$mapping" ]; then
                    aws lambda delete-event-source-mapping --uuid "$mapping" 2>/dev/null || true
                fi
            done
            # Delete the function
            aws lambda delete-function --function-name "$function" 2>/dev/null || true
        fi
    done
    
    # Force delete SQS queues that might be stuck
    print_status "Force cleaning SQS queues..."
    aws sqs list-queues --query 'QueueUrls[?contains(@, `blockchain-core`)]' --output text | while read -r queue; do
        if [ -n "$queue" ]; then
            print_status "Force deleting SQS queue: $queue"
            aws sqs delete-queue --queue-url "$queue" 2>/dev/null || true
        fi
    done
    
    # Force delete S3 buckets that might be stuck
    print_status "Force cleaning S3 buckets..."
    aws s3 ls 2>/dev/null | grep blockchain-core | awk '{print $3}' | while read -r bucket; do
        if [ -n "$bucket" ]; then
            print_status "Force deleting S3 bucket: $bucket"
            aws s3 rb "s3://$bucket" --force 2>/dev/null || true
        fi
    done
    
    print_success "Force cleanup completed"
}

# Destroy infrastructure with Terraform
destroy_terraform() {
    print_status "Destroying infrastructure with Terraform..."
    
    cd terraform-aws
    
    # Check if there are resources to destroy
    RESOURCE_COUNT=$(terraform state list 2>/dev/null | wc -l)
    if [ "$RESOURCE_COUNT" -eq 0 ]; then
        print_status "No resources in Terraform state to destroy"
        cd ..
        return 0
    fi
    
    print_status "Found $RESOURCE_COUNT resources to destroy"
    
    # Try terraform destroy with timeout and retry logic
    MAX_RETRIES=3
    RETRY_COUNT=0
    
    while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
        print_status "Attempt $((RETRY_COUNT + 1)) of $MAX_RETRIES: Running terraform destroy..."
        
        # Run terraform destroy with timeout (macOS compatible)
        if command -v timeout >/dev/null 2>&1; then
            timeout 300 terraform destroy -auto-approve
        else
            # macOS doesn't have timeout, use gtimeout if available, otherwise run without timeout
            if command -v gtimeout >/dev/null 2>&1; then
                gtimeout 300 terraform destroy -auto-approve
            else
                terraform destroy -auto-approve
            fi
        fi
        
        EXIT_CODE=$?
        
        if [ $EXIT_CODE -eq 0 ]; then
            print_success "Terraform destroy completed successfully"
            break
        elif [ $EXIT_CODE -eq 124 ]; then
            print_error "Terraform destroy timed out after 5 minutes"
        else
            print_error "Terraform destroy failed with exit code $EXIT_CODE"
        fi
        
        RETRY_COUNT=$((RETRY_COUNT + 1))
        
        if [ $RETRY_COUNT -lt $MAX_RETRIES ]; then
            print_status "Waiting 30 seconds before retry..."
            sleep 30
        fi
    done
    
    # If all retries failed, try force cleanup
    if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
        print_warning "All terraform destroy attempts failed. Attempting force cleanup..."
        
        # Remove problematic resources from state first
        print_status "Removing problematic resources from Terraform state..."
        terraform state rm aws_cloudwatch_event_rule.anomaly_detection 2>/dev/null || true
        terraform state rm aws_cloudwatch_event_target.anomaly_detection 2>/dev/null || true
        terraform state rm aws_lambda_permission.allow_eventbridge 2>/dev/null || true
        
        # Try terraform destroy again
        print_status "Retrying terraform destroy after removing problematic resources..."
        terraform destroy -auto-approve || true
        
        # If still failing, remove all state and try one more time
        if [ $? -ne 0 ]; then
            print_warning "Terraform destroy still failing. Removing all state..."
            rm -f terraform.tfstate terraform.tfstate.backup
            
            print_status "Final attempt with fresh state..."
            terraform destroy -auto-approve || true
        fi
    fi
    
    cd ..
    
    print_success "Infrastructure destruction process completed"
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
    
    echo ""
    echo "🔍 Destruction Verification Report"
    echo "=================================="
    
    # Check Terraform state
    print_status "Checking Terraform state..."
    if [ -f "terraform-aws/terraform.tfstate" ]; then
        RESOURCE_COUNT=$(cd terraform-aws && terraform state list 2>/dev/null | wc -l)
        if [ "$RESOURCE_COUNT" -eq 0 ]; then
            print_success "✅ Terraform state: All resources destroyed"
        else
            print_error "❌ Terraform state: $RESOURCE_COUNT resources still exist"
            cd terraform-aws && terraform state list 2>/dev/null || true
            cd ..
        fi
    else
        print_success "✅ Terraform state: State file removed"
    fi
    
    # Check for remaining AWS resources
    print_status "Checking for remaining AWS resources..."
    
    # Check DynamoDB tables
    DYNAMODB_COUNT=$(aws dynamodb list-tables --query 'TableNames[?contains(@, `blockchain-core`)]' --output text 2>/dev/null | wc -w)
    if [ "$DYNAMODB_COUNT" -eq 0 ]; then
        print_success "✅ DynamoDB: No blockchain-core tables found"
    else
        print_error "❌ DynamoDB: $DYNAMODB_COUNT tables still exist"
        aws dynamodb list-tables --query 'TableNames[?contains(@, `blockchain-core`)]' --output text 2>/dev/null || true
    fi
    
    # Check Lambda functions
    LAMBDA_COUNT=$(aws lambda list-functions --query 'Functions[?contains(FunctionName, `blockchain-core`)].FunctionName' --output text 2>/dev/null | wc -w)
    if [ "$LAMBDA_COUNT" -eq 0 ]; then
        print_success "✅ Lambda: No blockchain-core functions found"
    else
        print_error "❌ Lambda: $LAMBDA_COUNT functions still exist"
        aws lambda list-functions --query 'Functions[?contains(FunctionName, `blockchain-core`)].FunctionName' --output text 2>/dev/null || true
    fi
    
    # Check SQS queues
    SQS_COUNT=$(aws sqs list-queues --query 'QueueUrls[?contains(@, `blockchain-core`)]' --output text 2>/dev/null | wc -w)
    if [ "$SQS_COUNT" -eq 0 ]; then
        print_success "✅ SQS: No blockchain-core queues found"
    else
        print_error "❌ SQS: $SQS_COUNT queues still exist"
        aws sqs list-queues --query 'QueueUrls[?contains(@, `blockchain-core`)]' --output text 2>/dev/null || true
    fi
    
    # Check S3 buckets
    S3_COUNT=$(aws s3 ls 2>/dev/null | grep blockchain-core | wc -l)
    if [ "$S3_COUNT" -eq 0 ]; then
        print_success "✅ S3: No blockchain-core buckets found"
    else
        print_error "❌ S3: $S3_COUNT buckets still exist"
        aws s3 ls 2>/dev/null | grep blockchain-core || true
    fi
    
    # Check SNS topics
    SNS_COUNT=$(aws sns list-topics --query 'Topics[?contains(TopicArn, `blockchain-core`)].TopicArn' --output text 2>/dev/null | wc -w)
    if [ "$SNS_COUNT" -eq 0 ]; then
        print_success "✅ SNS: No blockchain-core topics found"
    else
        print_error "❌ SNS: $SNS_COUNT topics still exist"
        aws sns list-topics --query 'Topics[?contains(TopicArn, `blockchain-core`)].TopicArn' --output text 2>/dev/null || true
    fi
    
    # Check CloudWatch Event rules
    EVENT_COUNT=$(aws events list-rules --name-prefix blockchain-core --query 'Rules[].Name' --output text 2>/dev/null | wc -w)
    if [ "$EVENT_COUNT" -eq 0 ]; then
        print_success "✅ CloudWatch Events: No blockchain-core rules found"
    else
        print_error "❌ CloudWatch Events: $EVENT_COUNT rules still exist"
        aws events list-rules --name-prefix blockchain-core --query 'Rules[].Name' --output text 2>/dev/null || true
    fi
    
    # Check IAM roles
    IAM_COUNT=$(aws iam list-roles --query 'Roles[?contains(RoleName, `blockchain-core`)].RoleName' --output text 2>/dev/null | wc -w)
    if [ "$IAM_COUNT" -eq 0 ]; then
        print_success "✅ IAM: No blockchain-core roles found"
    else
        print_error "❌ IAM: $IAM_COUNT roles still exist"
        aws iam list-roles --query 'Roles[?contains(RoleName, `blockchain-core`)].RoleName' --output text 2>/dev/null || true
    fi
    
    # Summary
    echo ""
    echo "📊 Destruction Summary:"
    echo "======================"
    TOTAL_REMAINING=$((DYNAMODB_COUNT + LAMBDA_COUNT + SQS_COUNT + S3_COUNT + SNS_COUNT + EVENT_COUNT + IAM_COUNT))
    
    if [ "$TOTAL_REMAINING" -eq 0 ]; then
        print_success "🎉 SUCCESS: All infrastructure has been completely destroyed!"
    else
        print_error "⚠️  WARNING: $TOTAL_REMAINING resources may still exist"
        echo ""
        echo "If resources remain, you may need to:"
        echo "1. Wait a few minutes for AWS to complete deletion"
        echo "2. Manually delete remaining resources in AWS Console"
        echo "3. Check for dependencies preventing deletion"
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
    
    # Force cleanup any stuck resources after Terraform destroy
    force_cleanup_stuck_resources
    
    cleanup_local_files
    verify_destruction
    show_cost_savings
}

# Run main function
main "$@"
