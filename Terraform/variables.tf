variable "region" {
  type    = string
  default = "ap-southeast-1"
}

variable "create_vpc" {
  description = "Choose whether to create a new VPC."
  type        = bool
  default     = true
}

variable "vpc_id" {
  description = "If create_vpc is false, define your own vpc_id."
  type        = string
  default     = ""
}

variable "list_of_subnet_ids" {
  description = "If create_vpc is false, define your own subnet_ids."
  type        = list(string)
  default     = []
}

variable "create_kms_key" {
  description = "Controls if a KMS key for cluster encryption should be created."
  type        = bool
  default     = false
}

variable "use_eks_pod_identity_agent" {
  description = "Use IAM Roles for Service Account (IRSA) by default."
  type        = bool
  default     = false
}

variable "create_eks_worker_nodes_in_private_subnet" {
  type    = bool
  default = true
}