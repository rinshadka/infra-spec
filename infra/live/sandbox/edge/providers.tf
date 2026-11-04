provider "aws" {
  region              = var.aws_region
  allowed_account_ids = [var.aws_account_id]
}

# CloudFront certificates and CLOUDFRONT-scope WAF ACLs must be created in us-east-1.
provider "aws" {
  alias               = "us_east_1"
  region              = "us-east-1"
  allowed_account_ids = [var.aws_account_id]
}
