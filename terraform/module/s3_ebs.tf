# Creates a private S3 bucket, useful for storing application data, logs, or backups.
resource "aws_s3_bucket" "application_bucket" {
  bucket        = "s3-aws-terraform-explore" # S3 bucket names must be globally unique
  force_destroy = true                       # Allows deletion even if files exist (for dev/test buckets)

  tags = {
    Name        = "s3-bucket"
    Project     = "aws-terraform-explore"
  }
}

resource "aws_s3_bucket_versioning" "this" {
  bucket = aws_s3_bucket.application_bucket.id
  versioning_configuration {
    status = "Suspended"  # Save costs; versioning costs extra
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  bucket = aws_s3_bucket.application_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"  # Free SSE encryption
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "this" {
  bucket = aws_s3_bucket.application_bucket.id

  rule {
    id     = "transition-to-infrequent-access"
    status = "Enabled"

    transition {
      days          = 30
      storage_class = "STANDARD_IA"  # Cheaper after 30 days
    }

    expiration {
      days = 365  # Optional: expire objects after 1 year to save space
    }

    noncurrent_version_expiration {
      days = 30
    }
  }
}

# Creates a standalone General Purpose SSD (gp3) EBS volume.
# This volume can be dynamically provisioned to pods in EKS using the EBS CSI Driver.
resource "aws_ebs_volume" "database_volume" {
  availability_zone = module.vpc.azs[0]  # Must be in the same AZ as the node that will use it.
  size              = 8                  # minimum size in GB (8GB is the smallest allowed)
  type              = "gp3"              # cheapest general purpose SSD volume

  # tune IOPS and throughput to lowest values for cost savings
  iops              = 300           # minimum for gp3 (300 IOPS)
  throughput        = 125           # minimum throughput (MB/s)

  tags = {
    Name    = "ebs"
    Project = "aws-terraform-explore"
  }
}
