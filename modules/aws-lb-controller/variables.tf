variable "cluster_name" {
  type        = string
  description = "Name of the EKS cluster"
}

variable "aws_lb_controller_role_arn" {
  type        = string
  description = "ARN of the IAM role for the AWS Load Balancer Controller"
}

variable "vpc_id" {
  type        = string
  description = "VPC ID where the EKS cluster is deployed"
}

variable "chart_version" {
  type        = string
  default     = "1.7.2"
  description = "Version of the AWS Load Balancer Controller Helm chart"
}

variable "wait_duration" {
  type        = string
  default     = "60s"
  description = "Duration to wait after AWS Load Balancer Controller is deployed"
}
