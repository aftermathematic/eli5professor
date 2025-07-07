# Lambda function for the Twitter bot
module "twitter_bot_lambda" {
  count = local.deploy_lambda ? 1 : 0
  source = "./modules/lambda-function"

  function_name = "${var.app_name}-twitter-bot-${var.environment}"
  handler       = "src.main.lambda_handler"
  runtime       = "python3.9"
  timeout       = 300  # 5 minutes
  memory_size   = 512  # 512 MB

  s3_bucket = module.model_bucket.bucket_id
  s3_key    = "lambda/twitter_bot.zip"

  # Run every 15 minutes
  schedule_expression = "rate(15 minutes)"

  environment_variables = {
    ENVIRONMENT = var.environment
    # Reference secrets using the format ${SECRETS_MANAGER_SECRET_NAME}:${JSON_KEY}
    TWITTER_API_KEY             = "${aws_secretsmanager_secret.twitter_credentials.name}:TWITTER_API_KEY"
    TWITTER_API_SECRET          = "${aws_secretsmanager_secret.twitter_credentials.name}:TWITTER_API_SECRET"
    TWITTER_ACCESS_TOKEN        = "${aws_secretsmanager_secret.twitter_credentials.name}:TWITTER_ACCESS_TOKEN"
    TWITTER_ACCESS_TOKEN_SECRET = "${aws_secretsmanager_secret.twitter_credentials.name}:TWITTER_ACCESS_TOKEN_SECRET"
    TWITTER_BEARER_TOKEN        = "${aws_secretsmanager_secret.twitter_credentials.name}:TWITTER_BEARER_TOKEN"
    TWITTER_ACCOUNT_HANDLE      = "${aws_secretsmanager_secret.twitter_credentials.name}:TWITTER_ACCOUNT_HANDLE"
    TWITTER_USER_ID             = "${aws_secretsmanager_secret.twitter_credentials.name}:TWITTER_USER_ID"
    OPENAI_API_KEY              = "${aws_secretsmanager_secret.openai_credentials.name}:OPENAI_API_KEY"
    S3_BUCKET                   = module.model_bucket.bucket_id
  }

  tags = local.tags
}

# Lambda function for the API
module "api_lambda" {
  count = local.deploy_lambda ? 1 : 0
  source = "./modules/lambda-function"

  function_name = "${var.app_name}-api-${var.environment}"
  handler       = "src.app.lambda_handler"
  runtime       = "python3.9"
  timeout       = 30   # 30 seconds
  memory_size   = 256  # 256 MB

  s3_bucket = module.model_bucket.bucket_id
  s3_key    = "lambda/api.zip"

  # No schedule for the API Lambda, it will be triggered by API Gateway

  environment_variables = {
    ENVIRONMENT = var.environment
    OPENAI_API_KEY = "${aws_secretsmanager_secret.openai_credentials.name}:OPENAI_API_KEY"
    S3_BUCKET    = module.model_bucket.bucket_id
  }

  tags = local.tags
}

# API Gateway for the API Lambda
resource "aws_apigatewayv2_api" "api" {
  count = local.deploy_lambda ? 1 : 0
  name          = "${var.app_name}-api-${var.environment}"
  protocol_type = "HTTP"
  tags          = local.tags
}

resource "aws_apigatewayv2_stage" "api" {
  count = local.deploy_lambda ? 1 : 0
  api_id      = aws_apigatewayv2_api.api[0].id
  name        = "$default"
  auto_deploy = true
  tags        = local.tags
}

resource "aws_apigatewayv2_integration" "api" {
  count = local.deploy_lambda ? 1 : 0
  api_id             = aws_apigatewayv2_api.api[0].id
  integration_type   = "AWS_PROXY"
  integration_uri    = module.api_lambda[0].invoke_arn
  integration_method = "POST"
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "api" {
  count = local.deploy_lambda ? 1 : 0
  api_id    = aws_apigatewayv2_api.api[0].id
  route_key = "ANY /{proxy+}"
  target    = "integrations/${aws_apigatewayv2_integration.api[0].id}"
}

resource "aws_lambda_permission" "api" {
  count = local.deploy_lambda ? 1 : 0
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = module.api_lambda[0].function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.api[0].execution_arn}/*/*"
}

# Outputs for Lambda functions and API Gateway
output "twitter_bot_lambda_function_name" {
  description = "Name of the Twitter bot Lambda function"
  value       = local.deploy_lambda ? module.twitter_bot_lambda[0].function_name : "Not deployed"
}

output "twitter_bot_lambda_function_arn" {
  description = "ARN of the Twitter bot Lambda function"
  value       = local.deploy_lambda ? module.twitter_bot_lambda[0].function_arn : "Not deployed"
}

output "api_lambda_function_name" {
  description = "Name of the API Lambda function"
  value       = local.deploy_lambda ? module.api_lambda[0].function_name : "Not deployed"
}

output "api_lambda_function_arn" {
  description = "ARN of the API Lambda function"
  value       = local.deploy_lambda ? module.api_lambda[0].function_arn : "Not deployed"
}

output "api_gateway_url" {
  description = "URL of the API Gateway"
  value       = local.deploy_lambda ? aws_apigatewayv2_stage.api[0].invoke_url : "Not deployed"
}
