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
  policy_statements = [
    // {
    //   sid = "EC2ContainerRegistryReadOnly"
    //   actions = [
    //     "ecr:GetAuthorizationToken",
    //     "ecr:BatchCheckLayerAvailability",
    //     "ecr:GetDownloadUrlForLayer",
    //     "ecr:GetRepositoryPolicy",
    //     "ecr:DescribeRepositories",
    //     "ecr:ListImages",
    //     "ecr:DescribeImages",
    //     "ecr:BatchGetImage",
    //     "ecr:GetLifecyclePolicy",
    //     "ecr:GetLifecyclePolicyPreview",
    //     "ecr:ListTagsForResource",
    //     "ecr:DescribeImageScanFindings"
    //   ],
    //   resources = ["*"]
    // },

    // {
    //   sid = "AmazonEKSCNIPolicy"
    //   actions = [
    //     "ec2:AssignPrivateIpAddresses",
    //     "ec2:AttachNetworkInterface",
    //     "ec2:CreateNetworkInterface",
    //     "ec2:DeleteNetworkInterface",
    //     "ec2:DescribeInstances",
    //     "ec2:DescribeTags",
    //     "ec2:DescribeNetworkInterfaces",
    //     "ec2:DescribeInstanceTypes",
    //     "ec2:DescribeSubnets",
    //     "ec2:DetachNetworkInterface",
    //     "ec2:ModifyNetworkInterfaceAttribute",
    //     "ec2:UnassignPrivateIpAddresses",
    //   ],
    //   resources = ["*"]
    // },

    // {
    //   sid = "AmazonEKSCNIPolicyENITag",
    //   actions = [
    //     "ec2:CreateTags"
    //   ],
    //   resources = ["arn:aws:ec2:*:*:network-interface/*"]
    // },

    // {
    //   sid = "WorkerNodePermissions"
    //   actions = [
    //     "ec2:DescribeInstances",
    //     "ec2:DescribeInstanceTypes",
    //     "ec2:DescribeRouteTables",
    //     "ec2:DescribeSecurityGroups",
    //     "ec2:DescribeSubnets",
    //     "ec2:DescribeVolumes",
    //     "ec2:DescribeVolumesModifications",
    //     "ec2:DescribeVpcs",
    //     "eks:DescribeCluster",
    //     "eks-auth:AssumeRoleForPodIdentity"
    //   ],
    //   resources = ["*"]
    // },

    // {
    //   sid = "AmazonSSMManagedInstanceCorePolicy",
    //   actions = [
    //     "ssm:DescribeAssociation",
    //     "ssm:GetDeployablePatchSnapshotForInstance",
    //     "ssm:GetDocument",
    //     "ssm:DescribeDocument",
    //     "ssm:GetManifest",
    //     "ssm:GetParameter",
    //     "ssm:GetParameters",
    //     "ssm:ListAssociations",
    //     "ssm:ListInstanceAssociations",
    //     "ssm:PutInventory",
    //     "ssm:PutComplianceItems",
    //     "ssm:PutConfigurePackageResult",
    //     "ssm:UpdateAssociationStatus",
    //     "ssm:UpdateInstanceAssociationStatus",
    //     "ssm:UpdateInstanceInformation",
    //     "ssmmessages:CreateControlChannel",
    //     "ssmmessages:CreateDataChannel",
    //     "ssmmessages:OpenControlChannel",
    //     "ssmmessages:OpenDataChannel",
    //     "ec2messages:AcknowledgeMessage",
    //     "ec2messages:DeleteMessage",
    //     "ec2messages:FailMessage",
    //     "ec2messages:GetEndpoint",
    //     "ec2messages:GetMessages",
    //     "ec2messages:SendReply"
    //   ],
    //   resources = ["*"]
    // }
  ]
  role_name = "EKSDemoWorkerNodeRole"
}
