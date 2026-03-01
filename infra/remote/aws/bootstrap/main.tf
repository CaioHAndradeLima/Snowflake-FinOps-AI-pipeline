locals {
  github_oidc_enabled = var.enable_github_oidc && var.github_repository != ""
  github_provider_arn = local.github_oidc_enabled ? (
    var.github_oidc_provider_arn != "" ? var.github_oidc_provider_arn : aws_iam_openid_connect_provider.github[0].arn
  ) : ""
  github_sub_patterns = [for ref in var.github_ref_patterns : "repo:${var.github_repository}:ref:${ref}"]
}

resource "aws_iam_openid_connect_provider" "github" {
  count = local.github_oidc_enabled && var.github_oidc_provider_arn == "" ? 1 : 0

  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
  tags            = var.tags
}

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

  dynamic "statement" {
    for_each = local.github_oidc_enabled ? [1] : []

    content {
      sid     = "AllowGitHubOIDC"
      effect  = "Allow"
      actions = ["sts:AssumeRoleWithWebIdentity"]

      principals {
        type        = "Federated"
        identifiers = [local.github_provider_arn]
      }

      condition {
        test     = "StringEquals"
        variable = "token.actions.githubusercontent.com:aud"
        values   = ["sts.amazonaws.com"]
      }

      condition {
        test     = "StringLike"
        variable = "token.actions.githubusercontent.com:sub"
        values   = local.github_sub_patterns
      }
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
