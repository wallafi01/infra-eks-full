resource "aws_iam_role" "cluster_autoscaler" {
  name               = "eks_cluster_autoscaler"
  assume_role_policy = data.aws_iam_policy_document.cluster_autoscaler_assume_role_policy.json
}

data "aws_iam_policy_document" "cluster_autoscaler_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Federated"
      identifiers = [data.aws_iam_openid_connect_provider.oidc_provider.arn]
    }
    condition {
      test     = "StringEquals"
      variable = "${replace(data.aws_eks_cluster.cluster.identity.0.oidc.0.issuer, "https://", "")}:sub"
      values   = ["system:serviceaccount:kube-system:cluster-autoscaler"]
    }
  }
}

resource "aws_iam_role_policy_attachment" "cluster_autoscaler" {
  role       = aws_iam_role.cluster_autoscaler.name
  policy_arn = "arn:aws:iam::aws:policy/AutoScalingFullAccess"
}



