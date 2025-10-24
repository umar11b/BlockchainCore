variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "blockchain-core"
}

variable "environment" {
  description = "Environment (dev, staging, prod)"
  type        = string
  default     = "dev"
}



variable "data_retention_days" {
  description = "Number of days to retain data in S3"
  type        = number
  default     = 365
}

variable "price_threshold" {
  description = "Price movement threshold for anomaly detection (percentage)"
  type        = number
  default     = 5.0
}

variable "volume_threshold" {
  description = "Volume spike threshold for anomaly detection (multiplier)"
  type        = number
  default     = 3.0
}

variable "sma_threshold" {
  description = "SMA divergence threshold for anomaly detection (percentage)"
  type        = number
  default     = 2.0
}

variable "lambda_timeout" {
  description = "Lambda function timeout in seconds"
  type        = number
  default     = 300
}

variable "lambda_memory_size" {
  description = "Lambda function memory size in MB"
  type        = number
  default     = 512
}

variable "tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default = {
    Project     = "blockchain-core"
    Environment = "dev"
    ManagedBy   = "terraform"
  }
}
