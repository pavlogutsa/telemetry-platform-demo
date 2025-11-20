variable "chart_path" {
  type = string
}

variable "namespace" {
  type    = string
  default = "telemetry"
}

variable "oracle_user" {
  type = string
}

variable "oracle_password" {
  type = string
}

variable "oracle_jdbc_url" {
  type = string
}

variable "agent_ingest_image" {
  type = string
}

variable "agent_ingest_replicas" {
  type    = number
  default = 2
}

variable "device_state_image" {
  type = string
}

variable "device_state_replicas" {
  type    = number
  default = 1
}

variable "device_state_container_port" {
  type    = number
  default = 8081
}

variable "device_state_service_port" {
  type    = number
  default = 8080
}

variable "ingress_host" {
  type    = string
  default = "telemetry.internal"
}
