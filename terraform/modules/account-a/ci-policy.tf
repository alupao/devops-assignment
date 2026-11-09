resource "aws_iam_user_policy" "ci_pipeline" {
  name = "ci-least-privilege-pipeline"
  user = aws_iam_user.account_a["ci"].name
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "EcrPushSingleRepository"
        Effect   = "Allow"
        Action   = ["ecr:BatchCheckLayerAvailability", "ecr:BatchGetImage", "ecr:CompleteLayerUpload", "ecr:InitiateLayerUpload", "ecr:PutImage", "ecr:UploadLayerPart"]
        Resource = aws_ecr_repository.ci.arn
      },
      {
        Sid      = "EcrAuthenticateRegistry"
        Effect   = "Allow"
        Action   = ["ecr:GetAuthorizationToken"]
        Resource = "*"
      },
      {
        Sid      = "EcsRegisterTaskDefinition"
        Effect   = "Allow"
        Action   = ["ecs:RegisterTaskDefinition"]
        Resource = "${aws_ecs_task_definition.ci.arn_without_revision}:*"
      },
      {
        Sid      = "EcsUpdateSingleService"
        Effect   = "Allow"
        Action   = ["ecs:UpdateService"]
        Resource = aws_ecs_service.ci.arn
        Condition = {
          ArnEquals = { "ecs:cluster" = aws_ecs_cluster.ci.arn }
          ArnLike   = { "ecs:task-definition" = "${aws_ecs_task_definition.ci.arn_without_revision}:*" }
        }
      },
      {
        Sid      = "EcsDescribeDeploymentTarget"
        Effect   = "Allow"
        Action   = ["ecs:DescribeServices"]
        Resource = aws_ecs_service.ci.arn
      },
      {
        Sid       = "EcsPassTaskRoles"
        Effect    = "Allow"
        Action    = ["iam:PassRole"]
        Resource  = [aws_iam_role.ecs_execution.arn, aws_iam_role.ecs_task.arn]
        Condition = { StringEquals = { "iam:PassedToService" = "ecs-tasks.amazonaws.com" } }
      },
      {
        Sid      = "S3ReadArtifactsBucket"
        Effect   = "Allow"
        Action   = ["s3:GetObject"]
        Resource = "${aws_s3_bucket.artifacts.arn}/*"
      },
      {
        Sid      = "S3ListArtifactsBucket"
        Effect   = "Allow"
        Action   = ["s3:ListBucket"]
        Resource = aws_s3_bucket.artifacts.arn
      },
    ]
  })
}
