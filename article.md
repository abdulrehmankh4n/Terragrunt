As cloud-native architectures continue to gain momentum, Kubernetes has emerged as the de facto standard for container orchestration. Amazon Elastic Kubernetes Service (EKS) is a popular managed Kubernetes service that simplifies the deployment and management of containerized applications on AWS. To streamline the process of provisioning an EKS cluster and automate infrastructure management, developers and DevOps teams often turn to tools like Terraform, Terragrunt, and GitHub Actions.

In this article, we will explore the seamless integration of these tools to provision an EKS cluster on AWS, delving into the benefits of using them in combination, the key concepts involved, and the step-by-step process to set up an EKS cluster using infrastructure-as-code principles.

Whether you are a developer, a DevOps engineer, or an infrastructure enthusiast, this article will serve as a comprehensive guide to help you leverage the power of Terraform, Terragrunt, and GitHub Actions in provisioning and managing your EKS clusters efficiently.
Before diving in though, there are a few things to note.

**Disclaimer**
a) Given that we'll use Terraform and Terragrunt to provision our infrastructure, familiarity with these two is required to be able to follow along.
b) Given that we'll use GitHub Actions to automate the provisioning of our infrastructure, familiarity with the tool is required to be able to follow along as well.
c) Some basic understanding of Docker and container orchestration with Kubernetes will also help to follow along.

These are the steps we'll follow to provision our EKS cluster:

1. Write Terraform code for building blocks.

2. Write Terragrunt code to provision infrastructure.

3. Create a GitHub Actions workflow and delegate the infrastructure provisioning task to it.

4. Add a GitHub Actions workflow job to destroy our infrastructure when we're done.

Below is a diagram of the VPC and its components that we'll create, bearing in mind that the control plane components will be deployed in an EKS-managed VPC:

![EKS cluster worker node VPC](https://dev-to-uploads.s3.amazonaws.com/uploads/articles/ih92t2r2xyfte0bhkd04.png)

**1. Write Terraform code for building blocks**

Each building block will have the following files:

```
main.tf
outputs.tf
provider.tf
variables.tf
```

We'll be using version 4.x of the AWS provider for Terraform, so the **provider.tf** file will be the same in all building blocks:

**provider.tf**

```
terraform {
  required_version = ">= 1.4.2"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  access_key = var.AWS_ACCESS_KEY_ID
  secret_key = var.AWS_SECRET_ACCESS_KEY
  region     = var.AWS_REGION
  token      = var.AWS_SESSION_TOKEN
}
```

We can see a few variables here that will also be used by all building blocks in the **variables.tf** file:

**variables.tf**

```
variable "AWS_ACCESS_KEY_ID" {
  type = string
}

variable "AWS_SECRET_ACCESS_KEY" {
  type = string
}

variable "AWS_SESSION_TOKEN" {
  type    = string
  default = null
}

variable "AWS_REGION" {
  type = string
}
```

So when defining the building blocks in the following, these variables won't be explicitly defined, but you should have them in your **variables.tf** file.

_**a) VPC building block**_

**main.tf**

```
resource "aws_vpc" "vpc" {
  cidr_block                       = var.vpc_cidr
  instance_tenancy                 = var.instance_tenancy
  enable_dns_support               = var.enable_dns_support
  enable_dns_hostnames             = var.enable_dns_hostnames
  assign_generated_ipv6_cidr_block = var.assign_generated_ipv6_cidr_block

  tags = merge(var.vpc_tags, {
    Name = var.vpc_name
  })
}
```

**variables.tf**

```
variable "vpc_cidr" {
  type = string
}

variable "vpc_name" {
  type = string
}

variable "instance_tenancy" {
  type    = string
  default = "default"
}

variable "enable_dns_support" {
  type    = bool
  default = true
}

variable "enable_dns_hostnames" {
  type = bool
}

variable "assign_generated_ipv6_cidr_block" {
  type    = bool
  default = false
}

variable "vpc_tags" {
  type = map(string)
}
```

**outputs.tf**

```
output "vpc_id" {
  value = aws_vpc.vpc.id
}
```

_**b) Internet Gateway building block**_

**main.tf**

```
resource "aws_internet_gateway" "igw" {
  vpc_id = var.vpc_id

  tags = merge(var.tags, {
    Name = var.name
  })
}
```

**variables.tf**

```
variable "vpc_id" {
  type = string
}

variable "name" {
  type = string
}

variable "tags" {
  type = map(string)
}
```

**outputs.tf**

```
output "igw_id" {
  value = aws_internet_gateway.igw.id
}
```

_**c) Route Table building block**_

**main.tf**

```
resource "aws_route_table" "route_tables" {
  for_each = { for rt in var.route_tables : rt.name => rt }

  vpc_id = each.value.vpc_id

  dynamic "route" {
    for_each = { for route in each.value.routes : route.cidr_block => route if each.value.is_igw_rt }

    content {
      cidr_block = route.value.cidr_block
      gateway_id = route.value.igw_id
    }
  }

  dynamic "route" {
    for_each = { for route in each.value.routes : route.cidr_block => route if !each.value.is_igw_rt }

    content {
      cidr_block     = route.value.cidr_block
      nat_gateway_id = route.value.nat_gw_id
    }
  }

  tags = merge(each.value.tags, {
    Name         = each.value.name
  })
}
```

**variables.tf**

```
variable "route_tables" {
  type = list(object({
    name      = string
    vpc_id    = string
    is_igw_rt = bool

    routes = list(object({
      cidr_block = string
      igw_id     = optional(string)
      nat_gw_id  = optional(string)
    }))

    tags = map(string)
  }))
}
```

**outputs.tf**

```
output "route_table_ids" {
  value = values(aws_route_table.route_tables)[*].id
}
```

_**d) Subnet building block**_

**main.tf**

```
# Create public subnets
resource "aws_subnet" "public_subnets" {
  for_each = { for subnet in var.subnets : subnet.name => subnet if subnet.is_public }

  vpc_id                              = each.value.vpc_id
  cidr_block                          = each.value.cidr_block
  availability_zone                   = each.value.availability_zone
  map_public_ip_on_launch             = each.value.map_public_ip_on_launch
  private_dns_hostname_type_on_launch = each.value.private_dns_hostname_type_on_launch

  tags = merge(each.value.tags, {
    Name = each.value.name
  })
}

# Associate public subnets with their route table
resource "aws_route_table_association" "public_subnets" {
  for_each = { for subnet in var.subnets : subnet.name => subnet if subnet.is_public }

  subnet_id      = aws_subnet.public_subnets[each.value.name].id
  route_table_id = each.value.route_table_id
}

# Create private subnets
resource "aws_subnet" "private_subnets" {
  for_each = { for subnet in var.subnets : subnet.name => subnet if !subnet.is_public }

  vpc_id                              = each.value.vpc_id
  cidr_block                          = each.value.cidr_block
  availability_zone                   = each.value.availability_zone
  private_dns_hostname_type_on_launch = each.value.private_dns_hostname_type_on_launch

  tags = merge(each.value.tags, {
    Name = each.value.name
  })
}

# Associate private subnets with their route table
resource "aws_route_table_association" "private_subnets" {
  for_each = { for subnet in var.subnets : subnet.name => subnet if !subnet.is_public }

  subnet_id      = aws_subnet.private_subnets[each.value.name].id
  route_table_id = each.value.route_table_id
}
```

**variables.tf**

```
variable "subnets" {
  type = list(object({
    name                                = string
    vpc_id                              = string
    cidr_block                          = string
    availability_zone                   = optional(string)
    map_public_ip_on_launch             = optional(bool, true)
    private_dns_hostname_type_on_launch = optional(string, "resource-name")
    is_public                           = optional(bool, true)
    route_table_id                      = string
    tags                                = map(string)
  }))
}
```

**outputs.tf**

```
output "public_subnets" {
  value = values(aws_subnet.public_subnets)[*].id
}

output "private_subnets" {
  value = values(aws_subnet.private_subnets)[*].id
}
```

_**e) Elastic IP building block**_

**main.tf**

```
resource "aws_eip" "eip" {}
```

**outputs.tf**

```
output "eip_id" {
  value = aws_eip.eip.allocation_id
}
```

_**f) NAT Gateway building block**_

**main.tf**

```
resource "aws_nat_gateway" "nat_gw" {
  allocation_id = var.eip_id
  subnet_id     = var.subnet_id

  tags = merge(var.tags, {
    Name = var.name
  })
}
```

**variables.tf**

```
variable "name" {
  type = string
}

variable "eip_id" {
  type = string
}

variable "subnet_id" {
  type        = string
  description = "The ID of the public subnet in which the NAT Gateway should be placed"
}

variable "tags" {
  type = map(string)
}
```

**outputs.tf**

```
output "nat_gw_id" {
  value = aws_nat_gateway.nat_gw.id
}
```

_**g) NACL**_

**main.tf**

```
resource "aws_network_acl" "nacls" {
  for_each = { for nacl in var.nacls : nacl.name => nacl }

  vpc_id = each.value.vpc_id

  dynamic "egress" {
    for_each = { for rule in each.value.egress : rule.rule_no => rule }

    content {
      protocol   = egress.value.protocol
      rule_no    = egress.value.rule_no
      action     = egress.value.action
      cidr_block = egress.value.cidr_block
      from_port  = egress.value.from_port
      to_port    = egress.value.to_port
    }
  }

  dynamic "ingress" {
    for_each = { for rule in each.value.ingress : rule.rule_no => rule }

    content {
      protocol   = ingress.value.protocol
      rule_no    = ingress.value.rule_no
      action     = ingress.value.action
      cidr_block = ingress.value.cidr_block
      from_port  = ingress.value.from_port
      to_port    = ingress.value.to_port
    }
  }

  tags = merge(each.value.tags, {
    Name = each.value.name
  })
}

resource "aws_network_acl_association" "nacl_associations" {
  for_each = { for nacl in var.nacls : "${nacl.name}_${nacl.subnet_id}" => nacl }

  network_acl_id = aws_network_acl.nacls[each.value.name].id
  subnet_id      = each.value.subnet_id
}
```

**variables.tf**

```
variable "nacls" {
  type = list(object({
    name   = string
    vpc_id = string
    egress = list(object({
      protocol   = string
      rule_no    = number
      action     = string
      cidr_block = string
      from_port  = number
      to_port    = number
    }))
    ingress = list(object({
      protocol   = string
      rule_no    = number
      action     = string
      cidr_block = string
      from_port  = number
      to_port    = number
    }))
    subnet_id = string
    tags      = map(string)
  }))
}
```

**outputs.tf**

```
output "nacls" {
  value = values(aws_network_acl.nacls)[*].id
}

output "nacl_associations" {
  value = values(aws_network_acl_association.nacl_associations)[*].id
}
```

_**h) Security Group building block**_

**main.tf**

```
resource "aws_security_group" "security_group" {
  name        = var.name
  description = var.description
  vpc_id      = var.vpc_id

  # Ingress rules
  dynamic "ingress" {
    for_each = var.ingress_rules
    content {
      from_port   = ingress.value.from_port
      to_port     = ingress.value.to_port
      protocol    = ingress.value.protocol
      cidr_blocks = ingress.value.cidr_blocks
    }
  }

  # Egress rules
  dynamic "egress" {
    for_each = var.egress_rules
    content {
      from_port   = egress.value.from_port
      to_port     = egress.value.to_port
      protocol    = egress.value.protocol
      cidr_blocks = egress.value.cidr_blocks
    }
  }

  tags = merge(var.tags, {
    Name = var.name
  })
}
```

**variables.tf**

```
variable "vpc_id" {
  type = string
}

variable "name" {
  type = string
}

variable "description" {
  type = string
}

variable "ingress_rules" {
  type = list(object({
    protocol    = string
    from_port   = string
    to_port     = string
    cidr_blocks = list(string)
  }))
  default = []
}

variable "egress_rules" {
  type = list(object({
    protocol    = string
    from_port   = string
    to_port     = string
    cidr_blocks = list(string)
  }))
  default = []
}

variable "tags" {
  type = map(string)
}
```

**outputs.tf**

```
output "security_group_id" {
  value = aws_security_group.security_group.id
}
```

_**i) EC2 building block**_

**main.tf**

```
# AMI
data "aws_ami" "ami" {
  most_recent = var.most_recent_ami
  owners      = var.owners

  filter {
    name   = var.ami_name_filter
    values = var.ami_values_filter
  }
}

# EC2 Instance
resource "aws_instance" "ec2_instance" {
  ami                         = data.aws_ami.ami.id
  iam_instance_profile        = var.use_instance_profile ? var.instance_profile_name : null
  instance_type               = var.instance_type
  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = var.existing_security_group_ids
  associate_public_ip_address = var.assign_public_ip
  key_name                    = var.uses_ssh ? var.keypair_name : null
  user_data                   = var.use_userdata ? file(var.userdata_script_path) : null
  user_data_replace_on_change = var.use_userdata ? var.user_data_replace_on_change : null

  tags = merge(
    {
      Name = var.instance_name
    },
    var.extra_tags
  )
}
```

**variables.tf**

```
variable "most_recent_ami" {
  type = bool
}

variable "owners" {
  type    = list(string)
  default = ["amazon"]
}

variable "ami_name_filter" {
  type    = string
  default = "name"
}

variable "ami_values_filter" {
  type    = list(string)
  default = ["al2023-ami-2023.*-x86_64"]
}

variable "use_instance_profile" {
  type    = bool
  default = false
}

variable "instance_profile_name" {
  type = string
}

variable "instance_name" {
  description = "Name of the instance"
  type        = string
}

variable "subnet_id" {
  description = "ID of the subnet"
  type        = string
}

variable "instance_type" {
  description = "Type of EC2 instance"
  type        = string
  default     = "t2.micro"
}

variable "assign_public_ip" {
  type    = bool
  default = true
}

variable "extra_tags" {
  description = "Additional tags for EC2 instances"
  type        = map(string)
  default     = {}
}

variable "existing_security_group_ids" {
  description = "security group IDs for EC2 instances"
  type        = list(string)
}

variable "uses_ssh" {
  type = bool
}

variable "keypair_name" {
  type = string
}
variable "use_userdata" {
  description = "Whether to use userdata"
  type        = bool
  default     = false
}

variable "userdata_script_path" {
  description = "Path to the userdata script"
  type        = string
}

variable "user_data_replace_on_change" {
  type = bool
}
```

**outputs.tf**

```
output "instance_id" {
  value = aws_instance.ec2_instance.id
}

output "instance_arn" {
  value = aws_instance.ec2_instance.arn
}

output "instance_private_ip" {
  value = aws_instance.ec2_instance.private_ip
}

output "instance_public_ip" {
  value = aws_instance.ec2_instance.public_ip
}

output "instance_public_dns" {
  value = aws_instance.ec2_instance.public_dns
}
```

_**j) IAM Role building block**_

**main.tf**

```
data "aws_iam_policy_document" "assume_role" {
  statement {
    effect = "Allow"

    dynamic "principals" {
      for_each = { for principal in var.principals : principal.type => principal }
      content {
        type        = principals.value.type
        identifiers = principals.value.identifiers
      }
    }

    actions = ["sts:AssumeRole"]

    dynamic "condition" {
      for_each = var.is_external ? [var.condition] : []

      content {
        test     = condition.value.test
        variable = condition.value.variable
        values   = condition.value.values
      }
    }
  }
}

data "aws_iam_policy_document" "policy_document" {
  dynamic "statement" {
    for_each = { for statement in var.policy_statements : statement.sid => statement }

    content {
      effect    = "Allow"
      actions   = statement.value.actions
      resources = statement.value.resources

      dynamic "condition" {
        for_each = statement.value.has_condition ? [statement.value.condition] : []

        content {
          test     = condition.value.test
          variable = condition.value.variable
          values   = condition.value.values
        }
      }
    }
  }
}

resource "aws_iam_role" "role" {
  name               = var.role_name
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

resource "aws_iam_role_policy" "policy" {
  count = length(var.policy_statements) > 0 && var.policy_name != "" ? 1 : 0

  name   = var.policy_name
  role   = aws_iam_role.role.id
  policy = data.aws_iam_policy_document.policy_document.json
}

resource "aws_iam_role_policy_attachment" "attachment" {
  for_each = { for attachment in var.policy_attachments : attachment.arn => attachment }

  policy_arn = each.value.arn
  role       = aws_iam_role.role.name
}
```

**variables.tf**

```
variable "principals" {
  type = list(object({
    type        = string
    identifiers = list(string)
  }))
}

variable "is_external" {
  type    = bool
  default = false
}

variable "condition" {
  type = object({
    test     = string
    variable = string
    values   = list(string)
  })

  default = {
    test     = "test"
    variable = "variable"
    values   = ["values"]
  }
}

variable "role_name" {
  type = string
}

variable "policy_name" {
  type = string
}

variable "policy_attachments" {
  type = list(object({
    arn = string
  }))

  default = []
}

variable "policy_statements" {
  type = list(object({
    sid           = string
    actions       = list(string)
    resources     = list(string)
    has_condition = optional(bool, false)
    condition = optional(object({
      test     = string
      variable = string
      values   = list(string)
    }))
  }))

  default = [
    {
      sid = "CloudWatchLogsPermissions"
      actions = [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:DescribeLogGroups",
        "logs:DescribeLogStreams",
        "logs:PutLogEvents",
        "logs:GetLogEvents",
        "logs:FilterLogEvents",
      ],
      resources = ["*"]
    }
  ]
}
```

**outputs.tf**

```
output "role_arn" {
  value = aws_iam_role.role.arn
}

output "role_name" {
  value = aws_iam_role.role.name
}

output "unique_id" {
  value = aws_iam_role.role.unique_id
}
```

_**k) Instance Profile building block**_

**main.tf**

```
# Instance Profile
resource "aws_iam_instance_profile" "instance_profile" {
  name = var.instance_profile_name
  path = var.path
  role = var.iam_role_name

  tags = merge(var.instance_profile_tags, {
    Name = var.instance_profile_name
  })
}
```

**variables.tf**

```
variable "instance_profile_name" {
  type        = string
  description = "(Optional, Forces new resource) Name of the instance profile. If omitted, Terraform will assign a random, unique name. Conflicts with name_prefix. Can be a string of characters consisting of upper and lowercase alphanumeric characters and these special characters: _, +, =, ,, ., @, -. Spaces are not allowed."
}

variable "iam_role_name" {
  type        = string
  description = "(Optional) Name of the role to add to the profile."
}

variable "path" {
  type        = string
  default     = "/"
  description = "(Optional, default ' / ') Path to the instance profile. For more information about paths, see IAM Identifiers in the IAM User Guide. Can be a string of characters consisting of either a forward slash (/) by itself or a string that must begin and end with forward slashes. Can include any ASCII character from the ! (\u0021) through the DEL character (\u007F), including most punctuation characters, digits, and upper and lowercase letters."
}

variable "instance_profile_tags" {
  type = map(string)
}
```

**outputs.tf**

```
output "arn" {
  value = aws_iam_instance_profile.instance_profile.arn
}

output "name" {
  value = aws_iam_instance_profile.instance_profile.name
}

output "id" {
  value = aws_iam_instance_profile.instance_profile.id
}

output "unique_id" {
  value = aws_iam_instance_profile.instance_profile.unique_id
}
```

_**l) EKS Cluster building block**_

**main.tf**

```
# EKS Cluster
resource "aws_eks_cluster" "cluster" {
  name                      = var.name
  enabled_cluster_log_types = var.enabled_cluster_log_types
  role_arn                  = var.cluster_role_arn
  version                   = var.cluster_version

  vpc_config {
    subnet_ids = var.subnet_ids
  }
}
```

**variables.tf**

```
variable "name" {
  type        = string
  description = "(Required) Name of the cluster. Must be between 1-100 characters in length. Must begin with an alphanumeric character, and must only contain alphanumeric characters, dashes and underscores (^[0-9A-Za-z][A-Za-z0-9\\-_]+$)."
}

variable "enabled_cluster_log_types" {
  type        = list(string)
  description = "(Optional) List of the desired control plane logging to enable."
  default     = []
}

variable "cluster_role_arn" {
  type        = string
  description = "(Required) ARN of the IAM role that provides permissions for the Kubernetes control plane to make calls to AWS API operations on your behalf."
}

variable "subnet_ids" {
  type        = list(string)
  description = "(Required) List of subnet IDs. Must be in at least two different availability zones. Amazon EKS creates cross-account elastic network interfaces in these subnets to allow communication between your worker nodes and the Kubernetes control plane."
}

variable "cluster_version" {
  type        = string
  description = "(Optional) Desired Kubernetes master version. If you do not specify a value, the latest available version at resource creation is used and no upgrades will occur except those automatically triggered by EKS. The value must be configured and increased to upgrade the version when desired. Downgrades are not supported by EKS."
  default     = null
}
```

**outputs.tf**

```
output "arn" {
  value = aws_eks_cluster.cluster.arn
}

output "endpoint" {
  value = aws_eks_cluster.cluster.endpoint
}

output "id" {
  value = aws_eks_cluster.cluster.id
}

output "kubeconfig-certificate-authority-data" {
  value = aws_eks_cluster.cluster.certificate_authority[0].data
}

output "name" {
  value = aws_eks_cluster.cluster.name
}

output "oidc_tls_issuer" {
  value = aws_eks_cluster.cluster.identity[0].oidc[0].issuer
}

output "version" {
  value = aws_eks_cluster.cluster.version
}
```

_**m) EKS Add-ons building block**_

**main.tf**

```
# EKS Add-On
resource "aws_eks_addon" "addon" {
  for_each = { for addon in var.addons : addon.name => addon }

  cluster_name  = var.cluster_name
  addon_name    = each.value.name
  addon_version = each.value.version
}
```

**variables.tf**

```
variable "addons" {
  type = list(object({
    name    = string
    version = string
  }))
  description = "(Required) Name of the EKS add-on."
}

variable "cluster_name" {
  type        = string
  description = "(Required) Name of the EKS Cluster. Must be between 1-100 characters in length. Must begin with an alphanumeric character, and must only contain alphanumeric characters, dashes and underscores (^[0-9A-Za-z][A-Za-z0-9\\-_]+$)."
}
```

**outputs.tf**

```
output "arns" {
  value = values(aws_eks_addon.addon)[*].arn
}
```

_**n) EKS Node Group building block**_

**main.tf**

```
# EKS node group
resource "aws_eks_node_group" "node_group" {
  cluster_name    = var.cluster_name
  node_group_name = var.node_group_name
  node_role_arn   = var.node_role_arn
  subnet_ids      = var.subnet_ids
  version         = var.cluster_version
  ami_type        = var.ami_type
  capacity_type   = var.capacity_type
  disk_size       = var.disk_size
  instance_types  = var.instance_types

  scaling_config {
    desired_size = var.scaling_config.desired_size
    max_size     = var.scaling_config.max_size
    min_size     = var.scaling_config.min_size
  }

  update_config {
    max_unavailable            = var.update_config.max_unavailable
    max_unavailable_percentage = var.update_config.max_unavailable_percentage
  }
}
```

**variables.tf**

```
variable "cluster_name" {
  type        = string
  description = "(Required) Name of the EKS Cluster. Must be between 1-100 characters in length. Must begin with an alphanumeric character, and must only contain alphanumeric characters, dashes and underscores (^[0-9A-Za-z][A-Za-z0-9\\-_]+$)."
}

variable "node_group_name" {
  type        = string
  description = "(Optional) Name of the EKS Node Group. If omitted, Terraform will assign a random, unique name. Conflicts with node_group_name_prefix. The node group name can't be longer than 63 characters. It must start with a letter or digit, but can also include hyphens and underscores for the remaining characters."
}

variable "node_role_arn" {
  type        = string
  description = "(Required) Amazon Resource Name (ARN) of the IAM Role that provides permissions for the EKS Node Group."
}

variable "scaling_config" {
  type = object({
    desired_size = number
    max_size     = number
    min_size     = number
  })

  default = {
    desired_size = 1
    max_size     = 1
    min_size     = 1
  }

  description = "(Required) Configuration block with scaling settings."
}

variable "subnet_ids" {
  type        = list(string)
  description = "(Required) Identifiers of EC2 Subnets to associate with the EKS Node Group. These subnets must have the following resource tag: kubernetes.io/cluster/CLUSTER_NAME (where CLUSTER_NAME is replaced with the name of the EKS Cluster)."
}

variable "update_config" {
  type = object({
    max_unavailable_percentage = optional(number)
    max_unavailable            = optional(number)
  })
}

variable "cluster_version" {
  type        = string
  description = "(Optional) Kubernetes version. Defaults to EKS Cluster Kubernetes version. Terraform will only perform drift detection if a configuration value is provided."
  default     = null
}

variable "ami_type" {
  type        = string
  description = "(Optional) Type of Amazon Machine Image (AMI) associated with the EKS Node Group. Valid values are: AL2_x86_64 | AL2_x86_64_GPU | AL2_ARM_64 | CUSTOM | BOTTLEROCKET_ARM_64 | BOTTLEROCKET_x86_64 | BOTTLEROCKET_ARM_64_NVIDIA | BOTTLEROCKET_x86_64_NVIDIA | WINDOWS_CORE_2019_x86_64 | WINDOWS_FULL_2019_x86_64 | WINDOWS_CORE_2022_x86_64 | WINDOWS_FULL_2022_x86_64 | AL2023_x86_64_STANDARD | AL2023_ARM_64_STANDARD"
  default     = "AL2023_x86_64_STANDARD"
}

variable "capacity_type" {
  type        = string
  description = "(Optional) Type of capacity associated with the EKS Node Group. Valid values: ON_DEMAND, SPOT."
  default     = "ON_DEMAND"
}

variable "disk_size" {
  type        = number
  description = "(Optional) Disk size in GiB for worker nodes. Defaults to 20."
  default     = 20
}

variable "instance_types" {
  type        = list(string)
  description = "(Required) Set of instance types associated with the EKS Node Group. Defaults to [\"t3.medium\"]."
  default     = ["t3.medium"]
}
```

**outputs.tf**

```
output "arn" {
  value = aws_eks_node_group.node_group.arn
}
```

_**o) IAM OIDC building block (to allow pods to assume IAM roles)**_

**main.tf**

```
data "tls_certificate" "tls" {
  url = var.oidc_issuer
}

resource "aws_iam_openid_connect_provider" "provider" {
  client_id_list  = var.client_id_list
  thumbprint_list = data.tls_certificate.tls.certificates[*].sha1_fingerprint
  url             = data.tls_certificate.tls.url
}

data "aws_iam_policy_document" "assume_role_policy" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.provider.url, "https://", "")}:sub"
      values   = ["system:serviceaccount:kube-system:aws-node"]
    }

    principals {
      identifiers = [aws_iam_openid_connect_provider.provider.arn]
      type        = "Federated"
    }
  }
}

resource "aws_iam_role" "role" {
  assume_role_policy = data.aws_iam_policy_document.assume_role_policy.json
  name               = var.role_name
}
```

**variables.tf**

```
variable "role_name" {
  type        = string
  description = "(Required) Name of the IAM role."
}

variable "client_id_list" {
  type    = list(string)
  default = ["sts.amazonaws.com"]
}

variable "oidc_issuer" {
  type = string
}
```

**outputs.tf**

```
output "provider_arn" {
  value = aws_iam_openid_connect_provider.provider.arn
}

output "provider_id" {
  value = aws_iam_openid_connect_provider.provider.id
}

output "provider_url" {
  value = aws_iam_openid_connect_provider.provider.url
}

output "role_arn" {
  value = aws_iam_role.role.arn
}
```

With the building blocks defined, we can now version them into GitHub repositories and use them in the next step to develop our Terragrunt code.


**2. Write Terragrunt code to provision infrastructure**

Our Terragrunt code will have the following directory structure:

```
infra-live/
  <environment>/
    <module_1>/
      terragrunt.hcl
    <module_2>/
      terragrunt.hcl
    ...
    <module_n>/
      terragrunt.hcl
  terragrunt.hcl
```

For our article, we'll only have a dev directory. This directory will contain directories that will represent the different specific resources we'll want to create.

Our final folder structure will be:

```
infra-live/
  dev/
    bastion-ec2/
      terragrunt.hcl
      user-data.sh
    bastion-instance-profile/
      terragrunt.hcl
    bastion-role/
      terragrunt.hcl
    eks-addons/
      terragrunt.hcl
    eks-cluster/
      terragrunt.hcl
    eks-cluster-role/
      terragrunt.hcl
    eks-node-group/
      terragrunt.hcl
    eks-pod-iam/
      terragrunt.hcl
    internet-gateway/
      terragrunt.hcl
    nacl/
      terragrunt.hcl
    nat-gateway/
      terragrunt.hcl
    nat-gw-eip/
      terragrunt.hcl
    private-route-table/
      terragrunt.hcl
    private-subnets/
      terragrunt.hcl
    public-route-table/
      terragrunt.hcl
    public-subnets/
      terragrunt.hcl
    security-group/
      terragrunt.hcl
    vpc/
      terragrunt.hcl
    worker-node-role/
      terragrunt.hcl
  .gitignore
  terragrunt.hcl
```

**a) infra-live/terragrunt.hcl**

Our root **terragrunt.hcl** file will contain the configuration for our remote Terraform state. We'll use an S3 bucket in AWS to store our Terraform state file, and the name of our S3 bucket must be unique for it to be successfully created. This bucket must be created before applying any terragrunt configuration. My S3 bucket is in the N. Virginia region (us-east-1).

```
generate "backend" {
  path      = "backend.tf"
  if_exists = "overwrite_terragrunt"
  contents = <<EOF
terraform {
  backend "s3" {
    bucket         = "<s3_bucket_name>"
    key            = "infra-live/${path_relative_to_include()}/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
  }
}
EOF
}
```

Make sure you replace **<s3_bucket_name>** with the name of your own S3 bucket.

**b) infra-live/dev/vpc/terragrunt.hcl**

This module uses the **VPC building block** to create our VPC.
Our VPC CIDR will be `10.0.0.0/16`.

```
include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "git@github.com:<name_or_org>/vpc.git"
}

inputs = {
  vpc_cidr = "10.0.0.0/16"
  vpc_name = "eks-demo-vpc"
  enable_dns_hostnames = true
  vpc_tags = {}
}
```

The values passed in the inputs section are the variables that are defined in the building blocks.

For this module and the following modules, we won't be passing the variables **AWS_ACCESS_KEY_ID**, **AWS_SECRET_ACCESS_KEY**, and **AWS_REGION** since such credentials (bar the **AWS_REGION** variable) are sensitive. You'll have to add them as secrets in the GitHub repository you'll create to version your Terragrunt code.

**c) infra-live/dev/internet-gateway/terragrunt.hcl**

This module uses the **Internet Gateway building block** as its Terraform source to create our VPC's internet gateway.

```
include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "git@github.com:<name_or_org>/internet-gateway.git"
}

dependency "vpc" {
  config_path = "../vpc"
}

inputs = {
  vpc_id = dependency.vpc.outputs.vpc_id
  name = "eks-demo-igw"
  tags = {}
}
```

**d) infra-live/dev/public-route-table/terragrunt.hcl**

This module uses the **Route Table building block** as its Terraform source to create our VPC's public route table to be associated with the public subnet we'll create next.

It also adds a route to direct all internet traffic to the internet gateway.

```
include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "git@github.com:<name_or_org>/route-table.git"
}

dependency "vpc" {
  config_path = "../vpc"
}

dependency "igw" {
  config_path = "../internet-gateway"
}

inputs = {
  route_tables = [
    {
      name      = "eks-demo-public-rt"
      vpc_id    = dependency.vpc.outputs.vpc_id
      is_igw_rt = true

      routes = [
        {
          cidr_block = "0.0.0.0/0"
          igw_id     = dependency.igw.outputs.igw_id
        }
      ]

      tags = {}
    }
  ]
}
```

**e) infra-live/dev/public-subnets/terragrunt.hcl**

This module uses the **Subnet building block** as its Terraform source to create our VPC's public subnet and associate it with the public route table.

The CIDR for the public subnet will be 10.0.0.0/24.

```
include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "git@github.com:<name_or_org>/subnet.git"
}

dependency "vpc" {
  config_path = "../vpc"
}

dependency "public-route-table" {
  config_path = "../public-route-table"
}

inputs = {
  subnets = [
    {
      name                                = "eks-demo-public-subnet"
      vpc_id                              = dependency.vpc.outputs.vpc_id
      cidr_block                          = "10.0.0.0/24"
      availability_zone                   = "us-east-1a"
      map_public_ip_on_launch             = true
      private_dns_hostname_type_on_launch = "resource-name"
      is_public                           = true
      route_table_id                      = dependency.public-route-table.outputs.route_table_ids[0]
      tags                                = {}
    }
  ]
}
```

**f) infra-live/dev/nat-gw-eip/terragrunt.hcl**

This module uses the **Elastic IP building block** as its Terraform source to create a static IP in our VPC which we'll associate with the NAT gateway we'll create next.

```
include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "git@github.com:<name_or_org>/eip.git"
}

dependency "vpc" {
  config_path = "../vpc"
}

inputs = {}
```

**g) infra-live/dev/nat-gateway/terragrunt.hcl**

This module uses the **NAT Gateway building block** as its Terraform to create a NAT Gateway that we'll place in our VPC's public subnet. It will have the previously created elastic IP attached to it.

```
include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "git@github.com:<name_or_org>/nat-gateway.git"
}

dependency "eip" {
  config_path = "../nat-gw-eip"
}

dependency "public-subnets" {
  config_path = "../public-subnets"
}

inputs = {
  eip_id = dependency.eip.outputs.eip_id
  subnet_id = dependency.public-subnets.outputs.public_subnets[0]
  name = "eks-demo-nat-gw"
  tags = {}
}
```

**h) infra-live/dev/private-route-table/terragrunt.hcl**

This module uses the **Route Table building block** as its Terraform source to create our VPC's private route table to be associated with the private subnets we'll create next.

It also adds a route to direct all internet traffic to the NAT gateway.

```
include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "git@github.com:<name_or_org>/route-table.git"
}

dependency "vpc" {
  config_path = "../vpc"
}

dependency "nat-gw" {
  config_path = "../nat-gateway"
}

inputs = {
  route_tables = [
    {
      name      = "eks-demo-private-rt"
      vpc_id    = dependency.vpc.outputs.vpc_id
      is_igw_rt = false

      routes = [
        {
          cidr_block = "0.0.0.0/0"
          nat_gw_id     = dependency.nat-gw.outputs.nat_gw_id
        }
      ]

      tags = {}
    }
  ]
}
```

**i) infra-live/dev/private-subnets/terragrunt.hcl**

This module uses the **Subnet building block** as its Terraform source to create our VPC's private subnets and associate them with the private route table.

The CIDRs for the private subnets will be 10.0.100.0/24 (us-east-1a) and 10.0.200.0/24 (us-east-1b).

```
include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "git@github.com:<name_or_org>/subnet.git"
}

dependency "vpc" {
  config_path = "../vpc"
}

dependency "private-route-table" {
  config_path = "../private-route-table"
}

inputs = {
  subnets = [
    {
      name                                = "eks-demo-app-subnet-a"
      vpc_id                              = dependency.vpc.outputs.vpc_id
      cidr_block                          = "10.0.100.0/24"
      availability_zone                   = "us-east-1a"
      map_public_ip_on_launch             = false
      private_dns_hostname_type_on_launch = "resource-name"
      is_public                           = false
      route_table_id                      = dependency.private-route-table.outputs.route_table_ids[0]
      tags                                = {}
    },

    {
      name                                = "eks-demo-app-subnet-b"
      vpc_id                              = dependency.vpc.outputs.vpc_id
      cidr_block                          = "10.0.200.0/24"
      availability_zone                   = "us-east-1b"
      map_public_ip_on_launch             = false
      private_dns_hostname_type_on_launch = "resource-name"
      is_public                           = false
      route_table_id                      = dependency.private-route-table.outputs.route_table_ids[0]
      tags                                = {}
    }
  ]
}
```

**j) infra-live/dev/nacl/terragrunt.hcl**

This module uses the **NACL building block** as its Terraform source to create NACLs for our public and private subnets.

For the sake of simplicity, we'll configure very loose NACL and security group rules, but in the next blog post, we'll enforce security rules for the VPC and cluster.

```
include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "git@github.com:<name_or_org>/nacl.git"
}

dependency "vpc" {
  config_path = "../vpc"
}

dependency "public-subnets" {
  config_path = "../public-subnets"
}

dependency "private-subnets" {
  config_path = "../private-subnets"
}

inputs = {
  _vpc_id = dependency.vpc.outputs.vpc_id
  nacls = [
    # Public NACL
    {
      name   = "eks-demo-public-nacl"
      vpc_id = dependency.vpc.outputs.vpc_id
      egress = [
        {
          protocol = "-1"
          rule_no  = 500
          action   = "allow"
          cidr_block = "0.0.0.0/0"
          from_port = 0
          to_port   = 0
        }
      ]
      ingress = [
        {
          protocol = "-1"
          rule_no  = 100
          action   = "allow"
          cidr_block = "0.0.0.0/0"
          from_port = 0
          to_port   = 0
        }
      ]
      subnet_id = dependency.public-subnets.outputs.public_subnets[0]
      tags      = {}
    },

    # App NACL A
    {
      name   = "eks-demo-nacl-a"
      vpc_id = dependency.vpc.outputs.vpc_id
      egress = [
        {
          protocol = "-1"
          rule_no  = 100
          action   = "allow"
          cidr_block = "0.0.0.0/0"
          from_port = 0
          to_port   = 0
        }
      ]
      ingress = [
        {
          protocol = "-1"
          rule_no  = 100
          action   = "allow"
          cidr_block = "0.0.0.0/0"
          from_port = 0
          to_port   = 0
        }
      ]
      subnet_id = dependency.private-subnets.outputs.private_subnets[0]
      tags      = {}
    },

    # App NACL B
    {
      name   = "eks-demo-nacl-b"
      vpc_id = dependency.vpc.outputs.vpc_id
      egress = [
        {
          protocol = "-1"
          rule_no  = 100
          action   = "allow"
          cidr_block = "0.0.0.0/0"
          from_port = 0
          to_port   = 0
        }
      ]
      ingress = [
        {
          protocol = "-1"
          rule_no  = 100
          action   = "allow"
          cidr_block = "0.0.0.0/0"
          from_port = 0
          to_port   = 0
        }
      ]
      subnet_id = dependency.private-subnets.outputs.private_subnets[1]
      tags      = {}
    }
  ]
}
```

**k) infra-live/dev/security-group/terragrunt.hcl**

This module uses the **Security Group building block** as its Terraform source to create a security group for our nodes and bastion host.

Again, its rules are going to be very loose, but we'll correct that in the next article.

```
include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "git@github.com:<name_or_org>/security-group.git"
}

dependency "vpc" {
  config_path = "../vpc"
}

dependency "public-subnets" {
  config_path = "../public-subnets"
}

dependency "private-subnets" {
  config_path = "../private-subnets"
}

inputs = {
  vpc_id = dependency.vpc.outputs.vpc_id
  name = "public-sg"
  description = "Open security group"
  ingress_rules = [
    {
      protocol    = "-1"
      from_port   = 0
      to_port     = 0
      cidr_blocks = ["0.0.0.0/0"]
    }
  ]
  egress_rules = [
    {
      protocol    = "-1"
      from_port   = 0
      to_port     = 0
      cidr_blocks = ["0.0.0.0/0"]
    }
  ]
  tags = {}
}
```

**l) infra-live/dev/bastion-role/terragrunt.hcl**

This module uses the **IAM Role building block** as its Terraform source to create an IAM role with the permissions that our bastion host will need to perform EKS actions and to be managed by Systems Manager.

```
include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "git@github.com:<name_or_org>/iam-role.git"
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
```

**m) infra-live/dev/bastion-instance-profile/terragrunt.hcl**

This module uses the **Instance Profile building block* as its Terraform source to create an IAM instance profile for our bastion host. The IAM role created in the previous step is attached to this instance profile.

```
include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "git@github.com:<name_or_org>/instance-profile.git"
}

dependency "iam-role" {
  config_path = "../bastion-role"
}

inputs = {
  instance_profile_name = "EKSBastionInstanceProfile"
  path = "/"
  iam_role_name = dependency.iam-role.outputs.role_name
  instance_profile_tags = {}
}
```

**n) infra-live/dev/bastion-ec2/terragrunt.hcl**

This module uses the **EC2 building block** as its Terraform source to create an EC2 instance which we'll use as a jump box (or bastion host) to manage the worker nodes in our EKS cluster.

The bastion host will be placed in our public subnet and will have the instance profile we created in the previous step attached to it, as well as our loose security group.

It is a Linux instance of type t2.micro using the Amazon Linux 2023 AMI with a user data script configured. This script will be defined in the next step.

```
include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "git@github.com:<name_or_org>/ec2.git"
}

dependency "public-subnets" {
  config_path = "../public-subnets"
}

dependency "instance-profile" {
  config_path = "../bastion-instance-profile"
}

dependency "security-group" {
  config_path = "../security-group"
}

inputs = {
  instance_name = "eks-bastion-host"
  use_instance_profile = true
  instance_profile_name = dependency.instance-profile.outputs.name
  most_recent_ami = true
  owners = ["amazon"]
  ami_name_filter = "name"
  ami_values_filter = ["al2023-ami-2023.*-x86_64"]
  instance_type = "t2.micro"
  subnet_id = dependency.public-subnets.outputs.public_subnets[0]
  existing_security_group_ids = [dependency.security-group.outputs.security_group_id]
  assign_public_ip = true
  uses_ssh = false
  keypair_name = ""
  use_userdata = true
  userdata_script_path = "user-data.sh"
  user_data_replace_on_change = true
  extra_tags = {}
}
```

**o) infra-live/dev/bastion-ec2/user-data.sh**

This user data script installs the AWS CLI, as well as the `kubectl` and `eksctl` tools. It also configures an alias for the `kubectl` utility (`k`), and bash completion for it.

```
#!/bin/bash

# Become root user
sudo su -

# Update software packages
sudo yum update -y

# Download AWS CLI package
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv.zip"

# Unzip file
unzip -q awscli.zip

# Install AWS CLI
./aws/install

# Check AWS CLI version
aws —version

# Download kubectl binary
sudo curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"

# Give the binary executable permissions
sudo chmod +x ./kubectl

# Move binary to directory in system’s path
sudo mv kubectl /usr/local/bin/
export PATH=/usr/local/bin:$PATH 

# Check kubectl version
kubectl version -—client

# Installing kubectl bash completion on Linux
## If bash-completion is not installed on Linux, install the 'bash-completion' package
## via your distribution's package manager.
## Load the kubectl completion code for bash into the current shell
source <(kubectl completion bash)
## Write bash completion code to a file and source it from .bash_profile
kubectl completion bash > ~/.kube/completion.bash.inc
printf "
# kubectl shell completion
source '$HOME/.kube/completion.bash.inc'
" >> $HOME/.bash_profile
source $HOME/.bash_profile

# Set bash completion for kubectl alias (k)
echo 'alias k=kubectl' >>~/.bashrc
echo 'complete -F __start_kubectl k' >>~/.bashrc

# Get platform
ARCH=amd64
PLATFORM=$(uname -s)_$ARCH

# Download eksctl tool for platform
curl -sLO "https://github.com/eksctl-io/eksctl/releases/latest/download/eksctl_$PLATFORM.tar.gz"

# (Optional) Verify checksum
curl -sL "https://github.com/eksctl-io/eksctl/releases/latest/download/eksctl_checksums.txt" | grep $PLATFORM | sha256sum --check

# Extract binary
tar -xzf eksctl_$PLATFORM.tar.gz -C /tmp && rm eksctl_$PLATFORM.tar.gz

# Move binary to directory in system’s path
sudo mv /tmp/eksctl /usr/local/bin

# Check eksctl version
eksctl version

# Enable eksctl bash completion
. <(eksctl completion bash)
```

**p) infra-live/dev/eks-cluster-role/terragrunt.hcl**

This module uses the **IAM Role building block** as its Terraform source to create an IAM role for the EKS cluster. It has the managed policy AmazonEKSClusterPolicy attached to it.

```
include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "git@github.com:<name_or_org>/iam-role.git"
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
```

**q) infra-live/dev/eks-cluster/terragrunt.hcl**

This module uses the **EKS Cluster building block** as its Terraform source to create an EKS cluster which uses the IAM role created in the previous step.

The cluster will provision ENIs (Elastic Network Interfaces) in the private subnets we had created, which will be used by the EKS worker nodes.

The cluster also has various cluster log types enabled for auditing purposes.

```
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
```

**r) infra-live/dev/eks-addons/terragrunt.hcl**

This module uses the **EKS Add-ons building block** as its Terraform source to activate add-ons for our EKS cluster.

This is very important, given that these add-ons can help with networking within the AWS VPC using the VPC features (`vpc-cni`), cluster domain name resolution (`coredns`), maintaining network connectivity between services and pods in the cluster (`kube-proxy`), managing IAM credentials in the cluster (`eks-pod-identity-agent`), or allowing EKS to manage the lifecycle of EBS volumes (`aws-ebs-csi-driver`).

```
include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "git@github.com:<name_or_org>/eks-addon.git"
}

dependency "cluster" {
  config_path = "../eks-cluster"
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
```

**s) infra-live/dev/worker-node-role/terragrunt.hcl**

This module uses the **IAM Role building block** as its Terraform source to create an IAM role for the EKS worker nodes.

This role grants the node permissions to carry out its operations within the cluster, and to be managed by Systems Manager.

```
include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "git@github.com:<name_or_org>/iam-role.git"
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
```

**t) infra-live/dev/eks-node-group/terragrunt.hcl**

This module uses the **EKS Node Group building block** as its Terraform source to create a node group in the cluster.

The nodes in the node group will be provisioned in the VPC's private subnets, and we'll be using on-demand Linux instances of type `t3.medium` with the `AL2_x86_64` AMI and disk size of `20GB`.

```
include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "git@github.com:<name_or_org>/eks-node-group.git"
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
```

**u) infra-live/dev/eks-pod-iam/terragrunt.hcl**

This module uses the **IAM OIDC building block** as its Terraform source to create resources that will allow pods to assume IAM roles and communicate with other AWS services.

```
include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "git@github.com:<name_or_org>/iam-oidc.git"
}

dependency "cluster" {
  config_path = "../eks-cluster"
}

inputs = {
  role_name = "EKSDemoPodIAMAuth"
  oidc_issuer = dependency.cluster.outputs.oidc_tls_issuer
  client_id_list = ["sts.amazonaws.com"]
}
```

Having done all this, we now need to create a GitHub repository for our Terragrunt code and push our code to that repository. We should also configure repository secrets for our AWS credentials (`AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_REGION`) and an SSH private key that we'll use to access the repositories with our Terraform building blocks.

Once that is done, we can proceed to create a GitHub Actions workflow to automate the provisioning of our infrastructure.

**3. Create a GitHub Actions workflow for Automated Infrastructure Provisioning**

Now that our code has been versioned, we can write a workflow that will be triggered whenever we push code to the main branch (use whichever branch you prefer, like master).
Ideally, this workflow should only be triggered after a pull request has been approved to merge to the main branch, but we'll keep it simple for illustration purposes.

The first thing will be to create a `.github/workflows` in the root directory of your `infra-live` project. You can then create a YAML file within this `infra-live/.github/workflows` directory called **deploy.yml**, for example.

We'll add the following code to our `infra-live/.github/workflows/configure.yml` file to handle the provisioning of our infrastructure:

```
name: Deploy

on:
  push:
    branches:
      - main
  pull_request:
    branches:
      - main

jobs:
  terraform:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout repository
        uses: actions/checkout@v2

      - name: Setup SSH
        uses: webfactory/ssh-agent@v0.4.1
        with:
          ssh-private-key: ${{ secrets.SSH_PRIVATE_KEY }}

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v2
        with:
          terraform_version: 1.5.5
          terraform_wrapper: false

      - name: Setup Terragrunt
        run: |
          curl -LO "https://github.com/gruntwork-io/terragrunt/releases/download/v0.48.1/terragrunt_linux_amd64"
          chmod +x terragrunt_linux_amd64
          sudo mv terragrunt_linux_amd64 /usr/local/bin/terragrunt
          terragrunt -v

      - name: Apply Terraform changes
        run: |
          cd dev
          terragrunt run-all apply -auto-approve --terragrunt-non-interactive -var AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID -var AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY -var AWS_REGION=$AWS_DEFAULT_REGION
          cd bastion-ec2
          ip=$(terragrunt output instance_public_ip)
          echo "$ip"
          echo "$ip" > public_ip.txt
          cat public_ip.txt
          pwd
        env:
          AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
          AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          AWS_DEFAULT_REGION: ${{ secrets.AWS_DEFAULT_REGION }}
```

Let's break down what this file does:

a) The `name: Deploy` line names our workflow **Deploy**

b) The following lines of code tell GitHub to trigger this workflow whenever code is pushed to the main branch or a pull request is merged to the main branch:

```
on:
  push:
    branches:
      - main
  pull_request:
    branches:
      - main
```

c) Then we define our job called **terraform** using the lines below, telling GitHub to use a runner that runs on the latest version of Ubuntu. Think of a runner as the GitHub server executing the commands in this workflow file for us:

```
jobs:
  terraform:
    runs-on: ubuntu-latest
```

d) We then define a series of steps or blocks of commands that will be executed in order.
The first step uses a GitHub action to checkout our infra-live repository into the runner so that we can start working with it:

```
      - name: Checkout repository
        uses: actions/checkout@v2
```

The next step uses another GitHub action to help us easily set up SSH on the GitHub runner using the private key we had defined as a repository secret:

```
      - name: Setup SSH
        uses: webfactory/ssh-agent@v0.4.1
        with:
          ssh-private-key: ${{ secrets.SSH_PRIVATE_KEY }}
```

The following step uses yet another GitHub action to help us easily install Terraform on the GitHub runner, specifying the exact version that we need:

```
      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v2
        with:
          terraform_version: 1.5.5
          terraform_wrapper: false
```

Then we use another step to execute a series of commands that install Terragrunt on the GitHub runner. We use the command `terragrunt -v` to check the version of Terragrunt installed and confirm that the installation was successful:

```
      - name: Setup Terragrunt
        run: |
          curl -LO "https://github.com/gruntwork-io/terragrunt/releases/download/v0.48.1/terragrunt_linux_amd64"
          chmod +x terragrunt_linux_amd64
          sudo mv terragrunt_linux_amd64 /usr/local/bin/terragrunt
          terragrunt -v
```

Finally, we use a step to apply our Terraform changes, then we use a series of commands to retrieve the public IP address of our provisioned EC2 instance and save it to a file called **public_ip.txt**:

```
      - name: Apply Terraform changes
        run: |
          cd dev
          terragrunt run-all apply -auto-approve --terragrunt-non-interactive -var AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID -var AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY -var AWS_REGION=$AWS_DEFAULT_REGION
          cd bastion-ec2
          ip=$(terragrunt output instance_public_ip)
          echo "$ip"
          echo "$ip" > public_ip.txt
          cat public_ip.txt
          pwd
        env:
          AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
          AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          AWS_DEFAULT_REGION: ${{ secrets.AWS_DEFAULT_REGION }}
```

And that's it! We can now watch the pipeline get triggered when we push code to our main branch, and see how our EKS cluster gets provisioned.

In the next article, we'll secure our cluster then access our bastion host and get our hands dirty with real Kubernetes action!

I hope you liked this article. If you have any questions or remarks, please feel free to leave a comment below.

See you soon!