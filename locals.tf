# locals.tf
#
# Locals are computed values derived from variables.
# Define them once here, reference them everywhere.
# This is what keeps naming consistent across 50+ resources.

locals {

  name_prefix = "${var.project_name}-${var.environment}"

  common_tags = {
    Environment = var.environment
    Name        = local.name_prefix
  }
}
