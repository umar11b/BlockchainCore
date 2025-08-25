"""
Unit tests for the data processor Lambda function
"""

import json
import os
import sys
from datetime import datetime
from unittest.mock import Mock, patch

import pytest

# Set up environment variables for testing
os.environ["S3_BUCKET_NAME"] = "test-bucket"
os.environ["DYNAMODB_TABLE_NAME"] = "test-table"
os.environ["SNS_TOPIC_ARN"] = "arn:aws:sns:us-east-1:123456789012:test-topic"

# Add src to path for imports
sys.path.insert(
    0, os.path.join(os.path.dirname(__file__), "..", "src", "lambda", "processor")
)

from processor import (OHLCVCalculator, lambda_handler,  # noqa: E402
                       store_ohlcv_in_dynamodb, store_raw_data_in_s3)


class TestOHLCVCalculator:
    """Test OHLCV calculator functionality"""

    def test_initialization(self):
        """Test calculator initialization"""
        calculator = OHLCVCalculator("BTCUSDT")
        assert calculator.symbol == "BTCUSDT"
        assert calculator.interval_minutes == 1
        assert calculator.current_interval is None
        assert calculator.ohlcv_data["open"] is None

    def test_get_interval_key(self):
        """Test interval key generation"""
        calculator = OHLCVCalculator("BTCUSDT")
        timestamp_ms = int(datetime(2023, 1, 1, 12, 30, 45).timestamp() * 1000)
        interval_key = calculator.get_interval_key(timestamp_ms)
        assert interval_key == "2023-01-01T12:30:00Z"

    def test_process_trade_new_interval(self):
        """Test processing trade in new interval"""
        calculator = OHLCVCalculator("BTCUSDT")

        # Mock trade data
        trade_data = {
            "s": "BTCUSDT",
            "p": "50000.00",
            "q": "0.1",
            "E": int(datetime(2023, 1, 1, 12, 30, 30).timestamp() * 1000),
        }

        result = calculator.process_trade(trade_data)
        assert result is None  # No complete interval yet
        assert calculator.ohlcv_data["open"] == 50000.00
        assert calculator.ohlcv_data["high"] == 50000.00
        assert calculator.ohlcv_data["low"] == 50000.00
        assert calculator.ohlcv_data["close"] == 50000.00
        assert calculator.ohlcv_data["volume"] == 0.1

    def test_process_trade_complete_interval(self):
        """Test processing trade that completes an interval"""
        calculator = OHLCVCalculator("BTCUSDT")

        # First trade in interval
        trade1 = {
            "s": "BTCUSDT",
            "p": "50000.00",
            "q": "0.1",
            "E": int(datetime(2023, 1, 1, 12, 30, 30).timestamp() * 1000),
        }
        calculator.process_trade(trade1)

        # Second trade in new interval
        trade2 = {
            "s": "BTCUSDT",
            "p": "51000.00",
            "q": "0.2",
            "E": int(datetime(2023, 1, 1, 12, 31, 30).timestamp() * 1000),
        }
        result = calculator.process_trade(trade2)

        # Should return None since no complete interval yet
        assert result is None

        # Check that the new interval data is being processed
        assert calculator.ohlcv_data["open"] == 51000.00
        assert calculator.ohlcv_data["high"] == 51000.00
        assert calculator.ohlcv_data["low"] == 51000.00
        assert calculator.ohlcv_data["close"] == 51000.00
        assert calculator.ohlcv_data["volume"] == 0.2

    def test_get_ohlcv_data(self):
        """Test getting OHLCV data"""
        calculator = OHLCVCalculator("BTCUSDT")

        # No data yet
        result = calculator.get_ohlcv_data()
        assert result is None

        # Add some data
        trade_data = {
            "s": "BTCUSDT",
            "p": "50000.00",
            "q": "0.1",
            "E": int(datetime(2023, 1, 1, 12, 30, 30).timestamp() * 1000),
        }
        calculator.process_trade(trade_data)

        result = calculator.get_ohlcv_data()
        assert result is not None
        assert result["symbol"] == "BTCUSDT"
        assert result["open"] == 50000.00


class TestDataStorage:
    """Test data storage functions"""

    @patch("processor.get_s3_client")
    def test_store_raw_data_in_s3(self, mock_get_s3_client):
        """Test storing raw data in S3"""
        trade_data = {
            "s": "BTCUSDT",
            "p": "50000.00",
            "q": "0.1",
            "E": int(datetime(2023, 1, 1, 12, 30, 30).timestamp() * 1000),
        }
        timestamp = datetime(2023, 1, 1, 12, 30, 30)

        store_raw_data_in_s3(trade_data, timestamp)

        mock_get_s3_client.return_value.put_object.assert_called_once()
        call_args = mock_get_s3_client.return_value.put_object.call_args
        assert call_args[1]["Bucket"] == "test-bucket"
        assert "raw-data/2023/01/01/12/trades_20230101_1230.json" in call_args[1]["Key"]

    @patch("processor.get_table")
    def test_store_ohlcv_in_dynamodb(self, mock_get_table):
        """Test storing OHLCV data in DynamoDB"""
        ohlcv_data = {
            "symbol": "BTCUSDT",
            "timestamp": "2023-01-01T12:30:00Z",
            "open": 50000.00,
            "high": 51000.00,
            "low": 49000.00,
            "close": 50500.00,
            "volume": 1.5,
            "trade_count": 10,
        }

        store_ohlcv_in_dynamodb(ohlcv_data)

        mock_get_table.return_value.put_item.assert_called_once()
        call_args = mock_get_table.return_value.put_item.call_args
        item = call_args[1]["Item"]
        assert item["symbol"] == "BTCUSDT"
        assert item["open"] == 50000.00
        assert item["volume"] == 1.5


class TestLambdaHandler:
    """Test Lambda handler function"""

    @patch("processor.store_raw_data_in_s3")
    @patch("processor.store_ohlcv_in_dynamodb")
    def test_lambda_handler_success(self, mock_store_ohlcv, mock_store_raw):
        """Test successful Lambda handler execution"""
        # Mock SQS event
        event = {
            "Records": [
                {
                    "body": json.dumps(
                        {
                            "s": "BTCUSDT",
                            "p": "50000.00",
                            "q": "0.1",
                            "E": int(
                                datetime(2023, 1, 1, 12, 30, 30).timestamp() * 1000
                            ),
                        }
                    )
                }
            ]
        }

        # Mock context
        context = Mock()

        # Call handler
        result = lambda_handler(event, context)

        # Verify result
        assert result["statusCode"] == 200
        assert "Processed 1 records" in result["body"]

        # Verify function calls
        mock_store_raw.assert_called_once()

    @patch("processor.store_raw_data_in_s3")
    def test_lambda_handler_error(self, mock_store_raw):
        """Test Lambda handler with error"""
        # Mock SQS event with invalid data
        event = {"Records": [{"body": "invalid json"}]}

        # Mock context
        context = Mock()

        # Call handler and expect exception
        with pytest.raises(Exception):
            lambda_handler(event, context)

    def test_lambda_handler_empty_records(self):
        """Test Lambda handler with empty records"""
        event = {"Records": []}
        context = Mock()

        result = lambda_handler(event, context)

        assert result["statusCode"] == 200
        assert "Processed 0 records" in result["body"]


if __name__ == "__main__":
    pytest.main([__file__])
