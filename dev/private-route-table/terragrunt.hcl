include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "git@github.com:gozem-test/route-table.git"
}

dependency "vpc" {
  config_path = "../vpc"
}

dependency "nat-gw" {
  config_path = "../nat-gateway"
}

inputs = {
  route_tables = [
    {
      name      = "eks-demo-private-rt"
      vpc_id    = dependency.vpc.outputs.vpc_id
      is_igw_rt = false

      routes = [
        {
          cidr_block = "0.0.0.0/0"
          igw_id     = dependency.nat-gw.outputs.nat_gw_id
        }
      ]

      tags = {}
    }
  ]
}
