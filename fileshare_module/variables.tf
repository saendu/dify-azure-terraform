variable "storage_account_id" {
  description = "The resource ID of the storage account"
  type        = string
}

variable "local_mount_dir" {
  description = "Local mount directory path"
  type        = string
}

variable "share_name" {
  description = "The name of the file share"
  type        = string
}

variable "quota" {
  description = "The quota of the file share in GB"
  type        = number
  default     = 50
}
