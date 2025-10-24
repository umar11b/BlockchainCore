#!/bin/bash

# Populate DynamoDB with sample cryptocurrency data
set -e

echo "📊 Populating DynamoDB with sample data..."

# Get AWS region and DynamoDB table name
REGION=$(aws configure get region)
cd terraform-aws
TABLE_NAME=$(terraform output -raw dynamodb_table_name)
cd ..

echo "📍 Region: $REGION"
echo "📋 Table: $TABLE_NAME"

# Sample cryptocurrency data
echo "🪙 Adding sample cryptocurrency data..."

# BTCUSDT data
aws dynamodb put-item \
    --table-name "$TABLE_NAME" \
    --item '{
        "symbol": {"S": "BTCUSDT"},
        "timestamp": {"S": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'"},
        "open": {"N": "43250.67"},
        "high": {"N": "43300.00"},
        "low": {"N": "43200.00"},
        "close": {"N": "43275.50"},
        "volume": {"N": "28450000000"}
    }' \
    --region "$REGION"

# ETHUSDT data
aws dynamodb put-item \
    --table-name "$TABLE_NAME" \
    --item '{
        "symbol": {"S": "ETHUSDT"},
        "timestamp": {"S": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'"},
        "open": {"N": "2650.89"},
        "high": {"N": "2660.00"},
        "low": {"N": "2645.00"},
        "close": {"N": "2655.25"},
        "volume": {"N": "15600000000"}
    }' \
    --region "$REGION"

# ADAUSDT data
aws dynamodb put-item \
    --table-name "$TABLE_NAME" \
    --item '{
        "symbol": {"S": "ADAUSDT"},
        "timestamp": {"S": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'"},
        "open": {"N": "0.4856"},
        "high": {"N": "0.4900"},
        "low": {"N": "0.4800"},
        "close": {"N": "0.4875"},
        "volume": {"N": "890000000"}
    }' \
    --region "$REGION"

# DOTUSDT data
aws dynamodb put-item \
    --table-name "$TABLE_NAME" \
    --item '{
        "symbol": {"S": "DOTUSDT"},
        "timestamp": {"S": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'"},
        "open": {"N": "7.23"},
        "high": {"N": "7.30"},
        "low": {"N": "7.20"},
        "close": {"N": "7.28"},
        "volume": {"N": "450000000"}
    }' \
    --region "$REGION"

echo "✅ Sample data added successfully!"
echo ""
echo "📊 Added data for:"
echo "  - BTCUSDT (Bitcoin)"
echo "  - ETHUSDT (Ethereum)"
echo "  - ADAUSDT (Cardano)"
echo "  - DOTUSDT (Polkadot)"
echo ""
echo "🔗 You can now test the API endpoints:"
echo "  curl https://y3kto6ii0e.execute-api.us-east-1.amazonaws.com/prod/crypto/latest-ohlcv"
