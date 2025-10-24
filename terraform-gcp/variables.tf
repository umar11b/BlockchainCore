# GCP Terraform Variables

variable "gcp_project_id" {
  description = "GCP Project ID where resources will be created"
  type        = string
}

variable "gcp_region" {
  description = "GCP region for resources"
  type        = string
  default     = "us-central1"
}

variable "gcp_zone" {
  description = "GCP zone for resources"
  type        = string
  default     = "us-central1-a"
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "blockchain-core"
}

variable "environment" {
  description = "Environment (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "cost_center" {
  description = "Cost center for billing"
  type        = string
  default     = "blockchain-core"
}
