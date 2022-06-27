variable "stream_name" {
  type = string
  default = "project-stream"
}

variable "shard_count" {
  type = number
  default = 1
}

variable "retention_period" {
  type = number
  default = 24
}

