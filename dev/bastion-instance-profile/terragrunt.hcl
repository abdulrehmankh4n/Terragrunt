include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "git@github.com:gozem-test/instance-profile.git"
}

dependency "iam-role" {
  config_path = "../bastion-role"
}

inputs = {
  instance_profile_name = "EKSBastionInstanceProfile"
  path = "/"
  iam_role_name = dependency.iam-role.outputs.role_name
  instance_profile_tags = {}
}
