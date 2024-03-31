include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "git@github.com:gozem-test/nacl.git"
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
  _vpc_id = dependency.vpc.outputs.vpc_id
  nacls = [
    # Public NACL
    {
      name   = "eks-demo-public-nacl"
      vpc_id = dependency.vpc.outputs.vpc_id
      egress = [
        // {
        //   protocol   = "tcp"
        //   rule_no    = 100
        //   action     = "allow"
        //   cidr_block = "0.0.0.0/0"
        //   from_port  = 22
        //   to_port    = 22
        // },

        // {
        //   protocol   = "tcp"
        //   rule_no    = 200
        //   action     = "allow"
        //   cidr_block = "0.0.0.0/0"
        //   from_port  = 80
        //   to_port    = 80
        // },

        // {
        //   protocol   = "tcp"
        //   rule_no    = 300
        //   action     = "allow"
        //   cidr_block = "0.0.0.0/0"
        //   from_port  = 443
        //   to_port    = 443
        // },

        // {
        //   protocol   = "tcp"
        //   rule_no    = 400
        //   action     = "allow"
        //   cidr_block = "0.0.0.0/0"
        //   from_port  = 1024
        //   to_port    = 65535
        // },

        {
          protocol = "-1"
          rule_no  = 500
          action   = "allow"
          cidr_block = "0.0.0.0/0"
          from_port = 0
          to_port   = 0
        }
      ]
      ingress = [
        // {
        //   protocol   = "tcp"
        //   rule_no    = 100
        //   action     = "allow"
        //   cidr_block = "0.0.0.0/0"
        //   from_port  = 22
        //   to_port    = 22
        // },

        // {
        //   protocol   = "tcp"
        //   rule_no    = 200
        //   action     = "allow"
        //   cidr_block = "0.0.0.0/0"
        //   from_port  = 80
        //   to_port    = 80
        // },

        // {
        //   protocol   = "tcp"
        //   rule_no    = 300
        //   action     = "allow"
        //   cidr_block = "0.0.0.0/0"
        //   from_port  = 443
        //   to_port    = 443
        // },

        {
          protocol = "-1"
          rule_no  = 100
          action   = "allow"
          cidr_block = "0.0.0.0/0"
          from_port = 0
          to_port   = 0
        }
      ]
      subnet_id = dependency.public-subnets.outputs.public_subnets[0]
      tags      = {}
    },

    # App NACL A
    {
      name   = "eks-demo-nacl-a"
      vpc_id = dependency.vpc.outputs.vpc_id
      egress = [
        // {
        //   protocol   = "tcp"
        //   rule_no    = 100
        //   action     = "allow"
        //   cidr_block = "10.0.0.0/24"
        //   from_port  = 22
        //   to_port    = 22
        // },

        // {
        //   protocol   = "tcp"
        //   rule_no    = 200
        //   action     = "allow"
        //   cidr_block = "10.0.0.0/24"
        //   from_port  = 80
        //   to_port    = 80
        // },

        // {
        //   protocol   = "tcp"
        //   rule_no    = 300
        //   action     = "allow"
        //   cidr_block = "10.0.0.0/24"
        //   from_port  = 1024
        //   to_port    = 65535
        // },

        // {
        //   protocol   = "tcp"
        //   rule_no    = 400
        //   action     = "allow"
        //   cidr_block = "0.0.0.0/0"
        //   from_port  = 443
        //   to_port    = 443
        // }

        {
          protocol = "-1"
          rule_no  = 100
          action   = "allow"
          cidr_block = "0.0.0.0/0"
          from_port = 0
          to_port   = 0
        }
      ]
      ingress = [
        // {
        //   protocol   = "tcp"
        //   rule_no    = 100
        //   action     = "allow"
        //   cidr_block = "10.0.0.0/24"
        //   from_port  = 22
        //   to_port    = 22
        // },

        // {
        //   protocol   = "tcp"
        //   rule_no    = 200
        //   action     = "allow"
        //   cidr_block = "10.0.0.0/24"
        //   from_port  = 80
        //   to_port    = 80
        // },

        // {
        //   protocol   = "tcp"
        //   rule_no    = 300
        //   action     = "allow"
        //   cidr_block = "10.0.0.0/24"
        //   from_port  = 1024
        //   to_port    = 65535
        // },

        // {
        //   protocol   = "tcp"
        //   rule_no    = 400
        //   action     = "allow"
        //   cidr_block = "0.0.0.0/0"
        //   from_port  = 443
        //   to_port    = 443
        // }

        {
          protocol = "-1"
          rule_no  = 100
          action   = "allow"
          cidr_block = "0.0.0.0/0"
          from_port = 0
          to_port   = 0
        }
      ]
      subnet_id = dependency.private-subnets.outputs.private_subnets[0]
      tags      = {}
    },

    # App NACL B
    {
      name   = "eks-demo-nacl-b"
      vpc_id = dependency.vpc.outputs.vpc_id
      egress = [
        // {
        //   protocol   = "tcp"
        //   rule_no    = 100
        //   action     = "allow"
        //   cidr_block = "10.0.0.0/24"
        //   from_port  = 22
        //   to_port    = 22
        // },

        // {
        //   protocol   = "tcp"
        //   rule_no    = 200
        //   action     = "allow"
        //   cidr_block = "10.0.0.0/24"
        //   from_port  = 80
        //   to_port    = 80
        // },

        // {
        //   protocol   = "tcp"
        //   rule_no    = 300
        //   action     = "allow"
        //   cidr_block = "10.0.0.0/24"
        //   from_port  = 1024
        //   to_port    = 65535
        // },

        // {
        //   protocol   = "tcp"
        //   rule_no    = 400
        //   action     = "allow"
        //   cidr_block = "0.0.0.0/0"
        //   from_port  = 443
        //   to_port    = 443
        // }

        {
          protocol = "-1"
          rule_no  = 100
          action   = "allow"
          cidr_block = "0.0.0.0/0"
          from_port = 0
          to_port   = 0
        }
      ]
      ingress = [
        // {
        //   protocol   = "tcp"
        //   rule_no    = 100
        //   action     = "allow"
        //   cidr_block = "10.0.0.0/24"
        //   from_port  = 22
        //   to_port    = 22
        // },

        // {
        //   protocol   = "tcp"
        //   rule_no    = 200
        //   action     = "allow"
        //   cidr_block = "10.0.0.0/24"
        //   from_port  = 80
        //   to_port    = 80
        // },

        // {
        //   protocol   = "tcp"
        //   rule_no    = 300
        //   action     = "allow"
        //   cidr_block = "10.0.0.0/24"
        //   from_port  = 1024
        //   to_port    = 65535
        // },

        // {
        //   protocol   = "tcp"
        //   rule_no    = 400
        //   action     = "allow"
        //   cidr_block = "0.0.0.0/0"
        //   from_port  = 443
        //   to_port    = 443
        // }

        {
          protocol = "-1"
          rule_no  = 100
          action   = "allow"
          cidr_block = "0.0.0.0/0"
          from_port = 0
          to_port   = 0
        }
      ]
      subnet_id = dependency.private-subnets.outputs.private_subnets[1]
      tags      = {}
    },

    # RDS NACL A
    {
      name   = "eks-demo-rds-nacl-a"
      vpc_id = dependency.vpc.outputs.vpc_id
      egress = [
        {
          protocol = "tcp"
          rule_no  = 100
          action   = "allow"
          cidr_block = "10.0.100.0/24"
          from_port = 5432
          to_port   = 5432
        },

        {
          protocol = "tcp"
          rule_no  = 200
          action   = "allow"
          cidr_block = "10.0.200.0/24"
          from_port = 5432
          to_port   = 5432
        }
      ]
      ingress = [
        {
          protocol = "tcp"
          rule_no  = 100
          action   = "allow"
          cidr_block = "10.0.100.0/24"
          from_port = 5432
          to_port   = 5432
        },

        {
          protocol = "tcp"
          rule_no  = 200
          action   = "allow"
          cidr_block = "10.0.200.0/24"
          from_port = 5432
          to_port   = 5432
        }
      ]
      subnet_id = dependency.private-subnets.outputs.private_subnets[2]
      tags      = {}
    },

    # App NACL B
    {
      name   = "eks-demo-rds-nacl-b"
      vpc_id = dependency.vpc.outputs.vpc_id
      egress = [
        {
          protocol = "tcp"
          rule_no  = 100
          action   = "allow"
          cidr_block = "10.0.100.0/24"
          from_port = 5432
          to_port   = 5432
        },

        {
          protocol = "tcp"
          rule_no  = 200
          action   = "allow"
          cidr_block = "10.0.200.0/24"
          from_port = 5432
          to_port   = 5432
        }
      ]
      ingress = [
        {
          protocol = "tcp"
          rule_no  = 100
          action   = "allow"
          cidr_block = "10.0.100.0/24"
          from_port = 5432
          to_port   = 5432
        },

        {
          protocol = "tcp"
          rule_no  = 200
          action   = "allow"
          cidr_block = "10.0.200.0/24"
          from_port = 5432
          to_port   = 5432
        }
      ]
      subnet_id = dependency.private-subnets.outputs.private_subnets[3]
      tags      = {}
    }
  ]
}
