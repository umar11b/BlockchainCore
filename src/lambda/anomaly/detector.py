"""
BlockchainCore Anomaly Detection Lambda
Detects anomalies in cryptocurrency data and sends alerts via SNS
"""

import json
import logging
import os
from datetime import datetime, timedelta
from statistics import mean
from typing import Any, Dict, List, Optional

import boto3
from botocore.exceptions import ClientError

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Initialize AWS clients
dynamodb = boto3.resource("dynamodb")
sns_client = boto3.client("sns")

# Environment variables
DYNAMODB_TABLE = os.environ["DYNAMODB_TABLE_NAME"]
SNS_TOPIC_ARN = os.environ["SNS_TOPIC_ARN"]
PRICE_THRESHOLD = float(os.environ.get("PRICE_THRESHOLD", "5.0"))
VOLUME_THRESHOLD = float(os.environ.get("VOLUME_THRESHOLD", "3.0"))
SMA_THRESHOLD = float(os.environ.get("SMA_THRESHOLD", "2.0"))

# Initialize DynamoDB table
table = dynamodb.Table(DYNAMODB_TABLE)


class AnomalyDetector:
    """Detect anomalies in cryptocurrency data"""

    def __init__(self):
        self.price_threshold = PRICE_THRESHOLD
        self.volume_threshold = VOLUME_THRESHOLD
        self.sma_threshold = SMA_THRESHOLD

    def get_recent_ohlcv_data(
        self, symbol: str, minutes: int = 60
    ) -> List[Dict[str, Any]]:
        """Get recent OHLCV data from DynamoDB"""
        try:
            # Calculate time range
            end_time = datetime.utcnow()
            start_time = end_time - timedelta(minutes=minutes)

            # Query DynamoDB
            response = table.query(
                KeyConditionExpression=(
                    "symbol = :symbol AND #ts BETWEEN :start AND :end"
                ),
                ExpressionAttributeNames={"#ts": "timestamp"},
                ExpressionAttributeValues={
                    ":symbol": symbol,
                    ":start": start_time.strftime("%Y-%m-%dT%H:%M:00Z"),
                    ":end": end_time.strftime("%Y-%m-%dT%H:%M:00Z"),
                },
                ScanIndexForward=False,  # Most recent first
                Limit=100,
            )

            return response.get("Items", [])

        except ClientError as e:
            logger.error(f"Error querying DynamoDB: {e}")
            return []

    def detect_price_anomaly(
        self, ohlcv_data: List[Dict[str, Any]]
    ) -> Optional[Dict[str, Any]]:
        """Detect price movement anomalies"""
        if len(ohlcv_data) < 2:
            return None

        # Get the most recent data points
        current = ohlcv_data[0]
        previous = ohlcv_data[1]

        # Calculate price change percentage
        current_price = current["close"]
        previous_price = previous["close"]
        price_change_pct = ((current_price - previous_price) / previous_price) * 100

        # Check if price change exceeds threshold
        if abs(price_change_pct) > self.price_threshold:
            return {
                "type": "price_movement",
                "symbol": current["symbol"],
                "current_price": current_price,
                "previous_price": previous_price,
                "price_change_pct": price_change_pct,
                "threshold": self.price_threshold,
                "timestamp": current["timestamp"],
                "severity": (
                    "high"
                    if abs(price_change_pct) > self.price_threshold * 2
                    else "medium"
                ),
            }

        return None

    def detect_volume_anomaly(
        self, ohlcv_data: List[Dict[str, Any]]
    ) -> Optional[Dict[str, Any]]:
        """Detect volume spike anomalies"""
        if len(ohlcv_data) < 10:
            return None

        # Get recent volume data
        recent_volumes = [data["volume"] for data in ohlcv_data[:10]]
        current_volume = recent_volumes[0]

        # Calculate average volume (excluding current)
        avg_volume = mean(recent_volumes[1:])

        # Check if current volume exceeds threshold
        volume_ratio = current_volume / avg_volume if avg_volume > 0 else 0

        if volume_ratio > self.volume_threshold:
            return {
                "type": "volume_spike",
                "symbol": ohlcv_data[0]["symbol"],
                "current_volume": current_volume,
                "average_volume": avg_volume,
                "volume_ratio": volume_ratio,
                "threshold": self.volume_threshold,
                "timestamp": ohlcv_data[0]["timestamp"],
                "severity": (
                    "high" if volume_ratio > self.volume_threshold * 2 else "medium"
                ),
            }

        return None

    def calculate_sma(
        self, ohlcv_data: List[Dict[str, Any]], period: int = 20
    ) -> Optional[float]:
        """Calculate Simple Moving Average"""
        if len(ohlcv_data) < period:
            return None

        prices = [data["close"] for data in ohlcv_data[:period]]
        return mean(prices)

    def detect_sma_divergence(
        self, ohlcv_data: List[Dict[str, Any]]
    ) -> Optional[Dict[str, Any]]:
        """Detect SMA divergence anomalies"""
        if len(ohlcv_data) < 25:
            return None

        current = ohlcv_data[0]
        current_price = current["close"]

        # Calculate short-term and long-term SMAs
        short_sma = self.calculate_sma(ohlcv_data, 10)
        long_sma = self.calculate_sma(ohlcv_data, 20)

        if short_sma is None or long_sma is None:
            return None

        # Calculate divergence
        divergence_pct = ((short_sma - long_sma) / long_sma) * 100

        # Check if divergence exceeds threshold
        if abs(divergence_pct) > self.sma_threshold:
            return {
                "type": "sma_divergence",
                "symbol": current["symbol"],
                "current_price": current_price,
                "short_sma": short_sma,
                "long_sma": long_sma,
                "divergence_pct": divergence_pct,
                "threshold": self.sma_threshold,
                "timestamp": current["timestamp"],
                "severity": (
                    "high" if abs(divergence_pct) > self.sma_threshold * 2 else "medium"
                ),
            }

        return None

    def detect_anomalies(self, symbol: str) -> List[Dict[str, Any]]:
        """Detect all types of anomalies for a symbol"""
        anomalies = []

        # Get recent OHLCV data
        ohlcv_data = self.get_recent_ohlcv_data(symbol)

        if not ohlcv_data:
            logger.warning(f"No OHLCV data found for symbol: {symbol}")
            return anomalies

        # Detect price anomalies
        price_anomaly = self.detect_price_anomaly(ohlcv_data)
        if price_anomaly:
            anomalies.append(price_anomaly)

        # Detect volume anomalies
        volume_anomaly = self.detect_volume_anomaly(ohlcv_data)
        if volume_anomaly:
            anomalies.append(volume_anomaly)

        # Detect SMA divergence
        sma_anomaly = self.detect_sma_divergence(ohlcv_data)
        if sma_anomaly:
            anomalies.append(sma_anomaly)

        return anomalies


def send_sns_alert(anomaly: Dict[str, Any]):
    """Send anomaly alert via SNS"""
    try:
        # Create alert message
        if anomaly["type"] == "price_movement":
            message = f"""
🚨 PRICE MOVEMENT ALERT 🚨
Symbol: {anomaly['symbol']}
Price Change: {anomaly['price_change_pct']:.2f}%
Current Price: ${anomaly['current_price']:.2f}
Previous Price: ${anomaly['previous_price']:.2f}
Threshold: {anomaly['threshold']}%
Severity: {anomaly['severity'].upper()}
Time: {anomaly['timestamp']}
            """
        elif anomaly["type"] == "volume_spike":
            message = f"""
📈 VOLUME SPIKE ALERT 📈
Symbol: {anomaly['symbol']}
Volume Ratio: {anomaly['volume_ratio']:.2f}x
Current Volume: {anomaly['current_volume']:.2f}
Average Volume: {anomaly['average_volume']:.2f}
Threshold: {anomaly['threshold']}x
Severity: {anomaly['severity'].upper()}
Time: {anomaly['timestamp']}
            """
        elif anomaly["type"] == "sma_divergence":
            message = f"""
📊 SMA DIVERGENCE ALERT 📊
Symbol: {anomaly['symbol']}
Divergence: {anomaly['divergence_pct']:.2f}%
Current Price: ${anomaly['current_price']:.2f}
Short SMA: ${anomaly['short_sma']:.2f}
Long SMA: ${anomaly['long_sma']:.2f}
Threshold: {anomaly['threshold']}%
Severity: {anomaly['severity'].upper()}
Time: {anomaly['timestamp']}
            """
        else:
            message = f"Unknown anomaly type: {anomaly['type']}"

        # Send SNS message
        response = sns_client.publish(
            TopicArn=SNS_TOPIC_ARN,
            Subject=(
                f"BlockchainCore Alert: {anomaly['type'].replace('_', ' ').title()}"
            ),
            Message=message.strip(),
        )

        logger.info(f"Sent SNS alert: {response['MessageId']}")

    except ClientError as e:
        logger.error(f"Error sending SNS alert: {e}")
        raise


def lambda_handler(event, context):
    """Lambda handler for anomaly detection"""
    logger.info("Starting anomaly detection")

    detector = AnomalyDetector()
    all_anomalies = []

    try:
        # Get list of symbols from DynamoDB
        response = table.scan(
            ProjectionExpression="symbol", Select="SPECIFIC_ATTRIBUTES"
        )

        symbols = list(set([item["symbol"] for item in response.get("Items", [])]))
        logger.info(f"Found {len(symbols)} symbols to analyze")

        # Detect anomalies for each symbol
        for symbol in symbols:
            anomalies = detector.detect_anomalies(symbol)
            all_anomalies.extend(anomalies)

            # Send alerts for detected anomalies
            for anomaly in anomalies:
                send_sns_alert(anomaly)

        logger.info(f"Detection complete. Found {len(all_anomalies)} anomalies")

        return {
            "statusCode": 200,
            "body": json.dumps(
                {
                    "message": "Anomaly detection complete",
                    "anomalies_found": len(all_anomalies),
                    "symbols_analyzed": len(symbols),
                    "anomalies": all_anomalies,
                }
            ),
        }

    except Exception as e:
        logger.error(f"Error in anomaly detection: {e}")
        raise
