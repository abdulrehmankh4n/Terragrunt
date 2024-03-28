include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "git@github.com:gozem-test/subnet.git"
}

dependency "vpc" {
  config_path = "../vpc"
}

dependency "public-route-table" {
  config_path = "../public-route-table"
}

inputs = {
  subnets = [
    {
      name                                = "eks-demo-public-subnet"
      vpc_id                              = dependency.vpc.outputs.vpc_id
      cidr_block                          = "10.0.0.0/24"
      availability_zone                   = "us-east-1a"
      map_public_ip_on_launch             = true
      private_dns_hostname_type_on_launch = "resource-name"
      is_public                           = true
      route_table_id                      = dependency.public-route-table.outputs.route_table_ids[0]
      tags                                = {}
    }
  ]
}
