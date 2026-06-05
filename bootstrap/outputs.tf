# bootstrap/outputs.tf

output "state_bucket_name" {
  description = "S3 bucket name — copy this into your main project backend config"
  value       = aws_s3_bucket.state.bucket
}

output "state_bucket_arn" {
  description = "Full ARN of the state bucket — needed for IAM policies later"
  value       = aws_s3_bucket.state.arn
}

output "state_bucket_region" {
  description = "Region the state bucket lives in"
  value       = aws_s3_bucket.state.bucket_region
}

output "backend_config_snippet" {
  description = "Paste this into your main project providers.tf backend block"
  value       = <<-EOT
    terraform {
      backend "s3" {
        bucket       = "${aws_s3_bucket.state.bucket}"
        key          = "autoscale-infra/terraform.tfstate"
        region       = "${var.aws_region}"
        encrypt      = true
        use_lockfile = true
      }
    }
  EOT
}
