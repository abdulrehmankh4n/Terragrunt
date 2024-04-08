include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "git@github.com:gozem-test/eks-addon.git"
}

dependency "cluster" {
  config_path = "../eks-cluster"
}

dependency "node-group" {
  config_path = "../eks-node-group"
}

inputs = {
  cluster_name = dependency.cluster.outputs.name
  addons = [
    {
      name = "vpc-cni"
      version = "v1.17.1-eksbuild.1"
    },
    {
      name = "coredns"
      version = "v1.11.1-eksbuild.6"
    },
    {
      name = "kube-proxy"
      version = "v1.29.1-eksbuild.2"
    },
    {
      name = "aws-ebs-csi-driver"
      version = "v1.29.1-eksbuild.1"
    },
    {
      name = "eks-pod-identity-agent"
      version = "v1.2.0-eksbuild.1"
    }
  ]
}
