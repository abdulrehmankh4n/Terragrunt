include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "git@github.com:gozem-test/iam-role.git"
}

inputs = {
  principals = [
    {
      type = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  ]
  policy_name = "EKSDemoWorkerNodePolicy"
  policy_attachments = [
    {
      arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
    },
    {
      arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
    },
    {
      arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
    },
    {
      arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
    }
  ]
  policy_statements = []
  role_name = "EKSDemoWorkerNodeRole"
}
