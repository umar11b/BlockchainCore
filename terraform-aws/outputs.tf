output "sqs_queue_arn" {
  description = "ARN of the SQS queue"
  value       = aws_sqs_queue.trade_data.arn
}

output "sqs_queue_url" {
  description = "URL of the SQS queue"
  value       = aws_sqs_queue.trade_data.url
}

output "s3_bucket_name" {
  description = "Name of the S3 bucket for raw data"
  value       = aws_s3_bucket.raw_data.bucket
}

output "s3_bucket_arn" {
  description = "ARN of the S3 bucket for raw data"
  value       = aws_s3_bucket.raw_data.arn
}

output "dynamodb_table_name" {
  description = "Name of the DynamoDB table for OHLCV data"
  value       = aws_dynamodb_table.ohlcv_data.name
}

output "dynamodb_table_arn" {
  description = "ARN of the DynamoDB table for OHLCV data"
  value       = aws_dynamodb_table.ohlcv_data.arn
}

output "sns_topic_arn" {
  description = "ARN of the SNS topic for alerts"
  value       = aws_sns_topic.alerts.arn
}

output "sns_topic_name" {
  description = "Name of the SNS topic for alerts"
  value       = aws_sns_topic.alerts.name
}

output "lambda_processor_arn" {
  description = "ARN of the data processor Lambda function"
  value       = aws_lambda_function.processor.arn
}

output "lambda_processor_name" {
  description = "Name of the data processor Lambda function"
  value       = aws_lambda_function.processor.function_name
}

output "lambda_anomaly_detector_arn" {
  description = "ARN of the anomaly detector Lambda function"
  value       = aws_lambda_function.anomaly_detector.arn
}

output "lambda_anomaly_detector_name" {
  description = "Name of the anomaly detector Lambda function"
  value       = aws_lambda_function.anomaly_detector.function_name
}

output "lambda_role_arn" {
  description = "ARN of the Lambda execution role"
  value       = aws_iam_role.lambda_role.arn
}

output "eventbridge_rule_arn" {
  description = "ARN of the EventBridge rule for anomaly detection"
  value       = aws_cloudwatch_event_rule.anomaly_detection.arn
}

output "cloudwatch_log_groups" {
  description = "CloudWatch log group names"
  value = {
    processor       = aws_cloudwatch_log_group.processor.name
    anomaly_detector = aws_cloudwatch_log_group.anomaly_detector.name
  }
}

output "environment_variables" {
  description = "Environment variables for the producer application"
  value = {
    SQS_QUEUE_URL      = aws_sqs_queue.trade_data.url
    S3_BUCKET_NAME     = aws_s3_bucket.raw_data.bucket
    DYNAMODB_TABLE_NAME = aws_dynamodb_table.ohlcv_data.name
    SNS_TOPIC_ARN      = aws_sns_topic.alerts.arn
  }
}
