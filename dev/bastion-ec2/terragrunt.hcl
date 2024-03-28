include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "git@github.com:gozem-test/ec2.git"
}

dependency "public-subnets" {
  config_path = "../public-subnets"
}

dependency "instance-profile" {
  config_path = "../bastion-instance-profile"
}

dependency "security-group" {
  config_path = "../security-group"
}

inputs = {
  instance_name = "eks-bastion-host"
  use_instance_profile = true
  iam_instance_profile = dependency.instance-profile.outputs.name
  instance_type = "t3.micro"
  subnet_id = dependency.public-subnets.outputs.public_subnets[0]
  existing_security_group_ids = [dependency.security-group.outputs.security_group_id]
  assign_public_ip = true
  use_ssh = false
  keypair_name = ""
  use_userdata = true
  userdata_script_path = "user-data.sh"
  user_data_replace_on_change = false
  extra_tags = {}
}
