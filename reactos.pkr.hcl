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
  description = "Base name of ISO file used for installation."
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
  output_base      = "${var.destination_dir}/qemu"
  output_directory = "${local.output_base}/${local.dist_name}-${var.target}"
  config_file      = "${local.dist_name}/"
}

# -----------------------------------------------------------------------------
# Sources
# -----------------------------------------------------------------------------
source "qemu" "reactos_base" {
  accelerator      = "none"
  boot_wait        = "3s"
  cdrom_interface  = "ide"
  communicator     = "none"
  disk_cache       = "none"
  disk_interface   = "ide"
  disk_size        = "${var.disk_size}"
  format           = "qcow2"
  headless         = "${var.headless}"
  host_port_max    = 2229
  host_port_min    = 2222
  /* if not present throws error in v1.7.1
  http_directory   = "${var.http_dir}"
  */
  http_port_min    = 10082
  http_port_max    = 10089
  vnc_port_min     = 5901
  vnc_port_max     = 5999
  iso_checksum     = "${var.iso_checksum}"
  iso_urls         = ["iso/reactos/${var.iso_file}"]
  memory           = "${var.memory}"
  net_device       = "rtl8139"
  output_directory = "${local.output_directory}"
  shutdown_timeout = "20m"
  qemu_binary      = "qemu-system-x86_64"
  qemuargs         = [
    ["-m", "${var.memory}M"],
    ["-smp", "${var.cpu}"],
    # normally the the drives are added by packer itself but using ide for
    # both cd and disk does not work because the index for the disk is not
    # specified. The disk is declare before the cd with index=0 and an
    # error occurs.
    ["-drive", "file=${local.output_directory}/packer-reactos_base,if=ide,index=1,cache=none,discard=ignore,format=qcow2"],
    ["-drive", "file=iso/reactos/${var.iso_file},if=ide,index=0,id=cdrom,media=cdrom"],
  ]
}

source "qemu" "reactos_stage2" {
  accelerator      = "none"
  boot_wait        = "3s"
  cdrom_interface  = "ide"
  communicator     = "none"
  disk_cache       = "none"
  disk_size        = "${var.disk_size}"
  disk_image       = true
  format           = "qcow2"
  headless         = "${var.headless}"
  host_port_max    = 2229
  host_port_min    = 2222
  http_directory   = "${var.http_dir}"
  http_port_min    = 10082
  http_port_max    = 10089
  vnc_port_min     = 5901
  vnc_port_max     = 5999
  iso_checksum     = "none"
  iso_url          = "images/${local.dist_name}-${var.target}.qcow2"
  memory           = "${var.memory}"
  net_device       = "rtl8139"
  output_directory = "${local.output_directory}"
  shutdown_timeout = "20m"
  qemuargs         = [
    ["-m", "${var.memory}M"],
    ["-smp", "${var.cpu}"],
    # normally the the drives are added by packer itself but using ide for
    # both cd and disk does not work because the index for the disk is not
    # specified. The disk is declare before the cd with index=0 and an
    # error occurs.
    ["-drive", "file=${local.output_directory}/packer-reactos_stage2,if=ide,index=1,cache=none,discard=ignore,format=qcow2"],
    ["-drive", "file=iso/reactos/virtio-win.iso,if=ide,index=0,id=cdrom,media=cdrom"]
  ]
}

# -----------------------------------------------------------------------------
# Builds
# -----------------------------------------------------------------------------
build {
  name    = "reactos-rc"
  source "qemu.reactos_base" {
    name = "reactos-rc"
  }
  source "qemu.reactos_base" {
    name = "reactos-nightly"
  }
  /*
  source "qemu.reactos_base" {
    name = "reactos-release"
  }
  */
  source "qemu.reactos_stage2" {
    name = "reactos-nightly-stage2"
  }

  post-processor "shell-local" {
    script           = "scripts/rename-image.sh"
    environment_vars = [
      "DEBUG=true",
      "DEST_DIR=${local.output_base}",
      "DIST_NAME=${var.name}",
      "TARGET=${local.dist_name}-${var.target}"
    ]
  }
  /*
  post-processor "shell-local" {
    script           = "scripts/convert-diskimage.sh"
    environment_vars = [
      "FORMAT=gcp",
      "DEBUG=true",
      "DEST_DIR=${local.output_base}",
      "IMAGE_PATH=${local.output_base}/${local.dist_name}-${var.target}.qcow2",
      "DIST_NAME=${local.dist_name}",
      "TARGET=${var.target}"
    ]
  }
  */
}
