# bootstrap/main.tf

# ─────────────────────────────────────────
# TERRAFORM + PROVIDER CONFIGURATION
# ─────────────────────────────────────────

terraform {
  required_version = ">= 1.11.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  # No backend block here — bootstrap state stays local intentionally.
  # DO NOT add a backend "s3" block to this file.
}

provider "aws" {
  region = var.aws_region
}

# ─────────────────────────────────────────
# DATA SOURCES
# ─────────────────────────────────────────


data "aws_caller_identity" "current" {}

# ─────────────────────────────────────────
# LOCALS
# ─────────────────────────────────────────

locals {
  # Result: "autoscale-infra-tfstate-859493431963"
  bucket_name = "${var.project_name}-tfstate-${data.aws_caller_identity.current.account_id}"

  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
    Purpose     = "terraform-state-storage"
  }
}

# ─────────────────────────────────────────
# S3 BUCKET
# ─────────────────────────────────────────

resource "aws_s3_bucket" "state" {
  bucket = local.bucket_name
  tags   = local.common_tags

  # Protects against accidental terraform destroy on the state bucket.
  # Terraform will error and stop rather than delete this resource.
  lifecycle {
    prevent_destroy = true
  }
}

# ─────────────────────────────────────────
# BLOCK PUBLIC ACCESS
# ─────────────────────────────────────────

# ON by default since April 2023 — we set it explicitly so intent
# is visible in code and protected against console drift.
resource "aws_s3_bucket_public_access_block" "state" {
  bucket = aws_s3_bucket.state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ─────────────────────────────────────────
# OWNERSHIP CONTROLS
# ─────────────────────────────────────────

# BucketOwnerEnforced = ACLs completely disabled.
# Access controlled by bucket policies and IAM only.
resource "aws_s3_bucket_ownership_controls" "state" {
  bucket = aws_s3_bucket.state.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }

  depends_on = [aws_s3_bucket_public_access_block.state]
}

# ─────────────────────────────────────────
# VERSIONING
# ─────────────────────────────────────────

# Required for use_lockfile and state recovery.
# If an apply crashes mid-run, versioning lets you restore
# the last good state file. Not optional for a state bucket.
resource "aws_s3_bucket_versioning" "state" {
  bucket = aws_s3_bucket.state.id

  versioning_configuration {
    status = "Enabled"
  }

  depends_on = [aws_s3_bucket_ownership_controls.state]
}

# ─────────────────────────────────────────
# ENCRYPTION
# ─────────────────────────────────────────

# AES256 = SSE-S3. AWS manages the keys. No cost.
# State files can contain sensitive values — always encrypt at rest.
resource "aws_s3_bucket_server_side_encryption_configuration" "state" {
  bucket = aws_s3_bucket.state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }

  depends_on = [aws_s3_bucket_ownership_controls.state]
}
