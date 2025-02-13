provider "aws" {
  region = "us-east-1"
}

###High Availability VPC
resource "aws_vpc" "eks_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "eks-vpc"
  }
}

###Public & Private Subnets across 3 AZs
resource "aws_subnet" "public_subnets" {
  count                   = 3
  vpc_id                  = aws_vpc.eks_vpc.id
  cidr_block              = "10.0.${count.index + 1}.0/24"
  map_public_ip_on_launch = true
  availability_zone       = element(["us-east-1a", "us-east-1b", "us-east-1c"], count.index)

  tags = {
    Name = "Public Subnet ${count.index + 1}"
  }
}

resource "aws_subnet" "private_subnets" {
  count            = 3
  vpc_id           = aws_vpc.eks_vpc.id
  cidr_block       = "10.0.${count.index + 4}.0/24"
  availability_zone = element(["us-east-1a", "us-east-1b", "us-east-1c"], count.index)

  tags = {
    Name = "Private Subnet ${count.index + 1}"
  }
}

###Internet Gateway for Public Subnets
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.eks_vpc.id
}

###NAT Gateway for Private Subnets (1 per AZ for HA)
resource "aws_nat_gateway" "nat" {
  count         = 3
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public_subnets[count.index].id
}

resource "aws_eip" "nat" {
  count = 3
  domain = "vpc"
}

###EKS Cluster with OIDC for IRSA
resource "aws_eks_cluster" "eks_cluster" {
  name     = "my-ha-eks-cluster"
  role_arn = aws_iam_role.eks_role.arn

  vpc_config {
    subnet_ids = flatten([aws_subnet.public_subnets[*].id, aws_subnet.private_subnets[*].id])
  }

  tags = {
    Name = "my-ha-eks-cluster"
  }
}

###EKS Node Group (Private Worker Nodes)
resource "aws_eks_node_group" "eks_nodes" {
  cluster_name    = aws_eks_cluster.eks_cluster.name
  node_group_name = "eks-ha-worker-nodes"
  node_role_arn   = aws_iam_role.node_role.arn
  subnet_ids      = aws_subnet.private_subnets[*].id
  instance_types  = ["t3.medium"]

  scaling_config {
    desired_size = 3
    min_size     = 2
    max_size     = 6
  }

  tags = {
    Name = "EKS HA Worker Nodes"
  }
}

###S3 Storage for Persistent Data
resource "aws_s3_bucket" "eks_s3" {
  bucket = "ha-eks-storage-bucket"
  acl    = "private"

  tags = {
    Name = "EKS S3 Storage"
  }
}

###IAM Role for EKS Service Account (IRSA)
resource "aws_iam_role" "eks_irsa_role" {
  name = "EKS_IRSA_S3"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/${aws_eks_cluster.eks_cluster.identity[0].oidc[0].issuer}"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "${aws_eks_cluster.eks_cluster.identity[0].oidc[0].issuer}:sub": "system:serviceaccount:kube-system:eks-irsa"
        }
      }
    }
  ]
}
EOF
}

###IAM Policy for S3 Access (Read/Write)
resource "aws_iam_policy" "s3_access_policy" {
  name        = "EKS_S3_Access"
  description = "Allows Kubernetes Pods to access S3"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": ["s3:ListBucket", "s3:GetObject", "s3:PutObject"],
      "Resource": ["${aws_s3_bucket.eks_s3.arn}", "${aws_s3_bucket.eks_s3.arn}/*"]
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "attach_s3_policy" {
  role       = aws_iam_role.eks_irsa_role.name
  policy_arn = aws_iam_policy.s3_access_policy.arn
}

###Output Values
output "eks_cluster_name" {
  value = aws_eks_cluster.eks_cluster.name
}

output "s3_bucket_name" {
  value = aws_s3_bucket.eks_s3.bucket
}
 