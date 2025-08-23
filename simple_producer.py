#!/usr/bin/env python3
"""
Simple working producer to test the pipeline
"""

import asyncio
import json
import logging
import os
from datetime import datetime

import boto3
import websockets
from botocore.exceptions import ClientError

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class SimpleProducer:
    def __init__(self):
        self.sqs_client = boto3.client('sqs')
        self.queue_url = os.getenv('SQS_QUEUE_URL', '')
        self.symbol = 'BTCUSDT'
        self.running = False
        
        logger.info(f"SQS Queue URL: {self.queue_url}")
        logger.info(f"Trading Symbol: {self.symbol}")
        
        if not self.queue_url:
            logger.error("SQS_QUEUE_URL environment variable is not set!")
            raise ValueError("SQS_QUEUE_URL environment variable is required")
    
    async def run(self):
        """Main run loop"""
        logger.info("Starting Simple Producer")
        
        uri = f"wss://stream.binance.com:9443/ws/{self.symbol.lower()}@trade"
        logger.info(f"Connecting to: {uri}")
        
        try:
            websocket = await websockets.connect(uri)
            logger.info("✅ Connected to Binance WebSocket!")
            self.running = True
            
            message_count = 0
            async for message in websocket:
                if not self.running:
                    break
                
                try:
                    # Parse the trade data
                    trade_data = json.loads(message)
                    
                    # Add timestamp if not present
                    if 'E' not in trade_data:
                        trade_data['E'] = int(datetime.now().timestamp() * 1000)
                    
                    # Add processing timestamp
                    trade_data['processed_at'] = datetime.utcnow().isoformat()
                    
                    # Send to SQS
                    self.send_to_sqs(trade_data)
                    
                    message_count += 1
                    if message_count % 10 == 0:
                        logger.info(f"Processed {message_count} messages")
                    
                except json.JSONDecodeError as e:
                    logger.error(f"Failed to parse JSON message: {e}")
                except Exception as e:
                    logger.error(f"Error processing message: {e}")
                    
        except Exception as e:
            logger.error(f"WebSocket error: {e}")
        finally:
            if 'websocket' in locals():
                await websocket.close()
    
    def send_to_sqs(self, data):
        """Send data to AWS SQS queue"""
        try:
            data_json = json.dumps(data)
            response = self.sqs_client.send_message(
                QueueUrl=self.queue_url,
                MessageBody=data_json
            )
            logger.debug(f"Sent to SQS: {response['MessageId']}")
        except Exception as e:
            logger.error(f"SQS error: {e}")
    
    def stop(self):
        """Stop the producer"""
        logger.info("Stopping producer...")
        self.running = False

async def main():
    """Main entry point"""
    producer = SimpleProducer()
    
    try:
        await producer.run()
    except KeyboardInterrupt:
        logger.info("Received interrupt signal")
        producer.stop()
    except Exception as e:
        logger.error(f"Unexpected error: {e}")
        import traceback
        traceback.print_exc()

if __name__ == "__main__":
    asyncio.run(main())
