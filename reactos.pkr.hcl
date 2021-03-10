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
variable "ros_user" {
  type        = string
  description = "Name of default ReactOS user."
}
variable "ros_organization" {
  type        = string
  description = "Name of organization the VM is associated with."
}
variable "ros_admin_password" {
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
source "qemu" "reactos" {
  accelerator      = "none"
  /*
  boot_command     = [
    "<wait10>",                                # wait for setup screen
    "<enter><wait3>",                          # language selection -> United States
    "<enter><wait3>",                          # welcome -> install or upgrade
    "<enter><wait3>",                          # version status -> continue
    "<enter><wait3>",                          # device settings -> accept device settings
    "<enter><wait3>",                          # disk settings -> use unpartitioned space
    "<enter><wait3>",                          # format partition -> FAT (quick format)
    "<enter><wait3>",                          # format partition -> confirmation
    "<enter><wait3>",                          # reactos install directory
    "<wait120>",                               # installation process
    "<enter><wait3>",                          # install boot loader
    "<wait15>",                                # reboot countdown
    "<wait15>",                                # boot menu countdown
    "<wait120>",                               # wait for graphical dialogs after boot
    "<enter><wait3>",                          # welcome setup wizard -> next
    "<enter><wait3>",                          # acknowledgements -> next
    "<down><wait><enter><wait3>",              # product options -> ReactOS Server (default) -> next
    "<enter><wait3>",                          # regional settings -> next
    "${var.ros_user}<tab><wait>",              # personalize your software -> Name
    "${var.ros_organization}<enter><wait>",    # personalize your software -> Organization -> next
    "<tab>",                                   # computer name & admin pw -> skip name -> tab
    "${var.ros_admin_password}<tab>",          # computer name & admin pw -> admin pw -> tab
    "${var.ros_admin_password}<enter><wait3>", # computer name & admin pw -> admin pw confirm -> next
    "<enter><wait3>",                          # date and time -> next
    "<enter><wait3>",                          # appearance -> next
    "<enter><wait3>",                          # network settings -> typical -> next
    "<enter><wait3>",                          # workgrou and network domain -> default -> next
    "<wait15>",                                # installation process
    "<tab><enter>",                            # wine gecko installer -> cancel
    "<wait3><enter>",                          # reboot -> finish
    "<wait10>",                                # boot menu countdown
    "<wait120>",                               # startup wait time
    "<tab><enter><wait3>",                     # driver installation -> install
    "<spacebar><enter><wait3>",                # do not ask again -> cancel
    "<leftAltOn><f4><leftAltOff><wait3>",      # menu flyout
    "<leftAltOn>s<leftAltOff><wait3>",         # On nightly -> select the shutdown button
    "<enter><wait3>"                           # On rc -> ok shutdown dialog
  ]
  */
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
  http_directory   = "${var.http_dir}"
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
  qemuargs         = [
    ["-m", "${var.memory}M"],
    ["-smp", "${var.cpu}"],
    # normally the the drives are added by packer itself but using ide for
    # both cd and disk does not work because the index for the disk is not
    # specified. The disk is declare before the cd with index=0 and an
    # error occurs.
    ["-drive", "file=${local.output_directory}/packer-${var.name},if=ide,index=1,cache=none,discard=ignore,format=qcow2"],
    ["-drive", "file=iso/reactos/${var.iso_file},if=ide,index=0,id=cdrom,media=cdrom"]
  ]
}

# -----------------------------------------------------------------------------
# Builds
# -----------------------------------------------------------------------------
build {
  name    = "reactos-rc"
  source "source.qemu.reactos" {
    name = "reactos-rc"
  }
  source "source.qemu.reactos" {
    name = "reactos-nightly"
  }
  /*
  source "source.qemu.reactos" {
    name = "reactos-release"
  }
  */
  post-processor "shell-local" {
    script           = "scripts/rename-image.sh"
    environment_vars = [
      "DEBUG=true",
      "DEST_DIR=${local.output_base}",
      "DIST_NAME=${var.name}",
      "TARGET=${local.dist_name}-${var.target}"
    ]
  }
}
