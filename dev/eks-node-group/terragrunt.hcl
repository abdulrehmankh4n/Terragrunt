include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "git@github.com:gozem-test/eks-node-group.git"
}

dependency "cluster" {
  config_path = "../eks-cluster"
}

dependency "iam-role" {
  config_path = "../worker-node-role"
}

dependency "private-subnets" {
  config_path = "../private-subnets"
}

inputs = {
  cluster_name = dependency.cluster.outputs.name
  node_role_arn = dependency.iam-role.outputs.role_arn
  node_group_name = "eks-demo-node-group"
  scaling_config = {
    desired_size = 2
    max_size     = 4
    min_size     = 1
  }
  subnet_ids = [dependency.private-subnets.outputs.private_subnets[0], dependency.private-subnets.outputs.private_subnets[1]]
  update_config = {
    max_unavailable_percentage = 50
  }
  ami_type = "AL2_x86_64"
  capacity_type = "ON_DEMAND"
  disk_size = 20
  instance_types = ["t3.medium"]
}
