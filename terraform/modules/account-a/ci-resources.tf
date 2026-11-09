resource "aws_ecr_repository" "ci" {
  name         = "${var.name_prefix}-app"
  force_delete = false
  image_scanning_configuration { scan_on_push = true }
  tags = local.tags
}

resource "aws_cloudwatch_log_group" "ci" {
  name              = "/ecs/${var.name_prefix}"
  retention_in_days = 7
  tags              = local.tags
}

locals {
  ecs_trust = jsonencode({
    Version   = "2012-10-17"
    Statement = [{ Effect = "Allow", Action = "sts:AssumeRole", Principal = { Service = "ecs-tasks.amazonaws.com" } }]
  })
}

resource "aws_iam_role" "ecs_execution" {
  name               = "${var.name_prefix}-ecs-execution"
  assume_role_policy = local.ecs_trust
  tags               = local.tags
}

resource "aws_iam_role" "ecs_task" {
  name               = "${var.name_prefix}-ecs-task"
  assume_role_policy = local.ecs_trust
  tags               = local.tags
}

resource "aws_iam_role_policy" "ecs_execution" {
  name = "pull-assignment-image-and-write-logs"
  role = aws_iam_role.ecs_execution.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      { Effect = "Allow", Action = ["ecr:GetAuthorizationToken"], Resource = "*" },
      { Effect = "Allow", Action = ["ecr:BatchCheckLayerAvailability", "ecr:BatchGetImage", "ecr:GetDownloadUrlForLayer"], Resource = aws_ecr_repository.ci.arn },
      { Effect = "Allow", Action = ["logs:CreateLogStream", "logs:PutLogEvents"], Resource = "${aws_cloudwatch_log_group.ci.arn}:*" },
    ]
  })
}

resource "aws_ecs_cluster" "ci" {
  name = var.name_prefix
  tags = local.tags
}

resource "aws_ecs_task_definition" "ci" {
  family                   = "${var.name_prefix}-app"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn
  container_definitions = jsonencode([{
    name      = "app"
    image     = "${aws_ecr_repository.ci.repository_url}:latest"
    essential = true
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        awslogs-group         = aws_cloudwatch_log_group.ci.name
        awslogs-region        = var.aws_region
        awslogs-stream-prefix = "app"
      }
    }
  }])
  tags = local.tags
}

resource "aws_ecs_service" "ci" {
  name            = "${var.name_prefix}-app"
  cluster         = aws_ecs_cluster.ci.arn
  task_definition = aws_ecs_task_definition.ci.arn
  launch_type     = "FARGATE"
  desired_count   = 0
  network_configuration {
    subnets          = [aws_subnet.assignment.id]
    security_groups  = [aws_security_group.assignment.id]
    assign_public_ip = true
  }
  tags       = local.tags
  depends_on = [aws_route_table_association.assignment, aws_iam_role_policy.ecs_execution]
  lifecycle {
    ignore_changes = [task_definition, desired_count]
  }
}
