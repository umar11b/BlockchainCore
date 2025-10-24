#!/bin/bash

# Deploy GCP Infrastructure for BlockchainCore Multi-Cloud Architecture
# This script deploys the GCP side of the multi-cloud setup

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Print functions
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

# Check if GCP CLI is installed
check_gcp_cli() {
    if ! command -v gcloud &> /dev/null; then
        print_error "Google Cloud CLI (gcloud) is not installed!"
        print_status "Please install it from: https://cloud.google.com/sdk/docs/install"
        exit 1
    fi
    print_success "Google Cloud CLI found"
}

# Check if user is authenticated
check_gcp_auth() {
    if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" | grep -q .; then
        print_error "Not authenticated with Google Cloud!"
        print_status "Please run: gcloud auth login"
        exit 1
    fi
    print_success "Google Cloud authentication verified"
}

# Check if project is set
check_gcp_project() {
    PROJECT_ID=$(gcloud config get-value project 2>/dev/null)
    if [ -z "$PROJECT_ID" ]; then
        print_error "No GCP project set!"
        print_status "Please set a project: gcloud config set project YOUR_PROJECT_ID"
        exit 1
    fi
    print_success "GCP project set: $PROJECT_ID"
}

# Check if required APIs are enabled
enable_apis() {
    print_status "Enabling required Google Cloud APIs..."
    
    APIs=(
        "pubsub.googleapis.com"
        "cloudfunctions.googleapis.com"
        "firestore.googleapis.com"
        "storage.googleapis.com"
        "cloudscheduler.googleapis.com"
        "logging.googleapis.com"
        "monitoring.googleapis.com"
    )
    
    for api in "${APIs[@]}"; do
        print_status "Enabling $api..."
        gcloud services enable "$api" --quiet
    done
    
    print_success "All required APIs enabled"
}

# Deploy Terraform infrastructure
deploy_infrastructure() {
    print_status "Deploying GCP infrastructure with Terraform..."
    
    cd terraform-gcp
    
    # Initialize Terraform
    print_status "Initializing Terraform..."
    terraform init
    
    # Plan deployment
    print_status "Planning Terraform deployment..."
    terraform plan -var="gcp_project_id=$PROJECT_ID"
    
    # Apply deployment
    print_status "Applying Terraform configuration..."
    terraform apply -auto-approve -var="gcp_project_id=$PROJECT_ID"
    
    # Get outputs
    print_status "Getting Terraform outputs..."
    terraform output -json > ../gcp-outputs.json
    
    cd ..
    print_success "GCP infrastructure deployed successfully"
}

# Deploy Cloud Function
deploy_cloud_function() {
    print_status "Deploying Cloud Function..."
    
    # Create function source directory
    FUNCTION_DIR="src/lambda/processor-gcp"
    BUILD_DIR="build/gcp-function"
    
    # Clean and create build directory
    rm -rf "$BUILD_DIR"
    mkdir -p "$BUILD_DIR"
    
    # Copy function code
    cp "$FUNCTION_DIR/processor.py" "$BUILD_DIR/"
    cp "$FUNCTION_DIR/requirements.txt" "$BUILD_DIR/"
    
    # Create deployment package
    cd "$BUILD_DIR"
    zip -r processor.zip .
    cd ../..
    
    # Upload to Cloud Storage
    BUCKET_NAME=$(jq -r '.storage_bucket_name.value' gcp-outputs.json)
    gsutil cp "$BUILD_DIR/processor.zip" "gs://$BUCKET_NAME/processor.zip"
    
    print_success "Cloud Function deployed"
}

# Create environment file for GCP
create_env_file() {
    print_status "Creating GCP environment file..."
    
    # Get outputs from Terraform
    PUBSUB_TOPIC=$(jq -r '.pubsub_topic_name.value' gcp-outputs.json)
    STORAGE_BUCKET=$(jq -r '.storage_bucket_name.value' gcp-outputs.json)
    FIRESTORE_DB=$(jq -r '.firestore_database_name.value' gcp-outputs.json)
    PROJECT_ID=$(jq -r '.gcp_project_id.value' gcp-outputs.json)
    REGION=$(jq -r '.gcp_region.value' gcp-outputs.json)
    
    # Create .env.gcp file
    cat > .env.gcp << EOF
# GCP Multi-Cloud Configuration
GCP_PROJECT_ID=$PROJECT_ID
GCP_REGION=$REGION
PUBSUB_TOPIC=$PUBSUB_TOPIC
STORAGE_BUCKET=$STORAGE_BUCKET
FIRESTORE_DATABASE=$FIRESTORE_DB
TRADING_SYMBOL=BTCUSDT

# GCP Service Account (if needed)
# GOOGLE_APPLICATION_CREDENTIALS=path/to/service-account.json
EOF
    
    print_success "GCP environment file created: .env.gcp"
}

# Test GCP deployment
test_deployment() {
    print_status "Testing GCP deployment..."
    
    # Test Pub/Sub topic
    print_status "Testing Pub/Sub topic..."
    gcloud pubsub topics list --filter="name:$PUBSUB_TOPIC" --format="value(name)" | grep -q "$PUBSUB_TOPIC" && print_success "Pub/Sub topic exists" || print_error "Pub/Sub topic not found"
    
    # Test Firestore database
    print_status "Testing Firestore database..."
    gcloud firestore databases list --format="value(name)" | grep -q "blockchain-core" && print_success "Firestore database exists" || print_error "Firestore database not found"
    
    # Test Cloud Storage bucket
    print_status "Testing Cloud Storage bucket..."
    gsutil ls | grep -q "$STORAGE_BUCKET" && print_success "Storage bucket exists" || print_error "Storage bucket not found"
    
    print_success "GCP deployment test completed"
}

# Main deployment function
main() {
    print_status "🚀 Starting GCP Multi-Cloud Deployment"
    print_status "======================================"
    
    # Pre-deployment checks
    check_gcp_cli
    check_gcp_auth
    check_gcp_project
    
    # Deploy infrastructure
    enable_apis
    deploy_infrastructure
    deploy_cloud_function
    create_env_file
    test_deployment
    
    print_success "🎉 GCP Multi-Cloud Deployment Complete!"
    print_status "======================================"
    print_status "Next steps:"
    print_status "1. Start GCP producer: source .env.gcp && python3 src/producer/gcp_producer.py"
    print_status "2. Monitor resources: gcloud monitoring dashboards list"
    print_status "3. View logs: gcloud logging read 'resource.type=\"cloud_function\"'"
    print_status "4. Check Firestore: gcloud firestore databases list"
}

# Run main function
main "$@"
