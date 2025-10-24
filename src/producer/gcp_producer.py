"""
GCP Producer for BlockchainCore Multi-Cloud Architecture
This producer sends data to Google Cloud Pub/Sub instead of AWS SQS
"""

import asyncio
import json
import logging
import os
import websockets
from datetime import datetime, timezone
from typing import Dict, Any

from google.cloud import pubsub_v1
from google.cloud import storage

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

class GCPProducer:
    """GCP Producer for sending trade data to Cloud Pub/Sub"""
    
    def __init__(self):
        """Initialize GCP Producer"""
        self.pubsub_topic = os.environ.get('PUBSUB_TOPIC')
        self.storage_bucket = os.environ.get('STORAGE_BUCKET')
        self.symbol = os.environ.get('TRADING_SYMBOL', 'BTCUSDT')
        
        if not self.pubsub_topic:
            raise ValueError("PUBSUB_TOPIC environment variable is required")
        
        # Initialize GCP clients
        self.publisher = pubsub_v1.PublisherClient()
        self.storage_client = storage.Client()
        
        # WebSocket configuration
        self.websocket_url = f"wss://stream.binance.com:9443/ws/{self.symbol.lower()}@trade"
        
        logger.info(f"GCP Producer initialized")
        logger.info(f"Pub/Sub Topic: {self.pubsub_topic}")
        logger.info(f"Storage Bucket: {self.storage_bucket}")
        logger.info(f"Trading Symbol: {self.symbol}")
        logger.info(f"WebSocket URL: {self.websocket_url}")
    
    async def start(self):
        """Start the GCP producer"""
        logger.info("Starting GCP Producer")
        
        try:
            async with websockets.connect(self.websocket_url) as websocket:
                logger.info("✅ Connected to Binance WebSocket!")
                
                message_count = 0
                async for message in websocket:
                    try:
                        # Parse trade data
                        trade_data = json.loads(message)
                        
                        # Process and send to Pub/Sub
                        await self.process_and_send(trade_data)
                        
                        message_count += 1
                        if message_count % 10 == 0:
                            logger.info(f"Processed {message_count} messages")
                            
                    except json.JSONDecodeError as e:
                        logger.error(f"JSON decode error: {e}")
                    except Exception as e:
                        logger.error(f"Error processing message: {e}")
                        
        except websockets.exceptions.ConnectionClosed:
            logger.error("WebSocket connection closed")
        except Exception as e:
            logger.error(f"WebSocket error: {e}")
    
    async def process_and_send(self, trade_data: Dict[str, Any]):
        """Process trade data and send to Pub/Sub"""
        try:
            # Add processing timestamp
            trade_data['processed_at'] = datetime.now(timezone.utc).isoformat()
            trade_data['source'] = 'gcp_producer'
            
            # Convert to JSON string
            message_data = json.dumps(trade_data)
            
            # Publish to Pub/Sub
            future = self.publisher.publish(
                self.pubsub_topic,
                message_data.encode('utf-8'),
                symbol=trade_data.get('s', 'unknown'),
                timestamp=str(trade_data.get('T', 0))
            )
            
            # Wait for publish to complete
            message_id = future.result()
            logger.debug(f"Published message {message_id} for {trade_data.get('s', 'unknown')}")
            
        except Exception as e:
            logger.error(f"Error processing and sending trade data: {e}")
            raise e
    
    def store_raw_data(self, trade_data: Dict[str, Any]):
        """Store raw trade data in Cloud Storage"""
        try:
            if not self.storage_bucket:
                logger.warning("No storage bucket configured, skipping raw data storage")
                return
            
            # Create filename with timestamp
            timestamp = datetime.now(timezone.utc)
            filename = f"raw-data/{timestamp.strftime('%Y/%m/%d/%H/%M')}/{trade_data.get('s', 'unknown')}_{int(timestamp.timestamp())}.json"
            
            # Get bucket and create blob
            bucket = self.storage_client.bucket(self.storage_bucket)
            blob = bucket.blob(filename)
            
            # Upload data
            blob.upload_from_string(json.dumps(trade_data))
            logger.debug(f"Stored raw data: {filename}")
            
        except Exception as e:
            logger.error(f"Error storing raw data: {e}")
            # Don't raise here as this is not critical

async def main():
    """Main function to run the GCP producer"""
    try:
        producer = GCPProducer()
        await producer.start()
    except KeyboardInterrupt:
        logger.info("GCP Producer stopped by user")
    except Exception as e:
        logger.error(f"GCP Producer error: {e}")
        raise e

if __name__ == "__main__":
    asyncio.run(main())
