"""
BlockchainCore Data Processor Lambda
Processes trade data from SQS and stores in S3 and DynamoDB
"""

import json
import logging
import os
from datetime import datetime, timedelta
from typing import Dict, List, Any
from collections import defaultdict
from decimal import Decimal

import boto3
from botocore.exceptions import ClientError

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Initialize AWS clients
s3_client = boto3.client('s3')
dynamodb = boto3.resource('dynamodb')

# Environment variables
S3_BUCKET = os.environ['S3_BUCKET_NAME']
DYNAMODB_TABLE = os.environ['DYNAMODB_TABLE_NAME']
SNS_TOPIC_ARN = os.environ['SNS_TOPIC_ARN']

# Initialize DynamoDB table
table = dynamodb.Table(DYNAMODB_TABLE)

class OHLCVCalculator:
    """Calculate OHLCV (Open, High, Low, Close, Volume) data"""
    
    def __init__(self, symbol: str, interval_minutes: int = 1):
        self.symbol = symbol
        self.interval_minutes = interval_minutes
        self.current_interval = None
        self.ohlcv_data = {
            'open': None,
            'high': None,
            'low': None,
            'close': None,
            'volume': 0.0,
            'trade_count': 0
        }
    
    def get_interval_key(self, timestamp_ms: int) -> str:
        """Get interval key for the given timestamp"""
        dt = datetime.fromtimestamp(timestamp_ms / 1000)
        # Round down to the nearest interval
        interval_start = dt.replace(
            second=0, 
            microsecond=0
        ).replace(
            minute=(dt.minute // self.interval_minutes) * self.interval_minutes
        )
        return interval_start.strftime('%Y-%m-%dT%H:%M:00Z')
    
    def process_trade(self, trade_data: Dict[str, Any]) -> Dict[str, Any]:
        """Process a single trade and return OHLCV data if interval is complete"""
        timestamp_ms = trade_data.get('E', int(datetime.now().timestamp() * 1000))
        price = float(trade_data.get('p', 0))
        quantity = float(trade_data.get('q', 0))
        
        interval_key = self.get_interval_key(timestamp_ms)
        
        # Check if we've moved to a new interval
        if self.current_interval and interval_key != self.current_interval:
            # Return completed OHLCV data
            result = self.get_ohlcv_data()
            # Reset for new interval
            self.reset_ohlcv()
            self.current_interval = interval_key
        
        # Initialize interval if needed
        if not self.current_interval:
            self.current_interval = interval_key
        
        # Update OHLCV data
        if self.ohlcv_data['open'] is None:
            self.ohlcv_data['open'] = price
        
        self.ohlcv_data['high'] = max(self.ohlcv_data['high'] or price, price)
        self.ohlcv_data['low'] = min(self.ohlcv_data['low'] or price, price)
        self.ohlcv_data['close'] = price
        self.ohlcv_data['volume'] += quantity
        self.ohlcv_data['trade_count'] += 1
        
        return None  # No complete interval yet
    
    def get_ohlcv_data(self) -> Dict[str, Any]:
        """Get current OHLCV data"""
        if self.ohlcv_data['open'] is None:
            return None
        
        return {
            'symbol': self.symbol,
            'timestamp': self.current_interval,
            'open': self.ohlcv_data['open'],
            'high': self.ohlcv_data['high'],
            'low': self.ohlcv_data['low'],
            'close': self.ohlcv_data['close'],
            'volume': self.ohlcv_data['volume'],
            'trade_count': self.ohlcv_data['trade_count']
        }
    
    def reset_ohlcv(self):
        """Reset OHLCV data for new interval"""
        self.ohlcv_data = {
            'open': None,
            'high': None,
            'low': None,
            'close': None,
            'volume': 0.0,
            'trade_count': 0
        }

def store_raw_data_in_s3(trade_data: Dict[str, Any], timestamp: datetime):
    """Store raw trade data in S3 with partitioning"""
    try:
        # Create S3 key with partitioning (year/month/day/hour)
        year = timestamp.strftime('%Y')
        month = timestamp.strftime('%m')
        day = timestamp.strftime('%d')
        hour = timestamp.strftime('%H')
        minute = timestamp.strftime('%M')
        
        s3_key = f"raw-data/{year}/{month}/{day}/{hour}/trades_{year}{month}{day}_{hour}{minute}.json"
        
        # Convert trade data to JSON
        data_json = json.dumps(trade_data)
        
        # Upload to S3
        s3_client.put_object(
            Bucket=S3_BUCKET,
            Key=s3_key,
            Body=data_json,
            ContentType='application/json'
        )
        
        logger.debug(f"Stored raw data in S3: {s3_key}")
        
    except ClientError as e:
        logger.error(f"Error storing data in S3: {e}")
        raise

def store_ohlcv_in_dynamodb(ohlcv_data: Dict[str, Any]):
    """Store OHLCV data in DynamoDB"""
    try:
        # Prepare item for DynamoDB
        item = {
            'symbol': ohlcv_data['symbol'],
            'timestamp': ohlcv_data['timestamp'],
            'open': Decimal(str(ohlcv_data['open'])),
            'high': Decimal(str(ohlcv_data['high'])),
            'low': Decimal(str(ohlcv_data['low'])),
            'close': Decimal(str(ohlcv_data['close'])),
            'volume': Decimal(str(ohlcv_data['volume'])),
            'trade_count': Decimal(str(ohlcv_data['trade_count'])),
            'created_at': datetime.utcnow().isoformat()
        }
        
        # Store in DynamoDB
        table.put_item(Item=item)
        
        logger.info(f"Stored OHLCV data for {ohlcv_data['symbol']} at {ohlcv_data['timestamp']}")
        
    except ClientError as e:
        logger.error(f"Error storing OHLCV data in DynamoDB: {e}")
        raise

def lambda_handler(event, context):
    """Lambda handler for processing SQS messages"""
    logger.info(f"Processing {len(event['Records'])} messages")
    
    # Initialize OHLCV calculators for each symbol
    ohlcv_calculators = {}
    
    try:
        for record in event['Records']:
            # Parse SQS message
            sqs_data = record['body']
            trade_data = json.loads(sqs_data)
            
            # Extract symbol
            symbol = trade_data.get('s', 'UNKNOWN')
            
            # Initialize calculator for symbol if not exists
            if symbol not in ohlcv_calculators:
                ohlcv_calculators[symbol] = OHLCVCalculator(symbol)
            
            # Store raw data in S3
            timestamp = datetime.fromtimestamp(trade_data.get('E', 0) / 1000)
            store_raw_data_in_s3(trade_data, timestamp)
            
            # Process trade for OHLCV calculation
            ohlcv_data = ohlcv_calculators[symbol].process_trade(trade_data)
            
            # Store OHLCV data if interval is complete
            if ohlcv_data:
                store_ohlcv_in_dynamodb(ohlcv_data)
        
        # Process any remaining incomplete intervals
        for symbol, calculator in ohlcv_calculators.items():
            ohlcv_data = calculator.get_ohlcv_data()
            if ohlcv_data:
                store_ohlcv_in_dynamodb(ohlcv_data)
        
        logger.info("Successfully processed all records")
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': f'Processed {len(event["Records"])} records',
                'symbols_processed': list(ohlcv_calculators.keys())
            })
        }
        
    except Exception as e:
        logger.error(f"Error processing records: {e}")
        raise
