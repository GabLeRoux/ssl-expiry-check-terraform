variable "HOSTLIST" {}
variable "EXPIRY_BUFFER" {
  default = 5
}
variable "AWS_REGION" {
  default = "us-east-1"
}

provider "aws" {
  region = "${var.AWS_REGION}"
}

resource "aws_iam_role" "SSLExpiryRole" {
  name = "SSLExpiryRole"
  assume_role_policy = "${file("SSLExpiryRole.json")}"
}

resource "aws_iam_policy_attachment" "AWSLambdaBasicExecutionRole-attachment" {
  name = "SSLExpiryRolePolicy"
  roles = [
    "${aws_iam_role.SSLExpiryRole.name}"
  ]
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_lambda_function" "SSLExpiry" {
  description = ""
  function_name = "SSLExpiry"
  handler = "ssl_expiry_lambda.main"
  runtime = "python3.6"
  filename = "ssl-expiry-check.zip"
  timeout = 120
  source_code_hash = "${base64sha256(file("ssl-expiry-check.zip"))}"
  role = "${aws_iam_role.SSLExpiryRole.arn}"

  environment {
    variables = {
      HOSTLIST = "${var.HOSTLIST}"
      EXPIRY_BUFFER = "${var.EXPIRY_BUFFER}"
    }
  }
}

resource "aws_cloudwatch_event_rule" "SSLExpirySchedule" {
  name = "SSLExpirySchedule"
  depends_on = [
    "aws_lambda_function.SSLExpiry"
  ]
  schedule_expression = "rate(1 day)"
}

resource "aws_cloudwatch_event_target" "SSLExpiry" {
  target_id = "SSLExpiry"
  rule = "${aws_cloudwatch_event_rule.SSLExpirySchedule.name}"
  arn = "${aws_lambda_function.SSLExpiry.arn}"
}

resource "aws_lambda_permission" "SSLExpirySchedule" {
  statement_id = "AllowExecutionFromCloudWatch"
  action = "lambda:InvokeFunction"
  function_name = "${aws_lambda_function.SSLExpiry.function_name}"
  principal = "events.amazonaws.com"
  source_arn = "${aws_cloudwatch_event_rule.SSLExpirySchedule.arn}"
}
