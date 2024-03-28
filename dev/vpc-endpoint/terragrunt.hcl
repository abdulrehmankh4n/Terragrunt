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
      service_name = "com.amazonaws.us-east-1.ssm"
      vpc_endpoint_type = "Interface"
      security_group_ids = [dependency.security-group.outputs.security_group_id]
      private_dns_enabled = true
    },

    {
      service_name = "com.amazonaws.us-east-1.ec2messages"
      vpc_endpoint_type = "Interface"
      security_group_ids = [dependency.security-group.outputs.security_group_id]
      private_dns_enabled = true
    },

    {
      service_name = "com.amazonaws.us-east-1.ssmmessages"
      vpc_endpoint_type = "Interface"
      security_group_ids = [dependency.security-group.outputs.security_group_id]
      private_dns_enabled = true
    }
  ]
}
