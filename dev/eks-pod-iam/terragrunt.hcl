include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "git@github.com:gozem-test/iam-oidc.git"
}

dependency "cluster" {
  config_path = "../eks-cluster"
}

inputs = {
  role_name = "EKSDemoPodIAMAuth"
  oidc_issuer = dependency.cluster.outputs.oidc_tls_issuer
  client_id_list = ["sts.amazonaws.com"]
}
