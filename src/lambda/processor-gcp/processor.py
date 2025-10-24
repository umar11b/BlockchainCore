"""
GCP Cloud Function for processing trade data from Pub/Sub
This replaces the AWS Lambda processor for the GCP side of the multi-cloud architecture
"""

import json
import base64
import logging
from datetime import datetime, timezone
from decimal import Decimal
from typing import Dict, Any

from google.cloud import firestore
from google.cloud import storage
from google.cloud import pubsub_v1

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Initialize clients
db = firestore.Client()
storage_client = storage.Client()
pubsub_client = pubsub_v1.PublisherClient()

def process_trade_data(event: Dict[str, Any], context) -> str:
    """
    Cloud Function entry point for processing trade data from Pub/Sub
    
    Args:
        event: Pub/Sub event data
        context: Cloud Function context
        
    Returns:
        str: Processing result
    """
    try:
        # Extract message from Pub/Sub event
        if 'data' in event:
            message_data = base64.b64decode(event['data']).decode('utf-8')
            trade_data = json.loads(message_data)
        else:
            logger.error("No data found in Pub/Sub event")
            return "Error: No data found"
        
        logger.info(f"Processing trade data: {trade_data.get('symbol', 'unknown')}")
        
        # Process the trade data
        processed_data = process_trade_message(trade_data)
        
        # Store in Firestore
        store_in_firestore(processed_data)
        
        # Store raw data in Cloud Storage
        store_raw_data(trade_data)
        
        logger.info(f"Successfully processed trade for {processed_data.get('symbol', 'unknown')}")
        return f"Processed trade for {processed_data.get('symbol', 'unknown')}"
        
    except Exception as e:
        logger.error(f"Error processing trade data: {str(e)}")
        raise e

def process_trade_message(trade_data: Dict[str, Any]) -> Dict[str, Any]:
    """
    Process individual trade message and calculate OHLCV data
    
    Args:
        trade_data: Raw trade data from Binance
        
    Returns:
        Dict: Processed OHLCV data
    """
    try:
        # Extract trade information
        symbol = trade_data.get('s', 'UNKNOWN')
        price = Decimal(str(trade_data.get('p', '0')))
        quantity = Decimal(str(trade_data.get('q', '0')))
        timestamp = int(trade_data.get('T', 0))
        
        # Convert timestamp to datetime
        trade_time = datetime.fromtimestamp(timestamp / 1000, tz=timezone.utc)
        
        # Create minute-level key for OHLCV aggregation
        minute_key = trade_time.strftime('%Y-%m-%d-%H-%M')
        
        # Calculate volume
        volume = price * quantity
        
        processed_data = {
            'symbol': symbol,
            'price': float(price),
            'quantity': float(quantity),
            'volume': float(volume),
            'timestamp': timestamp,
            'trade_time': trade_time.isoformat(),
            'minute_key': minute_key,
            'processed_at': datetime.now(timezone.utc).isoformat(),
            'source': 'gcp_pubsub'
        }
        
        return processed_data
        
    except Exception as e:
        logger.error(f"Error processing trade message: {str(e)}")
        raise e

def store_in_firestore(data: Dict[str, Any]) -> None:
    """
    Store processed data in Firestore
    
    Args:
        data: Processed trade data
    """
    try:
        # Create document reference
        doc_ref = db.collection('ohlcv_data').document(f"{data['symbol']}_{data['minute_key']}")
        
        # Get existing document
        doc = doc_ref.get()
        
        if doc.exists:
            # Update existing OHLCV data
            existing_data = doc.to_dict()
            update_ohlcv_data(doc_ref, existing_data, data)
        else:
            # Create new OHLCV data
            create_ohlcv_data(doc_ref, data)
            
    except Exception as e:
        logger.error(f"Error storing in Firestore: {str(e)}")
        raise e

def update_ohlcv_data(doc_ref, existing_data: Dict[str, Any], new_data: Dict[str, Any]) -> None:
    """
    Update existing OHLCV data with new trade
    
    Args:
        doc_ref: Firestore document reference
        existing_data: Existing OHLCV data
        new_data: New trade data
    """
    try:
        # Update OHLCV values
        existing_data['high'] = max(existing_data.get('high', 0), new_data['price'])
        existing_data['low'] = min(existing_data.get('low', float('inf')), new_data['price'])
        existing_data['close'] = new_data['price']
        existing_data['volume'] += new_data['volume']
        existing_data['trade_count'] = existing_data.get('trade_count', 0) + 1
        existing_data['last_updated'] = new_data['processed_at']
        
        # Update document
        doc_ref.set(existing_data, merge=True)
        
    except Exception as e:
        logger.error(f"Error updating OHLCV data: {str(e)}")
        raise e

def create_ohlcv_data(doc_ref, data: Dict[str, Any]) -> None:
    """
    Create new OHLCV data document
    
    Args:
        doc_ref: Firestore document reference
        data: Trade data
    """
    try:
        ohlcv_data = {
            'symbol': data['symbol'],
            'minute_key': data['minute_key'],
            'open': data['price'],
            'high': data['price'],
            'low': data['price'],
            'close': data['price'],
            'volume': data['volume'],
            'trade_count': 1,
            'first_trade': data['processed_at'],
            'last_updated': data['processed_at'],
            'source': 'gcp_pubsub'
        }
        
        doc_ref.set(ohlcv_data)
        
    except Exception as e:
        logger.error(f"Error creating OHLCV data: {str(e)}")
        raise e

def store_raw_data(trade_data: Dict[str, Any]) -> None:
    """
    Store raw trade data in Cloud Storage
    
    Args:
        trade_data: Raw trade data
    """
    try:
        # Get bucket name from environment or use default
        bucket_name = os.environ.get('STORAGE_BUCKET', 'blockchain-core-raw-data')
        bucket = storage_client.bucket(bucket_name)
        
        # Create filename with timestamp
        timestamp = datetime.now(timezone.utc).strftime('%Y/%m/%d/%H/%M')
        filename = f"raw-data/{timestamp}/{trade_data.get('s', 'unknown')}_{int(datetime.now().timestamp())}.json"
        
        # Create blob and upload
        blob = bucket.blob(filename)
        blob.upload_from_string(json.dumps(trade_data))
        
    except Exception as e:
        logger.error(f"Error storing raw data: {str(e)}")
        # Don't raise here as this is not critical
        pass

def detect_anomalies(data: Dict[str, Any]) -> Dict[str, Any]:
    """
    Detect anomalies in trade data (placeholder for ML-based detection)
    
    Args:
        data: Processed trade data
        
    Returns:
        Dict: Anomaly detection results
    """
    try:
        anomalies = []
        
        # Simple price anomaly detection (placeholder)
        price = data['price']
        if price > 100000:  # Example threshold
            anomalies.append({
                'type': 'high_price',
                'value': price,
                'threshold': 100000,
                'severity': 'high'
            })
        
        # Simple volume anomaly detection (placeholder)
        volume = data['volume']
        if volume > 1000000:  # Example threshold
            anomalies.append({
                'type': 'high_volume',
                'value': volume,
                'threshold': 1000000,
                'severity': 'medium'
            })
        
        if anomalies:
            logger.warning(f"Anomalies detected: {anomalies}")
            return {
                'anomalies': anomalies,
                'timestamp': data['processed_at'],
                'symbol': data['symbol']
            }
        
        return {'anomalies': [], 'timestamp': data['processed_at']}
        
    except Exception as e:
        logger.error(f"Error detecting anomalies: {str(e)}")
        return {'anomalies': [], 'error': str(e)}
