include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "git@github.com:gozem-test/vpc-endpoint.git"
}

dependency "vpc" {
  config_path = "../vpc"
}

dependency "security-group" {
  config_path = "../security-group"
}

inputs = {
  vpc_id = dependency.vpc.outputs.vpc_id
  endpoints = [
    {
      service_name = "com.amazonaws.region.ssm"
      vpc_endpoint_type = "Interface"
      security_group_ids = [dependency.security-group.outputs.security_group_id]
      private_dns_enabled = false
    },

    {
      service_name = "com.amazonaws.region.ec2messages"
      vpc_endpoint_type = "Interface"
      security_group_ids = [dependency.security-group.outputs.security_group_id]
      private_dns_enabled = false
    },

    {
      service_name = "com.amazonaws.region.ec2"
      vpc_endpoint_type = "Interface"
      security_group_ids = [dependency.security-group.outputs.security_group_id]
      private_dns_enabled = false
    },

    {
      service_name = "com.amazonaws.region.ssmmessages"
      vpc_endpoint_type = "Interface"
      security_group_ids = [dependency.security-group.outputs.security_group_id]
      private_dns_enabled = false
    }
  ]
}
