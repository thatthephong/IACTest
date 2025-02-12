# EC2andEKS
🔹 Explanation
VPC with Public & Private Subnets
Public Subnets: Have internet access via Internet Gateway (IGW).
Private Subnets: Use NAT Gateway to access the internet securely.
EKS Cluster Setup
EKS Cluster: Fully managed Kubernetes control plane.
Node Group: Uses EC2 worker nodes in private subnets for security.
S3 Storage Bucket
Creates an S3 bucket to store logs, backups, or container data.

🚀 Key Features
✅ High Availability

Uses 3 Availability Zones (AZs) for resilience.
NAT Gateway per AZ ensures redundancy.
Worker nodes auto-scale (min: 2, max: 6).
✅ Resilience & Security

Worker nodes in private subnets for security.
Pods use IAM Role (IRSA) to access AWS securely.
✅ Optimized Networking

NAT Gateway per AZ prevents single-point failure.
Private & Public subnets for security & internet access.
✅ IAM Roles for Service Accounts (IRSA)

Pods get secure S3 access without root credentials.
IRSA allows fine-grained permissions per service.