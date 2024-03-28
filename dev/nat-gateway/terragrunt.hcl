include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "git@github.com:gozem-test/nat-gateway.git"
}

dependency "internet-gateway" {
  config_path = "../internet-gateway"
}

dependency "eip" {
  config_path = "../nat-gw-eip"
}

dependency "public-subnets" {
  config_path = "../public-subnets"
}

inputs = {
  eip_id = dependency.eip.outputs.eip_id
  subnet_id = dependency.public-subnets.outputs.public_subnets[0]
  name = "eks-demo-nat-gw"
  tags = {}
}
