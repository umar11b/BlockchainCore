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
    level=logging.INFO, format="%(asctime)s - %(name)s - %(levelname)s - %(message)s"
)
logger = logging.getLogger(__name__)


class BinanceWebSocketProducer:
    """Producer for streaming Binance trade data to AWS SQS"""

    def __init__(self):
        self.sqs_client = boto3.client("sqs")
        self.queue_url = os.getenv("SQS_QUEUE_URL", "")
        self.websocket_url = os.getenv(
            "BINANCE_WEBSOCKET_URL", "wss://stream.binance.com:9443/ws/btcusdt@trade"
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
            uri = f"wss://stream.binance.com:9443/ws/{self.symbol.lower()}@trade"
            logger.info(f"Connecting to Binance WebSocket: {uri}")

            # Simple connection without context manager
            websocket = await websockets.connect(uri, ping_interval=20, ping_timeout=20)
            logger.info("Connected to Binance WebSocket")
            self.running = True

            try:
                async for message in websocket:
                    if not self.running:
                        break

                    try:
                        await self.process_message(message)
                    except Exception as e:
                        logger.error(f"Error processing message: {e}")
            finally:
                await websocket.close()

        except asyncio.TimeoutError:
            logger.error("Timeout connecting to Binance WebSocket")
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

        while self.running:
            try:
                await self.connect_websocket()
            except Exception as e:
                logger.error(f"Connection lost, retrying in 5 seconds: {e}")
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
