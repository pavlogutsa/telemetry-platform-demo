# TODO: replace with terraform-aws-modules/vpc/aws or your own implementation
resource "aws_vpc" "this" {
  cidr_block           = var.cidr_block
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(
    var.common_tags,
    { Name = var.name }
  )
}

# TODO: add subnets, igw, nat, routes
