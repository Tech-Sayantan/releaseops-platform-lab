locals {
  github_oidc_url = "https://token.actions.githubusercontent.com"
  github_subject  = "repo:${var.github_repository}:ref:refs/heads/${var.github_branch}"
}

resource "aws_iam_openid_connect_provider" "github" {
  url = local.github_oidc_url

  client_id_list = [
    "sts.amazonaws.com"
  ]

  tags = merge(var.tags, {
    Name      = "${var.name_prefix}-github-oidc"
    Component = "iam"
  })
}

data "aws_iam_policy_document" "github_actions_assume_role" {
  statement {
    sid     = "AllowGitHubActionsAssumeRoleWithWebIdentity"
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type = "Federated"
      identifiers = [
        aws_iam_openid_connect_provider.github.arn
      ]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = [local.github_subject]
    }
  }
}

resource "aws_iam_role" "github_actions" {
  name = "${var.name_prefix}-${var.role_name_suffix}"

  assume_role_policy   = data.aws_iam_policy_document.github_actions_assume_role.json
  max_session_duration = 3600

  tags = merge(var.tags, {
    Name      = "${var.name_prefix}-${var.role_name_suffix}"
    Component = "iam"
  })
}
data "aws_iam_policy_document" "terraform_permissions" {
  statement {
    sid    = "AllowTerraformBackendAccess"
    effect = "Allow"

    actions = [
      "s3:GetBucketVersioning",
      "s3:GetObject",
      "s3:ListBucket",
      "s3:PutObject",
      "s3:DeleteObject",
      "dynamodb:GetItem",
      "dynamodb:PutItem",
      "dynamodb:DeleteItem",
      "dynamodb:DescribeTable"
    ]

    resources = ["*"]
  }

  statement {
    sid    = "AllowPlatformInfrastructureManagement"
    effect = "Allow"

    actions = [
      "ec2:*",
      "rds:*",
      "ecr:*",
      "sqs:*",
      "eks:*",
      "iam:*",
      "kms:*",
      "secretsmanager:*",
      "elasticloadbalancing:*",
      "autoscaling:*",
      "cloudwatch:*",
      "logs:*",
      "sts:GetCallerIdentity"
    ]

    resources = ["*"]
  }
}

resource "aws_iam_policy" "terraform_permissions" {
  name        = "${var.name_prefix}-${var.role_name_suffix}-policy"
  description = "Allows GitHub Actions Terraform workflow to manage ReleaseOps lab infrastructure."
  policy      = data.aws_iam_policy_document.terraform_permissions.json

  tags = merge(var.tags, {
    Name      = "${var.name_prefix}-${var.role_name_suffix}-policy"
    Component = "iam"
  })
}

resource "aws_iam_role_policy_attachment" "terraform_permissions" {
  role       = aws_iam_role.github_actions.name
  policy_arn = aws_iam_policy.terraform_permissions.arn
}