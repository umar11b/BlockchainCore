terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Data sources
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# S3 Bucket for raw data storage
resource "aws_s3_bucket" "raw_data" {
  bucket = "${var.project_name}-raw-data-${random_string.bucket_suffix.result}"
  
  force_destroy = true  # Allow Terraform to destroy bucket even if it contains objects

  tags = {
    Name        = "${var.project_name}-raw-data"
    Environment = var.environment
    Project     = var.project_name
  }
}

resource "aws_s3_bucket_versioning" "raw_data" {
  bucket = aws_s3_bucket.raw_data.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "raw_data" {
  bucket = aws_s3_bucket.raw_data.id

  rule {
    id     = "data_retention"
    status = "Enabled"

    filter {
      prefix = ""
    }

    expiration {
      days = var.data_retention_days
    }

    noncurrent_version_expiration {
      noncurrent_days = 30
    }
  }
}

# SQS Queue for trade data processing
resource "aws_sqs_queue" "trade_data" {
  name = "${var.project_name}-trade-data"

  visibility_timeout_seconds = 300
  message_retention_seconds  = 1209600  # 14 days
  receive_wait_time_seconds  = 20       # Long polling

  tags = {
    Name        = "${var.project_name}-trade-data"
    Environment = var.environment
    Project     = var.project_name
  }
}

# DynamoDB Table for OHLCV data
resource "aws_dynamodb_table" "ohlcv_data" {
  name           = "${var.project_name}-ohlcv-data"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "symbol"
  range_key      = "timestamp"

  attribute {
    name = "symbol"
    type = "S"
  }

  attribute {
    name = "timestamp"
    type = "S"
  }

  tags = {
    Name        = "${var.project_name}-ohlcv-data"
    Environment = var.environment
    Project     = var.project_name
  }
}

# SNS Topic for alerts
resource "aws_sns_topic" "alerts" {
  name = "${var.project_name}-alerts"

  tags = {
    Name        = "${var.project_name}-alerts"
    Environment = var.environment
    Project     = var.project_name
  }
}

# SNS Topic Policy
resource "aws_sns_topic_policy" "alerts" {
  arn = aws_sns_topic.alerts.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action   = "SNS:Publish"
        Resource = aws_sns_topic.alerts.arn
      }
    ]
  })
}

# IAM Role for Lambda functions
resource "aws_iam_role" "lambda_role" {
  name = "${var.project_name}-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-lambda-role"
    Environment = var.environment
    Project     = var.project_name
  }
}

# IAM Policy for Lambda functions
resource "aws_iam_role_policy" "lambda_policy" {
  name = "${var.project_name}-lambda-policy"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes",
          "sqs:ChangeMessageVisibility"
        ]
        Resource = aws_sqs_queue.trade_data.arn
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        Resource = "${aws_s3_bucket.raw_data.arn}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:DeleteItem",
          "dynamodb:Query",
          "dynamodb:Scan"
        ]
        Resource = aws_dynamodb_table.ohlcv_data.arn
      },
      {
        Effect = "Allow"
        Action = [
          "sns:Publish"
        ]
        Resource = aws_sns_topic.alerts.arn
      }
    ]
  })
}

# Lambda function for data processing
resource "aws_lambda_function" "processor" {
  filename         = "../src/lambda/processor/processor.zip"
  function_name    = "${var.project_name}-processor"
  role            = aws_iam_role.lambda_role.arn
  handler         = "processor.lambda_handler"
  runtime         = "python3.9"
  timeout         = 300
  memory_size     = 512

  environment {
    variables = {
      SQS_QUEUE_URL      = aws_sqs_queue.trade_data.url
      S3_BUCKET_NAME     = aws_s3_bucket.raw_data.bucket
      DYNAMODB_TABLE_NAME = aws_dynamodb_table.ohlcv_data.name
      SNS_TOPIC_ARN      = aws_sns_topic.alerts.arn
    }
  }

  tags = {
    Name        = "${var.project_name}-processor"
    Environment = var.environment
    Project     = var.project_name
  }
}

# Lambda function for anomaly detection
resource "aws_lambda_function" "anomaly_detector" {
  filename         = "../src/lambda/anomaly/anomaly.zip"
  function_name    = "${var.project_name}-anomaly-detector"
  role            = aws_iam_role.lambda_role.arn
  handler         = "detector.lambda_handler"
  runtime         = "python3.9"
  timeout         = 60
  memory_size     = 256

  environment {
    variables = {
      DYNAMODB_TABLE_NAME = aws_dynamodb_table.ohlcv_data.name
      SNS_TOPIC_ARN      = aws_sns_topic.alerts.arn
      PRICE_THRESHOLD    = var.price_threshold
      VOLUME_THRESHOLD   = var.volume_threshold
      SMA_THRESHOLD      = var.sma_threshold
    }
  }

  tags = {
    Name        = "${var.project_name}-anomaly-detector"
    Environment = var.environment
    Project     = var.project_name
  }
}

# EventBridge rule to trigger anomaly detection
resource "aws_cloudwatch_event_rule" "anomaly_detection" {
  name                = "${var.project_name}-anomaly-detection"
  description         = "Trigger anomaly detection every minute"
  schedule_expression = "rate(1 minute)"

  tags = {
    Name        = "${var.project_name}-anomaly-detection"
    Environment = var.environment
    Project     = var.project_name
  }
}

resource "aws_cloudwatch_event_target" "anomaly_detection" {
  rule      = aws_cloudwatch_event_rule.anomaly_detection.name
  target_id = "AnomalyDetectionTarget"
  arn       = aws_lambda_function.anomaly_detector.arn
}

resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.anomaly_detector.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.anomaly_detection.arn
}

# SQS trigger for processor Lambda
resource "aws_lambda_event_source_mapping" "processor" {
  event_source_arn = aws_sqs_queue.trade_data.arn
  function_name    = aws_lambda_function.processor.arn
  batch_size       = 10
  maximum_batching_window_in_seconds = 5
}

# CloudWatch Log Groups
resource "aws_cloudwatch_log_group" "processor" {
  name              = "/aws/lambda/${aws_lambda_function.processor.function_name}"
  retention_in_days = 14

  tags = {
    Name        = "${var.project_name}-processor-logs"
    Environment = var.environment
    Project     = var.project_name
  }
}

resource "aws_cloudwatch_log_group" "anomaly_detector" {
  name              = "/aws/lambda/${aws_lambda_function.anomaly_detector.function_name}"
  retention_in_days = 14

  tags = {
    Name        = "${var.project_name}-anomaly-detector-logs"
    Environment = var.environment
    Project     = var.project_name
  }
}

# Random string for bucket naming
resource "random_string" "bucket_suffix" {
  length  = 8
  special = false
  upper   = false
}
