output "db_host" {
  description = "RDS hostname for the PostgreSQL instance"
  value       = aws_db_instance.postgres.address
}

output "db_name" {
  description = "Database name"
  value       = aws_db_instance.postgres.db_name
}

output "db_port" {
  description = "Database port"
  value       = aws_db_instance.postgres.port
}
