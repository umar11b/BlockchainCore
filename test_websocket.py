#!/usr/bin/env python3
"""
Simple test script to check Binance WebSocket connectivity
"""

import asyncio
import websockets
import json
import logging

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

async def test_binance_websocket():
    """Test Binance WebSocket connection"""
    uri = "wss://stream.binance.com:9443/ws/btcusdt@trade"
    logger.info(f"Testing connection to: {uri}")
    
    try:
        async with websockets.connect(uri, ping_interval=20, ping_timeout=20) as websocket:
            logger.info("✅ Successfully connected to Binance WebSocket!")
            
            # Try to receive a few messages
            for i in range(5):
                try:
                    message = await asyncio.wait_for(websocket.recv(), timeout=10.0)
                    data = json.loads(message)
                    logger.info(f"Received message {i+1}: {data.get('s', 'unknown')} @ {data.get('p', 'unknown')}")
                except asyncio.TimeoutError:
                    logger.warning(f"Timeout waiting for message {i+1}")
                    break
                    
    except Exception as e:
        logger.error(f"❌ Failed to connect: {e}")
        return False
    
    return True

if __name__ == "__main__":
    asyncio.run(test_binance_websocket())
