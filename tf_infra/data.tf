# Detect AZs available in var.primary_aws_region
data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_route53_zone" "this" {
  zone_id = var.r53_zone_id
}
