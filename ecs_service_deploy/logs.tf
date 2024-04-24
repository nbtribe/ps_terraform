# Set up CloudWatch group and log stream and retain logs for 30 days
resource "aws_cloudwatch_log_group" "cb_log_group" {
  name              = "/ecs/nb-demo-app"
  retention_in_days = 30

  tags = {
    Name = "nb-demo-log-group"
  }
}

resource "aws_cloudwatch_log_stream" "cb_log_stream" {
  name           = "nb-demo-log-stream"
  log_group_name = aws_cloudwatch_log_group.cb_log_group.name
}