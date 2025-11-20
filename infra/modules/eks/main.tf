# TODO: replace with terraform-aws-modules/eks/aws or your own implementation
resource "aws_eks_cluster" "this" {
  name     = var.cluster_name
  role_arn = "arn:aws:iam::123456789012:role/TODO-eks-role" # TODO

  vpc_config {
    subnet_ids = var.subnet_ids
  }

  tags = var.common_tags
}
