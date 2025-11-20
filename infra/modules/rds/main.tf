# TODO: implement real RDS (single instance or cluster)
# This is just a placeholder.
resource "aws_db_instance" "this" {
  identifier        = "telemetry-db"
  allocated_storage = 20
  engine            = var.engine
  instance_class    = var.instance_class
  db_name           = var.db_name

  # TODO: subnet group, security groups, credentials

  skip_final_snapshot = true

  tags = var.common_tags
}
