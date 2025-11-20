resource "aws_ecr_repository" "this" {
  for_each = toset(var.repositories)

  name = each.value

  tags = var.common_tags
}
