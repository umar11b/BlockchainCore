"""
GCP Cloud Function for BlockchainCore
Processes trade data from Pub/Sub and stores in Firestore
"""

import base64
import json
import os
from datetime import datetime

from google.api_core.exceptions import GoogleAPIError
from google.cloud import firestore, storage

# Initialize Firestore and Storage clients
db = firestore.Client()
storage_client = storage.Client()

# Environment variables
FIRESTORE_COLLECTION = os.environ.get(
    "FIRESTORE_COLLECTION", "blockchain-core-ohlcv-data"
)
GCP_PROJECT_ID = os.environ.get("GCP_PROJECT_ID")
RAW_DATA_BUCKET = os.environ.get(
    "RAW_DATA_BUCKET"
)  # This will be set by the deploy script


def process_trade_data(event, context):
    """
    Cloud Function that processes messages from a Pub/Sub topic.
    The message contains trade data from Binance.
    It stores the data in Firestore and raw data in Cloud Storage.
    """
    if "data" not in event:
        print("No data found in the Pub/Sub message.")
        return

    try:
        # Decode the Pub/Sub message
        pubsub_message = base64.b64decode(event["data"]).decode("utf-8")
        trade_data = json.loads(pubsub_message)

        print(f"Received trade data: {trade_data}")

        # Add a processed_at timestamp
        trade_data["processed_at"] = datetime.utcnow().isoformat() + "Z"

        # Store in Firestore
        store_in_firestore(trade_data)

        # Store raw data in Cloud Storage
        if RAW_DATA_BUCKET:
            store_raw_in_cloud_storage(trade_data)
        else:
            print(
                "RAW_DATA_BUCKET environment variable not set. "
                "Skipping raw data storage."
            )

    except json.JSONDecodeError as e:
        print(f"Error decoding JSON: {e}. Message data: {event['data']}")
    except GoogleAPIError as e:
        print(f"Google Cloud API error: {e}")
    except Exception as e:
        print(f"An unexpected error occurred: {e}")


def store_in_firestore(data):
    """Stores processed trade data in Firestore."""
    try:
        doc_ref = db.collection(FIRESTORE_COLLECTION).document(data["trade_id"])
        doc_ref.set(data)
        print(f"Successfully stored trade {data['trade_id']} in Firestore.")
    except Exception as e:
        print(f"Error storing data in Firestore: {e}")


def store_raw_in_cloud_storage(data):
    """Stores raw trade data in Cloud Storage."""
    try:
        bucket = storage_client.bucket(RAW_DATA_BUCKET)
        # Use a timestamped path to avoid overwrites and organize data
        timestamp = datetime.utcnow().strftime("%Y/%m/%d/%H")
        blob_name = f"raw_trades/{timestamp}/{data['trade_id']}.json"
        blob = bucket.blob(blob_name)
        blob.upload_from_string(json.dumps(data), content_type="application/json")
        print(
            f"Successfully stored raw trade {data['trade_id']} "
            f"in Cloud Storage bucket {RAW_DATA_BUCKET}."
        )
    except Exception as e:
        print(f"Error storing raw data in Cloud Storage: {e}")
