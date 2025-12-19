variable "namespace" {
  type    = string
  default = "argocd"
}

variable "chart_version" {
  type    = string
  default = "9.1.9"
}

variable "repo_url" {
  type = string
}

variable "aws_region" {
  type = string
}

variable "cluster_name" {
  type = string
}

variable "target_revision" {
  type    = string
  default = "main"
}

variable "rollouts_chart_version" {
  type    = string
  default = "2.40.5"
}

variable "subnet_ids" {
  type        = list(string)
  description = "List of subnet IDs for ALB (should be public subnets for internet-facing ALB)"
}
