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
  policy_name = "EKSDemoBastionPolicy"
  policy_attachments = [
    {
      arn = "arn:aws:iam::534876755051:policy/AmazonEKSFullAccessPolicy"
    },
    {
      arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
    }
  ]
  policy_statements = []
  role_name = "EKSDemoBastionRole"
}
