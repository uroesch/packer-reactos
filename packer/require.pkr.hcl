packer {
  required_plugins {
    qemu = {
      version = "~> 1"
      source  = "github.com/hashicorp/qemu"
    }
    virtualbox = {
       version = "~> 1"
       source  = "github.com/hashicorp/virtualbox"
    }
  }
}
