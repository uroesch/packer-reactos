# -----------------------------------------------------------------------------
# Variables
# -----------------------------------------------------------------------------
variable "name" {
  type        = string
  description = "Operation system name e.g. reactos"
}
variable "version" {
  type        = string
  description = "Version to build e.g. 0.4.15."
}
variable "arch" {
  type        = string
  default     = "x86"
  description = "Architecture to build either x86 or x64."
  validation {
    condition     = can(regex("^x(86|64)", var.arch))
    error_message = "Arch must be either, 'x86' [default] or 'x64'."
  }
}
variable "target" {
  type        = string
  default     = "workstation"
  description = "What to build e.g. rc, nightly or release."
}
variable "cpu" {
  type        = number
  default     = "1"
  description = "How many CPUs to allocate for the build virtual machine."
}
variable "memory" {
  type        = number
  default     = "1024"
  description = "How much memory to allocate for the build virtual machine."
}
variable "destination_dir" {
  type        = string
  default     = "artifacts"
  description = "Work directory for disk images"
}
variable "disk_size" {
  type        = number
  default     = "4000"
  description = "Disk size to allocate to for the build."
}
variable "headless" {
  type        = bool
  default     = "false"
  description = "Display QEMU window during build."
}
variable "http_dir" {
  type        = string
  default     = "http"
  description = "Packer http server's document root."
}
variable "iso_checksum" {
  type        = string
  description = "Checksum of ISO file used for installation."
}
variable "iso_file" {
  type        = string
  description = "Path to the ISO file used for installation."
}
variable "ros_fstype" {
  type        = string
  description = "filsystem to use; currently either 'FAT' or 'BtrFS'."
}
variable "ros_productoption" {
  type        = string
  description = "Installation type; currently either 'server' or 'workstation'."
}
variable "ros_fullname" {
  type        = string
  description = "Name of default ReactOS user."
}
variable "ros_orgname" {
  type        = string
  description = "Name of organization the VM is associated with."
}
variable "ros_computername" {
  type        = string
  description = "Name of the computer aka. hostname."
}
variable "ros_adminpassword" {
  type        = string
  description = "Administrator's password."
}

# -----------------------------------------------------------------------------
# Locals
# -----------------------------------------------------------------------------
locals {
  dist_name        = "${var.name}-${var.version}"
  output_base      = "${var.destination_dir}"
  output_directory = "${local.output_base}/${local.dist_name}-${var.arch}"
  config_file      = "${local.dist_name}/"
}
