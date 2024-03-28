include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "git@github.com:gozem-test/eip.git"
}

dependency "vpc" {
  config_path = "../vpc"
}

inputs = {}
