include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "git@github.com:gozem-test/eks-cluster.git"
}

dependency "private-subnets" {
  config_path = "../private-subnets"
}

dependency "iam-role" {
  config_path = "../eks-cluster-role"
}

inputs = {
  name = "eks-demo"
  subnet_ids = [dependency.private-subnets.outputs.private_subnets[0], dependency.private-subnets.outputs.private_subnets[1]]
  cluster_role_arn = dependency.iam-role.outputs.role_arn
  enabled_cluster_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
}
