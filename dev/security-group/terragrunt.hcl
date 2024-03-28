include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "git@github.com:gozem-test/security-group.git"
}

dependency "vpc" {
  config_path = "../vpc"
}

dependency "public-subnets" {
  config_path = "../public-subnets"
}

dependency "private-subnets" {
  config_path = "../private-subnets"
}

inputs = {
  vpc_id = dependency.vpc.outputs.vpc_id
  name = "public-sg"
  description = "Open security group"
  ingress_rules = [
    {
      protocol    = "-1"
      from_port   = 0
      to_port     = 0
      cidr_blocks = ["0.0.0.0/0"]
    },
    // {
    //   protocol    = "tcp"
    //   from_port   = 22
    //   to_port     = 22
    //   cidr_blocks = ["0.0.0.0/0"]
    // },
    
    // {
    //   protocol    = "tcp"
    //   from_port   = 80
    //   to_port     = 80
    //   cidr_blocks = ["0.0.0.0/0"]
    // },
    
    // {
    //   protocol    = "tcp"
    //   from_port   = 443
    //   to_port     = 443
    //   cidr_blocks = ["0.0.0.0/0"]
    // },

    // {
    //   protocol    = "tcp"
    //   from_port   = 1024
    //   to_port     = 65535
    //   cidr_blocks = ["0.0.0.0/0"]
    // }
  ]
  egress_rules = [
    {
      protocol    = "-1"
      from_port   = 0
      to_port     = 0
      cidr_blocks = ["0.0.0.0/0"]
    }
  ]
  tags = {}
}
