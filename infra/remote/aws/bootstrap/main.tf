data "aws_iam_policy_document" "execution_role_assume" {
  statement {
    sid     = "AllowTrustedPrincipals"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "AWS"
      identifiers = var.trusted_principal_arns
    }
  }
}

resource "aws_iam_role" "terraform_execution_dev" {
  name               = var.dev_role_name
  assume_role_policy = data.aws_iam_policy_document.execution_role_assume.json
  tags               = var.tags
}

resource "aws_iam_role" "terraform_execution_prod" {
  name               = var.prod_role_name
  assume_role_policy = data.aws_iam_policy_document.execution_role_assume.json
  tags               = var.tags
}

locals {
  role_policy_pairs = {
    for pair in setproduct(
      [aws_iam_role.terraform_execution_dev.name, aws_iam_role.terraform_execution_prod.name],
      var.managed_policy_arns
      ) : "${pair[0]}|${pair[1]}" => {
      role       = pair[0]
      policy_arn = pair[1]
    }
  }
}

resource "aws_iam_role_policy_attachment" "execution_managed_policies" {
  for_each = local.role_policy_pairs

  role       = each.value.role
  policy_arn = each.value.policy_arn
}
