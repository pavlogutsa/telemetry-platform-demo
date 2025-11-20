output "db_endpoint" {
  value = aws_db_instance.this.address
}

output "db_port" {
  value = aws_db_instance.this.port
}

output "jdbc_url" {
  value = "jdbc:${aws_db_instance.this.engine}://${aws_db_instance.this.address}:${aws_db_instance.this.port}/${aws_db_instance.this.db_name}"
}

# TODO: output db_user, db_pass if you manage them here
