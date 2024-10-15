//creation of s3 bucket for remote state
resource "aws_s3_bucket" "terraform_remote_state" {
  bucket = "oyogbeche-resume-terraform-state"
  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_ownership_controls" "terraform_remote_state_own" {
  bucket = aws_s3_bucket.terraform_remote_state.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_acl" "terraform_remote_state_acl" {
  depends_on = [aws_s3_bucket_ownership_controls.terraform_remote_state_own]

  bucket = aws_s3_bucket.terraform_remote_state.id
  acl    = "private"
}

resource "aws_s3_bucket_versioning" "terraform_bucket_version" {
  bucket = aws_s3_bucket.terraform_remote_state.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_remote_state_config" {
  bucket = aws_s3_bucket.terraform_remote_state.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

//creation of dynamodb for state locking
resource "aws_dynamodb_table" "state_locking" {
  name         = "terraform-state-locking"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }
}

resource "aws_iam_role" "terraform_role" {
  name = "iam-for-terraform"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "iam.amazonaws.com"
        }
      },
    ]
  })

  tags = {
    name = "terraform state"
  }
}

resource "aws_iam_policy" "terraform_policy" {
  name = "policy_for_terraform"
  path = "/"
  policy = jsonencode(
    {
      "Version" : "2012-10-17",
      "Statement" : [
        {
          "Effect" : "Allow",
          "Action" : "s3:ListBucket",
          "Resource" : "${aws_s3_bucket.terraform_remote_state.arn}"
        },
        {
          "Effect" : "Allow",
          "Action" : ["s3:GetObject", "s3:PutObject"],
          "Resource" : "${aws_s3_bucket.terraform_remote_state.arn}"
        },
        {
          "Effect" : "Deny",
          "Action" : "s3:DeleteBucket",
          "Resource" : "${aws_s3_bucket.terraform_remote_state.arn}"
        }
      ]
  })
}

resource "aws_iam_policy" "terraform_policy_for_dyanamodb" {
  name = "dynamodb_policy_for_terraform"
  path = "/"
  policy = jsonencode(
    {
      "Version" : "2012-10-17",
      "Statement" : [
        {
          "Effect" : "Allow",
          "Action" : [
            "dynamodb:DescribeTable",
            "dynamodb:GetItem",
            "dynamodb:PutItem",
            "dynamodb:DeleteItem"
          ],
          "Resource" : "arn:aws:dynamodb:*:*:table/terraform-state-locking"
        }
      ]
  })
}

resource "aws_iam_role_policy_attachment" "terraform_policy_attachment" {
  role       = aws_iam_role.terraform_role.name
  policy_arn = aws_iam_policy.terraform_policy.arn
}

resource "aws_iam_role_policy_attachment" "terraform_policy_attachment_dynamodb" {
  role       = aws_iam_role.terraform_role.name
  policy_arn = aws_iam_policy.terraform_policy_for_dyanamodb.arn
}