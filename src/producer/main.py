#!/usr/bin/env python3
"""
BlockchainCore Data Producer
Connects to Binance WebSocket API and streams trade data to AWS SQS
"""

import asyncio
import json
import logging
import os
import sys
import threading
from datetime import datetime
from typing import Any, Dict

import boto3
import websockets
from botocore.exceptions import ClientError

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
)
logger = logging.getLogger(__name__)


class BinanceWebSocketProducer:
    """Producer for streaming Binance trade data to AWS SQS"""

    def __init__(self):
        self.sqs_client = boto3.client("sqs")
        self.queue_url = os.getenv("SQS_QUEUE_URL", "")
        self.websocket_url = os.getenv(
            "BINANCE_WEBSOCKET_URL",
            "wss://stream.binance.com:9443/ws/btcusdt@trade",
        )
        self.symbol = os.getenv("TRADING_SYMBOL", "BTCUSDT")
        self.running = False

        # Debug logging
        logger.info(f"SQS Queue URL: {self.queue_url}")
        logger.info(f"WebSocket URL: {self.websocket_url}")
        logger.info(f"Trading Symbol: {self.symbol}")

        if not self.queue_url:
            logger.error("SQS_QUEUE_URL environment variable is not set!")
            raise ValueError("SQS_QUEUE_URL environment variable is required")

    async def connect_websocket(self):
        """Connect to Binance WebSocket"""
        try:
            logger.info(f"Connecting to WebSocket: {self.websocket_url}")
            
            # Add timeout to the connection
            async with websockets.connect(
                self.websocket_url, 
                ping_interval=20, 
                ping_timeout=10,
                close_timeout=10
            ) as websocket:
                logger.info("WebSocket connected successfully")
                
                # Set a timeout for receiving messages
                while self.running:
                    try:
                        # Wait for message with timeout
                        message = await asyncio.wait_for(
                            websocket.recv(), 
                            timeout=30.0  # 30 second timeout
                        )
                        await self.process_message(message)
                    except asyncio.TimeoutError:
                        logger.debug("No message received within timeout, continuing...")
                        continue
                    except websockets.exceptions.ConnectionClosed:
                        logger.warning("WebSocket connection closed")
                        break
                        
        except asyncio.TimeoutError:
            logger.error("WebSocket connection timeout")
            raise
        except websockets.exceptions.ConnectionClosed as e:
            logger.error(f"WebSocket connection closed: {e}")
            raise
        except websockets.exceptions.InvalidURI as e:
            logger.error(f"Invalid WebSocket URI: {e}")
            raise
        except Exception as e:
            logger.error(f"WebSocket connection error: {e}")
            raise

    async def process_message(self, message: str):
        """Process incoming WebSocket message"""
        try:
            # Parse the trade data
            trade_data = json.loads(message)

            # Add timestamp if not present
            if "E" not in trade_data:
                trade_data["E"] = int(datetime.now().timestamp() * 1000)

            # Add processing timestamp
            trade_data["processed_at"] = datetime.utcnow().isoformat()

            # Send to SQS
            self.send_to_sqs(trade_data)

        except json.JSONDecodeError as e:
            logger.error(f"Failed to parse JSON message: {e}")
        except Exception as e:
            logger.error(f"Error processing message: {e}")

    def send_to_sqs(self, data: Dict[str, Any]):
        """Send data to AWS SQS queue"""

        def _send():
            try:
                # Convert data to JSON string
                data_json = json.dumps(data)

                # Send to SQS
                response = self.sqs_client.send_message(
                    QueueUrl=self.queue_url, MessageBody=data_json
                )

                logger.debug(f"Sent message to SQS: {response['MessageId']}")

            except ClientError as e:
                logger.error(f"AWS SQS error: {e}")
            except Exception as e:
                logger.error(f"Error sending to SQS: {e}")

        # Run in a separate thread to avoid blocking
        thread = threading.Thread(target=_send)
        thread.start()

    def stop(self):
        """Stop the producer"""
        logger.info("Stopping producer...")
        self.running = False

    async def run(self):
        """Main run loop"""
        logger.info("Starting Binance WebSocket Producer")
        
        max_retries = 3
        retry_count = 0

        while self.running and retry_count < max_retries:
            try:
                await self.connect_websocket()
                retry_count = 0  # Reset retry count on successful connection
            except Exception as e:
                retry_count += 1
                logger.error(f"Connection lost (attempt {retry_count}/{max_retries}), retrying in 5 seconds: {e}")
                if retry_count >= max_retries:
                    logger.error("Max retries reached, stopping producer")
                    break
                await asyncio.sleep(5)


async def main():
    """Main entry point"""
    logger.info("Initializing Binance WebSocket Producer...")
    producer = BinanceWebSocketProducer()

    # Handle graceful shutdown
    def signal_handler():
        logger.info("Received shutdown signal")
        producer.stop()

    try:
        logger.info("Starting producer run loop...")
        await producer.run()
    except KeyboardInterrupt:
        logger.info("Received interrupt signal")
        signal_handler()
    except Exception as e:
        logger.error(f"Unexpected error: {e}")
        import traceback

        traceback.print_exc()
        sys.exit(1)


if __name__ == "__main__":
    asyncio.run(main())
