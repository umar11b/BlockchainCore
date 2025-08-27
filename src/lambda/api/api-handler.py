import json
import boto3
import os
from datetime import datetime, timedelta
from typing import Dict, List, Any
import logging
from decimal import Decimal

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Initialize AWS clients
dynamodb = boto3.resource('dynamodb')
s3 = boto3.client('s3')
cloudwatch = boto3.client('cloudwatch')

# Get environment variables
DYNAMODB_TABLE_NAME = os.environ.get('DYNAMODB_TABLE_NAME')
S3_BUCKET_NAME = os.environ.get('S3_BUCKET_NAME')
SNS_TOPIC_ARN = os.environ.get('SNS_TOPIC_ARN')

def lambda_handler(event, context):
    """API Gateway Lambda handler for BlockchainCore frontend API"""
    
    try:
        # Parse the request
        http_method = event.get('httpMethod', 'GET')
        path = event.get('path', '')
        query_params = event.get('queryStringParameters', {}) or {}
        
        # Set CORS headers
        headers = {
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Headers': 'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token',
            'Access-Control-Allow-Methods': 'GET,POST,OPTIONS',
            'Content-Type': 'application/json'
        }
        
        # Handle OPTIONS request (CORS preflight)
        if http_method == 'OPTIONS':
            return {
                'statusCode': 200,
                'headers': headers,
                'body': ''
            }
        
        # Route the request
        if path == '/crypto/latest-ohlcv':
            return get_latest_ohlcv_data(headers)
        elif path.startswith('/crypto/historical/'):
            symbol = path.split('/')[-1]
            return get_historical_data(symbol, query_params, headers)
        elif path == '/anomalies/recent':
            return get_recent_anomalies(headers)
        elif path == '/system/metrics':
            return get_system_metrics(headers)
        else:
            return {
                'statusCode': 404,
                'headers': headers,
                'body': json.dumps({'error': 'Endpoint not found'})
            }
            
    except Exception as e:
        logger.error(f"Error in API handler: {str(e)}")
        return {
            'statusCode': 500,
            'headers': headers,
            'body': json.dumps({'error': 'Internal server error'})
        }

def get_latest_ohlcv_data(headers: Dict[str, str]) -> Dict[str, Any]:
    """Get latest OHLCV data from DynamoDB"""
    try:
        table = dynamodb.Table(DYNAMODB_TABLE_NAME)
        
        # Scan for the latest data (in production, you'd use a more efficient query)
        response = table.scan(
            Limit=100
        )
        
        # Group by symbol and get latest for each
        latest_data = {}
        for item in response.get('Items', []):
            symbol = item.get('symbol')
            timestamp = item.get('timestamp')
            
            if symbol and timestamp:
                if symbol not in latest_data or timestamp > latest_data[symbol]['timestamp']:
                    latest_data[symbol] = item
        
        # Convert Decimal objects to float for JSON serialization
        serializable_data = []
        for item in latest_data.values():
            serializable_item = {}
            for key, value in item.items():
                if isinstance(value, Decimal):
                    serializable_item[key] = float(value)
                else:
                    serializable_item[key] = value
            serializable_data.append(serializable_item)
        
        return {
            'statusCode': 200,
            'headers': headers,
            'body': json.dumps(serializable_data)
        }
        
    except Exception as e:
        logger.error(f"Error fetching OHLCV data: {str(e)}")
        return {
            'statusCode': 500,
            'headers': headers,
            'body': json.dumps({'error': 'Failed to fetch OHLCV data'})
        }

def get_historical_data(symbol: str, query_params: Dict[str, str], headers: Dict[str, str]) -> Dict[str, Any]:
    """Get historical data from S3"""
    try:
        timeframe = query_params.get('timeframe', '1h')
        limit = int(query_params.get('limit', '24'))
        
        # In a real implementation, you'd query S3 for historical data
        # For now, return mock data
        mock_data = []
        now = datetime.utcnow()
        
        for i in range(limit):
            timestamp = now - timedelta(hours=i)
            mock_data.append({
                'symbol': symbol,
                'timestamp': timestamp.isoformat(),
                'open': 100 + i * 0.1,
                'high': 101 + i * 0.1,
                'low': 99 + i * 0.1,
                'close': 100.5 + i * 0.1,
                'volume': 1000000 + i * 10000
            })
        
        return {
            'statusCode': 200,
            'headers': headers,
            'body': json.dumps(mock_data)
        }
        
    except Exception as e:
        logger.error(f"Error fetching historical data: {str(e)}")
        return {
            'statusCode': 500,
            'headers': headers,
            'body': json.dumps({'error': 'Failed to fetch historical data'})
        }

def get_recent_anomalies(headers: Dict[str, str]) -> Dict[str, Any]:
    """Get recent anomalies from SNS or stored data"""
    try:
        # In a real implementation, you'd query a database or SNS for recent anomalies
        # For now, return mock data
        mock_anomalies = [
            {
                'id': '1',
                'type': 'price_spike',
                'symbol': 'BTCUSDT',
                'message': 'Price increased by 8.5% in the last 5 minutes',
                'severity': 'high',
                'timestamp': datetime.utcnow().isoformat(),
                'price_change': 8.5
            },
            {
                'id': '2',
                'type': 'volume_spike',
                'symbol': 'ETHUSDT',
                'message': 'Volume spike detected: 3.2x above average',
                'severity': 'medium',
                'timestamp': (datetime.utcnow() - timedelta(minutes=15)).isoformat(),
                'volume_change': 320
            }
        ]
        
        return {
            'statusCode': 200,
            'headers': headers,
            'body': json.dumps(mock_anomalies)
        }
        
    except Exception as e:
        logger.error(f"Error fetching anomalies: {str(e)}")
        return {
            'statusCode': 500,
            'headers': headers,
            'body': json.dumps({'error': 'Failed to fetch anomalies'})
        }

def get_system_metrics(headers: Dict[str, str]) -> Dict[str, Any]:
    """Get system metrics from CloudWatch"""
    try:
        # Get CloudWatch metrics
        end_time = datetime.utcnow()
        start_time = end_time - timedelta(hours=1)
        
        # SQS Queue Depth
        sqs_metrics = cloudwatch.get_metric_statistics(
            Namespace='AWS/SQS',
            MetricName='ApproximateNumberOfVisibleMessages',
            Dimensions=[{'Name': 'QueueName', 'Value': 'trade-data-queue'}],
            StartTime=start_time,
            EndTime=end_time,
            Period=300,
            Statistics=['Average']
        )
        
        # Lambda Executions
        lambda_metrics = cloudwatch.get_metric_statistics(
            Namespace='AWS/Lambda',
            MetricName='Invocations',
            Dimensions=[{'Name': 'FunctionName', 'Value': 'processor'}],
            StartTime=start_time,
            EndTime=end_time,
            Period=300,
            Statistics=['Sum']
        )
        
        metrics = {
            'sqsQueueDepth': sqs_metrics.get('Datapoints', [{}])[0].get('Average', 0),
            'lambdaExecutions': lambda_metrics.get('Datapoints', [{}])[0].get('Sum', 0),
            'dynamoDbReads': 0,  # Would need to get from DynamoDB metrics
            's3StorageUsed': 0,  # Would need to get from S3 metrics
            'lastUpdated': end_time.isoformat()
        }
        
        return {
            'statusCode': 200,
            'headers': headers,
            'body': json.dumps(metrics)
        }
        
    except Exception as e:
        logger.error(f"Error fetching system metrics: {str(e)}")
        return {
            'statusCode': 500,
            'headers': headers,
            'body': json.dumps({'error': 'Failed to fetch system metrics'})
        }
