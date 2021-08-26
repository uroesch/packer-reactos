# -----------------------------------------------------------------------------
# Sources
# -----------------------------------------------------------------------------
source "qemu" "reactos_base" {
  vm_name          = "${local.dist_name}-${var.target}"
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
  output_directory = "${local.output_directory}/qemu"
  shutdown_timeout = "60m"
  qemu_binary      = "qemu-system-x86_64"
  qemuargs         = [
    ["-m", "${var.memory}M"],
    ["-smp", "${var.cpu}"],
    # normally the the drives are added by packer itself but using ide for
    # both cd and disk does not work because the index for the disk is not
    # specified. The disk is declare before the cd with index=0 and an
    # error occurs.
    ["-drive", "file=${local.output_directory}/qemu/${local.dist_name}-${var.target},if=ide,index=1,cache=none,discard=ignore,format=qcow2"],
    ["-drive", "file=iso/reactos/${var.iso_file},if=ide,index=0,id=cdrom,media=cdrom"],
  ]
}

# -----------------------------------------------------------------------------
# Builds
# -----------------------------------------------------------------------------
build {
  # ---------------------------------------------------------------------------
  # QEMU
  # ---------------------------------------------------------------------------
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

  post-processor "shell-local" {
    only   = [
      "qemu.reactos-rc",
      "qemu.reactos-nightly",
      "qemu.reactos-release"
    ]
    inline = [
      "mv ${local.output_directory}/qemu/${local.dist_name}* images/${local.dist_name}-${var.target}.qcow2",
      "rm -rf ${local.output_directory}/qemu"
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
