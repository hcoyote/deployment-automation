resource "aws_s3_bucket" "si" {
  bucket = local.si_bucket_name
  tags   = local.instance_tags
}

resource "aws_s3_bucket_acl" "si" {
  bucket = aws_s3_bucket.si.id
  acl    = "private"
}

resource "aws_s3_bucket_versioning" "si" {
  bucket = aws_s3_bucket.si.id
  versioning_configuration {
    status = "Disabled"
  }
}

resource "aws_s3_bucket_public_access_block" "si" {
  bucket = aws_s3_bucket.si.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# resource "aws_s3_bucket_ownership_controls" "si" {
  # bucket = aws_s3_bucket.si.id
# 
  # rule {
    #object_ownership = "BucketOwnerPreferred"
    # object_ownership = "BucketOwnerEnforced"
  # }
# }
