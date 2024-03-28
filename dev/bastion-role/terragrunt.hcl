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
  policy_statements = [
    {
      sid = "EKSDemoFullAccessPolicy"
      actions = [
        "eks:*"
      ],
      resources = ["arn:aws:eks:*:*:cluster/*"]
    },

    {
      sid = "AmazonSSMManagedInstanceCorePolicy",
      actions = [
        "ssm:DescribeAssociation",
        "ssm:GetDeployablePatchSnapshotForInstance",
        "ssm:GetDocument",
        "ssm:DescribeDocument",
        "ssm:GetManifest",
        "ssm:GetParameter",
        "ssm:GetParameters",
        "ssm:ListAssociations",
        "ssm:ListInstanceAssociations",
        "ssm:PutInventory",
        "ssm:PutComplianceItems",
        "ssm:PutConfigurePackageResult",
        "ssm:UpdateAssociationStatus",
        "ssm:UpdateInstanceAssociationStatus",
        "ssm:UpdateInstanceInformation",
        "ssmmessages:CreateControlChannel",
        "ssmmessages:CreateDataChannel",
        "ssmmessages:OpenControlChannel",
        "ssmmessages:OpenDataChannel",
        "ec2messages:AcknowledgeMessage",
        "ec2messages:DeleteMessage",
        "ec2messages:FailMessage",
        "ec2messages:GetEndpoint",
        "ec2messages:GetMessages",
        "ec2messages:SendReply"
      ],
      resources = ["*"]
    }
  ]
  role_name = "EKSDemoBastionRole"
}
