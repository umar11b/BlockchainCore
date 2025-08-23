#!/usr/bin/env python3
"""
Minimal test to debug the hanging issue
"""

import asyncio
import websockets
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

async def minimal_test():
    """Minimal test of websockets"""
    logger.info("Starting minimal test...")
    
    try:
        logger.info("About to connect...")
        websocket = await websockets.connect("wss://stream.binance.com:9443/ws/btcusdt@trade")
        logger.info("✅ Connected successfully!")
        
        # Try to receive one message
        message = await websocket.recv()
        logger.info(f"✅ Received message: {message[:100]}...")
        
        await websocket.close()
        logger.info("✅ Test completed successfully!")
        
    except Exception as e:
        logger.error(f"❌ Test failed: {e}")
        import traceback
        traceback.print_exc()

if __name__ == "__main__":
    asyncio.run(minimal_test())
