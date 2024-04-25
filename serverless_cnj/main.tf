terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 4.64.0"
    }
  }
}

provider "aws" {

}

data "aws_caller_identity" "current" {}

data "archive_file" "LambdaZipFile" {
  type        = "zip"
  source_file = "${path.module}/src/app.py"
  output_path = "${path.module}/app.zip"
}

## Create Layer for Python requests
resource "aws_lambda_layer_version" "python_requests_layer" {
  filename   = "src/requests.zip"
  layer_name = "python_requests_layer"

  compatible_runtimes = ["python3.10"]
}
## Create SNS to send msg
resource "aws_sns_topic" "user_updates_topic" {
  name = "CNJ-topic"
}
##Create Subscription
resource "aws_sns_topic_subscription" "user_email_target" {
  topic_arn = aws_sns_topic.user_updates_topic.arn
  protocol  = "email"
  endpoint  = "<<EMAIL_TARGET>>"
}

resource "aws_lambda_function" "scheduled_function" {
  function_name = "Scheduled-CN-Joke"
  filename      = data.archive_file.LambdaZipFile.output_path
  handler       = "app.lambda_handler"
  role          = aws_iam_role.iam_for_lambda.arn
  runtime       = "python3.10"
  memory_size   = 128
  timeout       = 30
  layers        =[aws_lambda_layer_version.python_requests_layer.arn]
  environment {
    variables= {
      TOPIC_ARN = aws_sns_topic.user_updates_topic.arn
    }
  }
}

resource "aws_iam_role" "scheduler_role" {
  name = "EventBridgeSchedulerRole"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "scheduler.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "eventbridge_invoke_policy" {
  name = "EventBridgeInvokeLambdaPolicy"
  role = aws_iam_role.scheduler_role.id
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Sid" : "AllowEventBridgeToInvokeLambda",
        "Action" : [
          "lambda:InvokeFunction"
        ],
        "Effect" : "Allow",
        "Resource" : aws_lambda_function.scheduled_function.arn
      }
    ]
  })
}

resource "aws_iam_role" "iam_for_lambda" {
  name = "LambdaExecutionRole"
  assume_role_policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Action" : "sts:AssumeRole",
        "Principal" : {
          "Service" : "lambda.amazonaws.com"
        },
        "Effect" : "Allow",
        "Sid" : ""
      }
    ]
  })
}

resource "aws_iam_role_policy" "lambda_logs_policy" {
  name = "PublishLogsPolicy"
  role = aws_iam_role.iam_for_lambda.id
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Sid" : "AllowLambdaFunctionToCreateLogs",
        "Action" : [
          "logs:*"
        ],
        "Effect" : "Allow",
        "Resource" : [
          "arn:aws:logs:*:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/${aws_lambda_function.scheduled_function.function_name}:*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy" "lambda_SNS_policy" {
  name = "SNSAccess"
  role = aws_iam_role.iam_for_lambda.id
  policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": [
                "sns:*"
            ],
            "Effect": "Allow",
            "Resource": "*"
        }
    ]
})
}

resource "aws_scheduler_schedule" "invoke_lambda_schedule" {
  name = "InvokeLambdaSchedule"
  flexible_time_window {
    mode = "OFF"
  }
  schedule_expression = "rate(1 hour)"
  target {
    arn      = aws_lambda_function.scheduled_function.arn
    role_arn = aws_iam_role.scheduler_role.arn
    input    = jsonencode({ "input" : "This message was sent using EventBridge Scheduler!" })
  }
}

output "ScheduleTargetFunction" {
  value       = aws_lambda_function.scheduled_function.arn
  description = "The ARN of the Lambda function being invoked"
}

output "ScheduleName" {
  value       = aws_scheduler_schedule.invoke_lambda_schedule.name
  description = " EventBridge Schedule Name"
}