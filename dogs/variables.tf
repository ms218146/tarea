
variable "aws_region" {
  type        = string
  description = "AWS Region"
}

variable "app_name" {
  type        = string
  description = "Application Name"
}

variable "ip_red" {
  description = "Las ip a usar en la VPC."
  default     = "10.0.0.0/16"
}

variable "subnet_publica" {
  description = "Lista de subnets publicas"
}

variable "subnet_privada" {
  description = "Lista de subnets privadas"
}

variable "availability_zones" {
  description = "Lista de Zonzas de Disponibilidad"
}
