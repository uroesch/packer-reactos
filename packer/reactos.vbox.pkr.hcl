# -----------------------------------------------------------------------------
# Sources
# -----------------------------------------------------------------------------
source "virtualbox-iso" "reactos_base" {
  vm_name                 = "${local.dist_name}-${var.target}"
  format                  = "ova"
  boot_wait               = "3s"
  disk_size               = "${var.disk_size}"
  headless                = "${var.headless}"
  communicator            = "none"
  host_port_max           = 2229
  host_port_min           = 2222
  /* if not present throws error in v1.7.1
  http_directory          = "${var.http_dir}"
  */
  http_port_min           = 10082
  http_port_max           = 10089
  iso_checksum            = "${var.iso_checksum}"
  iso_urls                = ["iso/reactos/${var.iso_file}"]
  memory                  = "${var.memory}"
  output_directory        = "${local.output_directory}/vbox"
  shutdown_timeout        = "60m"
  disable_shutdown        = true
  guest_additions_mode    = "disable"
  virtualbox_version_file = ""
}
# -----------------------------------------------------------------------------
# Builds
# -----------------------------------------------------------------------------
build {
  # ---------------------------------------------------------------------------
  # VirtualBox 
  # ---------------------------------------------------------------------------
  source "virtualbox-iso.reactos_base" {
    name = "reactos-nightly"
  }

  source "virtualbox-iso.reactos_base" {
    name = "reactos-rc"
  }

  source "virtualbox-iso.reactos_base" {
    name = "reactos-release"
  }

  post-processor "shell-local" {
    only   = [
      "virtualbox-iso.reactos-rc", 
      "virtualbox-iso.reactos-nightly",
      "virtualbox-iso.reactos-release"
    ]
    inline = [
      "mv ${local.output_directory}/vbox/${local.dist_name}*ova images/", 
      "rm -rf ${local.output_directory}/vbox" 
    ]
  }
}
