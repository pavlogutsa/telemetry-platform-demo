variable "identifier" {
  type    = string
  default = "telemetry-db"
}

variable "db_name" {
  type = string
}

variable "instance_class" {
  type = string
}

variable "engine" {
  type = string
}

variable "engine_version" {
  type    = string
  default = "19.0.0.0.ru-2024-01.rur-2024-01.r1" # example for Oracle; change if using Postgres
}

variable "allocated_storage" {
  type    = number
  default = 20
}

variable "username" {
  type = string
}

variable "password" {
  type      = string
  sensitive = true
}

variable "vpc_id" {
  type = string
}

variable "vpc_cidr_block" {
  type = string
}

variable "subnet_ids" {
  type = list(string)
}

variable "common_tags" {
  type = map(string)
}
