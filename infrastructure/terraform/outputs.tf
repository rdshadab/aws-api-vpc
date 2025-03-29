output "user_pool_id" {
  value = aws_cognito_user_pool.vpc_api_user_pool.id
}

output "user_pool_client_id" {
  value = aws_cognito_user_pool_client.vpc_api_client.id
}

output "lambda_role_arn" {
  value = aws_iam_role.lambda_role.arn
}

output "api_gateway_role_arn" {
  value = aws_iam_role.api_gateway_role.arn
}

output "api_endpoint" {
  value = aws_api_gateway_deployment.deploy.invoke_url
}