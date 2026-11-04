resource "aws_securityhub_account" "this" {
  count = var.enable_security_hub ? 1 : 0

  enable_default_standards  = false
  auto_enable_controls      = true
  control_finding_generator = "SECURITY_CONTROL"
}

resource "aws_securityhub_standards_subscription" "this" {
  for_each = var.enable_security_hub ? var.security_hub_standards : toset([])

  standards_arn = "arn:${local.partition}:securityhub:${local.region}::standards/${each.value}"

  depends_on = [aws_securityhub_account.this]
}
