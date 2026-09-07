output "state_machine_arn" {
  description = "ARN of the Step Functions orchestration state machine"
  value       = aws_sfn_state_machine.orchestration.arn
}

output "state_machine_name" {
  description = "Name of the Step Functions orchestration state machine"
  value       = aws_sfn_state_machine.orchestration.name
}
