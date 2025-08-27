#!/bin/bash

# Deploy API Lambda function for BlockchainCore frontend
set -e

echo "🚀 Deploying BlockchainCore API Lambda..."

# Get the current directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
API_DIR="$PROJECT_DIR/src/lambda/api"

# Check if we're in the right directory
if [ ! -f "$API_DIR/api-handler.py" ]; then
    echo "❌ Error: API handler not found at $API_DIR/api-handler.py"
    exit 1
fi

# Create deployment package
echo "📦 Creating deployment package..."
cd "$API_DIR"

# Create a temporary directory for the package
TEMP_DIR=$(mktemp -d)
cp api-handler.py "$TEMP_DIR/"
cp requirements.txt "$TEMP_DIR/"

# Install dependencies
pip install -r requirements.txt -t "$TEMP_DIR/" --quiet

# Create ZIP file
cd "$TEMP_DIR"
zip -r api-handler.zip . -q

# Get AWS region and account info
REGION=$(aws configure get region)
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

echo "📍 Region: $REGION"
echo "🏢 Account: $ACCOUNT_ID"

# Get Terraform outputs
cd "$PROJECT_DIR/terraform"
DYNAMODB_TABLE=$(terraform output -raw dynamodb_table_name)
S3_BUCKET=$(terraform output -raw s3_bucket_name)
SNS_TOPIC=$(terraform output -raw sns_topic_arn)
ROLE_ARN=$(terraform output -raw lambda_role_arn)

echo "📋 Environment Variables:"
echo "  DYNAMODB_TABLE_NAME: $DYNAMODB_TABLE"
echo "  S3_BUCKET_NAME: $S3_BUCKET"
echo "  SNS_TOPIC_ARN: $SNS_TOPIC"

# Deploy to AWS Lambda
echo "☁️ Deploying to AWS Lambda..."

# Check if function exists
if aws lambda get-function --function-name blockchaincore-api --region "$REGION" >/dev/null 2>&1; then
    echo "📝 Updating existing Lambda function..."
    aws lambda update-function-code \
        --function-name blockchaincore-api \
        --zip-file fileb://"$TEMP_DIR/api-handler.zip" \
        --region "$REGION"
    
    # Update environment variables
    aws lambda update-function-configuration \
        --function-name blockchaincore-api \
        --environment "Variables={DYNAMODB_TABLE_NAME=$DYNAMODB_TABLE,S3_BUCKET_NAME=$S3_BUCKET,SNS_TOPIC_ARN=$SNS_TOPIC}" \
        --region "$REGION"
else
    echo "🆕 Creating new Lambda function..."
    
    aws lambda create-function \
        --function-name blockchaincore-api \
        --runtime python3.9 \
        --role "$ROLE_ARN" \
        --handler api-handler.lambda_handler \
        --zip-file fileb://"$TEMP_DIR/api-handler.zip" \
        --timeout 30 \
        --memory-size 256 \
        --environment "Variables={DYNAMODB_TABLE_NAME=$DYNAMODB_TABLE,S3_BUCKET_NAME=$S3_BUCKET,SNS_TOPIC_ARN=$SNS_TOPIC}" \
        --region "$REGION"
fi

# Clean up
rm -rf "$TEMP_DIR"

echo "✅ API Lambda deployed successfully!"
echo ""
echo "🔗 Next steps:"
echo "1. Create API Gateway to expose this Lambda"
echo "2. Update frontend environment variables with API Gateway URL"
echo "3. Test the API endpoints"
echo ""
echo "📋 API Endpoints:"
echo "  GET /crypto/latest-ohlcv     - Latest OHLCV data"
echo "  GET /crypto/historical/{symbol} - Historical data"
echo "  GET /anomalies/recent        - Recent anomalies"
echo "  GET /system/metrics          - System metrics"
