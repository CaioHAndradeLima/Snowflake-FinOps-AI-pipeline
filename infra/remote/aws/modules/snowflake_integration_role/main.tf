locals {
  prefix_arns = [
    for prefix in var.allowed_prefixes :
    "${var.bucket_arn}/${trim(prefix, "/")}${trim(prefix, "/") == "*" ? "" : "/*"}"
  ]
}

data "aws_iam_policy_document" "assume_role" {
  statement {
    sid     = "AllowSnowflakeAssumeRole"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "AWS"
      identifiers = [var.trusted_principal_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "sts:ExternalId"
      values   = [var.external_id]
    }
  }
}

resource "aws_iam_role" "this" {
  name               = var.role_name
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
  tags               = var.tags
}

data "aws_iam_policy_document" "access" {
  statement {
    sid    = "AllowListBucket"
    effect = "Allow"
    actions = [
      "s3:GetBucketLocation",
      "s3:ListBucket",
    ]
    resources = [var.bucket_arn]
  }

  statement {
    sid    = "AllowObjectAccess"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
    ]
    resources = local.prefix_arns
  }

  statement {
    sid    = "AllowKmsForS3Objects"
    effect = "Allow"
    actions = [
      "kms:Decrypt",
      "kms:Encrypt",
      "kms:GenerateDataKey",
      "kms:DescribeKey",
    ]
    resources = [var.kms_key_arn]
  }
}

resource "aws_iam_role_policy" "this" {
  name   = "${var.role_name}-policy"
  role   = aws_iam_role.this.id
  policy = data.aws_iam_policy_document.access.json
}
