"""
AWS Helper Utilities for BlockchainCore
Common AWS operations and utilities
"""

import json
import logging
from typing import Any, Dict, List, Optional

import boto3
from botocore.exceptions import ClientError, NoCredentialsError

logger = logging.getLogger(__name__)


class AWSHelper:
    """Helper class for AWS operations"""

    def __init__(self, region_name: str = "us-east-1"):
        self.region_name = region_name
        self._clients: Dict[str, Any] = {}

    def get_client(self, service_name: str):
        """Get or create AWS client"""
        if service_name not in self._clients:
            try:
                self._clients[service_name] = boto3.client(
                    service_name, region_name=self.region_name
                )
            except NoCredentialsError:
                logger.error(f"AWS credentials not found for {service_name}")
                raise
        return self._clients[service_name]

    def get_resource(self, service_name: str):
        """Get or create AWS resource"""
        try:
            return boto3.resource(service_name, region_name=self.region_name)
        except NoCredentialsError:
            logger.error(f"AWS credentials not found for {service_name}")
            raise


class SQSHelper(AWSHelper):
    """Helper for SQS operations"""

    def send_message(
        self, queue_url: str, data: Dict[str, Any], delay_seconds: int = 0
    ) -> Dict[str, Any]:
        """Send a message to SQS queue"""
        try:
            client = self.get_client("sqs")
            kwargs: Dict[str, Any] = {
                "QueueUrl": queue_url,
                "MessageBody": json.dumps(data),
            }
            if delay_seconds > 0:
                kwargs["DelaySeconds"] = delay_seconds

            response = client.send_message(**kwargs)
            logger.debug(f"Message sent to SQS: {response['MessageId']}")
            return response
        except ClientError as e:
            logger.error(f"Error sending message to SQS: {e}")
            raise

    def receive_messages(
        self,
        queue_url: str,
        max_messages: int = 10,
        wait_time_seconds: int = 20,
    ) -> List[Dict[str, Any]]:
        """Receive messages from SQS queue"""
        try:
            client = self.get_client("sqs")
            response = client.receive_message(
                QueueUrl=queue_url,
                MaxNumberOfMessages=max_messages,
                WaitTimeSeconds=wait_time_seconds,
            )
            return response.get("Messages", [])
        except ClientError as e:
            logger.error(f"Error receiving messages from SQS: {e}")
            raise

    def delete_message(self, queue_url: str, receipt_handle: str) -> Dict[str, Any]:
        """Delete a message from SQS queue"""
        try:
            client = self.get_client("sqs")
            response = client.delete_message(
                QueueUrl=queue_url,
                ReceiptHandle=receipt_handle,
            )
            logger.debug(f"Message deleted from SQS: {receipt_handle}")
            return response
        except ClientError as e:
            logger.error(f"Error deleting message from SQS: {e}")
            raise

    def get_queue_attributes(self, queue_url: str) -> Dict[str, Any]:
        """Get SQS queue attributes"""
        try:
            client = self.get_client("sqs")
            response = client.get_queue_attributes(
                QueueUrl=queue_url, AttributeNames=["All"]
            )
            return response.get("Attributes", {})
        except ClientError as e:
            logger.error(f"Error getting SQS queue attributes: {e}")
            raise


class S3Helper(AWSHelper):
    """Helper for S3 operations"""

    def put_object(
        self,
        bucket: str,
        key: str,
        data: str,
        content_type: str = "application/json",
    ) -> Dict[str, Any]:
        """Put an object to S3"""
        try:
            client = self.get_client("s3")
            response = client.put_object(
                Bucket=bucket,
                Key=key,
                Body=data,
                ContentType=content_type,
            )
            logger.debug(f"Object uploaded to S3: {bucket}/{key}")
            return response
        except ClientError as e:
            logger.error(f"Error uploading to S3: {e}")
            raise

    def get_object(self, bucket: str, key: str) -> Optional[str]:
        """Get an object from S3"""
        try:
            client = self.get_client("s3")
            response = client.get_object(Bucket=bucket, Key=key)
            return response["Body"].read().decode("utf-8")
        except ClientError as e:
            if e.response["Error"]["Code"] == "NoSuchKey":
                logger.warning(f"Object not found: {bucket}/{key}")
                return None
            logger.error(f"Error getting object from S3: {e}")
            raise

    def list_objects(self, bucket: str, prefix: str = "") -> List[str]:
        """List objects in S3 bucket with prefix"""
        try:
            client = self.get_client("s3")
            response = client.list_objects_v2(Bucket=bucket, Prefix=prefix)
            return [obj["Key"] for obj in response.get("Contents", [])]
        except ClientError as e:
            logger.error(f"Error listing objects in S3: {e}")
            raise


class DynamoDBHelper(AWSHelper):
    """Helper for DynamoDB operations"""

    def __init__(self, table_name: str, region_name: str = "us-east-1"):
        super().__init__(region_name)
        self.table_name = table_name
        self.table = self.get_resource("dynamodb").Table(table_name)

    def put_item(self, item: Dict[str, Any]) -> Dict[str, Any]:
        """Put an item to DynamoDB"""
        try:
            response = self.table.put_item(Item=item)
            logger.debug(f"Item put to DynamoDB: {item.get('symbol', 'unknown')}")
            return response
        except ClientError as e:
            logger.error(f"Error putting item to DynamoDB: {e}")
            raise

    def get_item(self, key: Dict[str, Any]) -> Optional[Dict[str, Any]]:
        """Get an item from DynamoDB"""
        try:
            response = self.table.get_item(Key=key)
            return response.get("Item")
        except ClientError as e:
            logger.error(f"Error getting item from DynamoDB: {e}")
            raise

    def query(
        self,
        key_condition_expression: str,
        expression_values: Dict[str, Any],
        scan_index_forward: bool = True,
        limit: int = None,
    ) -> List[Dict[str, Any]]:
        """Query items from DynamoDB"""
        try:
            kwargs = {
                "KeyConditionExpression": key_condition_expression,
                "ExpressionAttributeValues": expression_values,
                "ScanIndexForward": scan_index_forward,
            }
            if limit:
                kwargs["Limit"] = limit

            response = self.table.query(**kwargs)
            return response.get("Items", [])
        except ClientError as e:
            logger.error(f"Error querying DynamoDB: {e}")
            raise

    def scan(
        self,
        filter_expression: str = None,
        expression_values: Dict[str, Any] = None,
    ) -> List[Dict[str, Any]]:
        """Scan items from DynamoDB"""
        try:
            kwargs: Dict[str, Any] = {}
            if filter_expression:
                kwargs["FilterExpression"] = filter_expression
            if expression_values:
                kwargs["ExpressionAttributeValues"] = expression_values

            response = self.table.scan(**kwargs)
            return response.get("Items", [])
        except ClientError as e:
            logger.error(f"Error scanning DynamoDB: {e}")
            raise


class SNSHelper(AWSHelper):
    """Helper for SNS operations"""

    def publish_message(
        self, topic_arn: str, message: str, subject: str = None
    ) -> Dict[str, Any]:
        """Publish a message to SNS topic"""
        try:
            client = self.get_client("sns")
            kwargs = {"TopicArn": topic_arn, "Message": message}
            if subject:
                kwargs["Subject"] = subject

            response = client.publish(**kwargs)
            logger.info(f"Message published to SNS: {response['MessageId']}")
            return response
        except ClientError as e:
            logger.error(f"Error publishing to SNS: {e}")
            raise

    def create_topic(self, name: str) -> str:
        """Create an SNS topic"""
        try:
            client = self.get_client("sns")
            response = client.create_topic(Name=name)
            topic_arn = response["TopicArn"]
            logger.info(f"SNS topic created: {topic_arn}")
            return topic_arn
        except ClientError as e:
            logger.error(f"Error creating SNS topic: {e}")
            raise

    def subscribe_email(self, topic_arn: str, email: str) -> str:
        """Subscribe an email to SNS topic"""
        try:
            client = self.get_client("sns")
            response = client.subscribe(
                TopicArn=topic_arn, Protocol="email", Endpoint=email
            )
            subscription_arn = response["SubscriptionArn"]
            logger.info(f"Email subscribed to SNS: {subscription_arn}")
            return subscription_arn
        except ClientError as e:
            logger.error(f"Error subscribing email to SNS: {e}")
            raise


def get_aws_account_id() -> str:
    """Get current AWS account ID"""
    try:
        sts = boto3.client("sts")
        response = sts.get_caller_identity()
        return response["Account"]
    except Exception as e:
        logger.error(f"Error getting AWS account ID: {e}")
        raise


def validate_aws_credentials() -> bool:
    """Validate AWS credentials are configured"""
    try:
        sts = boto3.client("sts")
        sts.get_caller_identity()
        return True
    except Exception:
        return False
