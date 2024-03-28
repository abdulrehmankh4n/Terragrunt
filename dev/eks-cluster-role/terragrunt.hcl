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
      identifiers = ["eks.amazonaws.com"]
    }
  ]
  policy_name = "EKSDemoClusterRolePolicy"
  policy_attachments = [
    {
      arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
    }
  ]
  policy_statements = []
  role_name = "EKSDemoClusterRole"
}
