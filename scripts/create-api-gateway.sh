#!/bin/bash

# Create API Gateway for BlockchainCore frontend
set -e

echo "🌐 Creating API Gateway for BlockchainCore..."

# Get AWS region
REGION=$(aws configure get region)
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

echo "📍 Region: $REGION"
echo "🏢 Account: $ACCOUNT_ID"

# Create API Gateway
echo "📡 Creating REST API..."
API_ID=$(aws apigateway create-rest-api \
    --name "BlockchainCore API" \
    --description "API for BlockchainCore frontend" \
    --region "$REGION" \
    --query 'id' --output text)

echo "✅ API Gateway created with ID: $API_ID"

# Get root resource ID
ROOT_ID=$(aws apigateway get-resources \
    --rest-api-id "$API_ID" \
    --region "$REGION" \
    --query 'items[?path==`/`].id' --output text)

echo "📋 Root resource ID: $ROOT_ID"

# Create resources and methods
echo "🔧 Setting up API endpoints..."

# Create /crypto resource
CRYPTO_ID=$(aws apigateway create-resource \
    --rest-api-id "$API_ID" \
    --parent-id "$ROOT_ID" \
    --path-part "crypto" \
    --region "$REGION" \
    --query 'id' --output text)

# Create /crypto/latest-ohlcv resource
LATEST_OHLCV_ID=$(aws apigateway create-resource \
    --rest-api-id "$API_ID" \
    --parent-id "$CRYPTO_ID" \
    --path-part "latest-ohlcv" \
    --region "$REGION" \
    --query 'id' --output text)

# Create /crypto/historical resource
HISTORICAL_ID=$(aws apigateway create-resource \
    --rest-api-id "$API_ID" \
    --parent-id "$CRYPTO_ID" \
    --path-part "historical" \
    --region "$REGION" \
    --query 'id' --output text)

# Create /crypto/historical/{symbol} resource
SYMBOL_ID=$(aws apigateway create-resource \
    --rest-api-id "$API_ID" \
    --parent-id "$HISTORICAL_ID" \
    --path-part "{symbol}" \
    --region "$REGION" \
    --query 'id' --output text)

# Create /anomalies resource
ANOMALIES_ID=$(aws apigateway create-resource \
    --rest-api-id "$API_ID" \
    --parent-id "$ROOT_ID" \
    --path-part "anomalies" \
    --region "$REGION" \
    --query 'id' --output text)

# Create /anomalies/recent resource
RECENT_ANOMALIES_ID=$(aws apigateway create-resource \
    --rest-api-id "$API_ID" \
    --parent-id "$ANOMALIES_ID" \
    --path-part "recent" \
    --region "$REGION" \
    --query 'id' --output text)

# Create /system resource
SYSTEM_ID=$(aws apigateway create-resource \
    --rest-api-id "$API_ID" \
    --parent-id "$ROOT_ID" \
    --path-part "system" \
    --region "$REGION" \
    --query 'id' --output text)

# Create /system/metrics resource
METRICS_ID=$(aws apigateway create-resource \
    --rest-api-id "$API_ID" \
    --parent-id "$SYSTEM_ID" \
    --path-part "metrics" \
    --region "$REGION" \
    --query 'id' --output text)

echo "📁 Resources created successfully"

# Create Lambda integration
echo "🔗 Creating Lambda integration..."

# Create integration for latest-ohlcv
aws apigateway put-method \
    --rest-api-id "$API_ID" \
    --resource-id "$LATEST_OHLCV_ID" \
    --http-method GET \
    --authorization-type NONE \
    --region "$REGION"

aws apigateway put-integration \
    --rest-api-id "$API_ID" \
    --resource-id "$LATEST_OHLCV_ID" \
    --http-method GET \
    --type AWS_PROXY \
    --integration-http-method POST \
    --uri "arn:aws:apigateway:$REGION:lambda:path/2015-03-31/functions/arn:aws:lambda:$REGION:$ACCOUNT_ID:function:blockchaincore-api/invocations" \
    --region "$REGION"

# Create integration for historical/{symbol}
aws apigateway put-method \
    --rest-api-id "$API_ID" \
    --resource-id "$SYMBOL_ID" \
    --http-method GET \
    --authorization-type NONE \
    --region "$REGION"

aws apigateway put-integration \
    --rest-api-id "$API_ID" \
    --resource-id "$SYMBOL_ID" \
    --http-method GET \
    --type AWS_PROXY \
    --integration-http-method POST \
    --uri "arn:aws:apigateway:$REGION:lambda:path/2015-03-31/functions/arn:aws:lambda:$REGION:$ACCOUNT_ID:function:blockchaincore-api/invocations" \
    --region "$REGION"

# Create integration for anomalies/recent
aws apigateway put-method \
    --rest-api-id "$API_ID" \
    --resource-id "$RECENT_ANOMALIES_ID" \
    --http-method GET \
    --authorization-type NONE \
    --region "$REGION"

aws apigateway put-integration \
    --rest-api-id "$API_ID" \
    --resource-id "$RECENT_ANOMALIES_ID" \
    --http-method GET \
    --type AWS_PROXY \
    --integration-http-method POST \
    --uri "arn:aws:apigateway:$REGION:lambda:path/2015-03-31/functions/arn:aws:lambda:$REGION:$ACCOUNT_ID:function:blockchaincore-api/invocations" \
    --region "$REGION"

# Create integration for system/metrics
aws apigateway put-method \
    --rest-api-id "$API_ID" \
    --resource-id "$METRICS_ID" \
    --http-method GET \
    --authorization-type NONE \
    --region "$REGION"

aws apigateway put-integration \
    --rest-api-id "$API_ID" \
    --resource-id "$METRICS_ID" \
    --http-method GET \
    --type AWS_PROXY \
    --integration-http-method POST \
    --uri "arn:aws:apigateway:$REGION:lambda:path/2015-03-31/functions/arn:aws:lambda:$REGION:$ACCOUNT_ID:function:blockchaincore-api/invocations" \
    --region "$REGION"

echo "🔗 Lambda integrations created"

# Add Lambda permission for API Gateway
echo "🔐 Adding Lambda permissions..."
aws lambda add-permission \
    --function-name blockchaincore-api \
    --statement-id apigateway-access \
    --action lambda:InvokeFunction \
    --principal apigateway.amazonaws.com \
    --source-arn "arn:aws:execute-api:$REGION:$ACCOUNT_ID:$API_ID/*/*/*" \
    --region "$REGION" 2>/dev/null || echo "Permission already exists"

# Deploy the API
echo "🚀 Deploying API..."
aws apigateway create-deployment \
    --rest-api-id "$API_ID" \
    --stage-name prod \
    --region "$REGION"

echo "✅ API Gateway deployed successfully!"
echo ""
echo "🌐 API Gateway URL: https://$API_ID.execute-api.$REGION.amazonaws.com/prod"
echo ""
echo "📋 Available Endpoints:"
echo "  GET https://$API_ID.execute-api.$REGION.amazonaws.com/prod/crypto/latest-ohlcv"
echo "  GET https://$API_ID.execute-api.$REGION.amazonaws.com/prod/crypto/historical/{symbol}"
echo "  GET https://$API_ID.execute-api.$REGION.amazonaws.com/prod/anomalies/recent"
echo "  GET https://$API_ID.execute-api.$REGION.amazonaws.com/prod/system/metrics"
echo ""
echo "🔗 Next step: Update frontend environment variables with the API Gateway URL"
