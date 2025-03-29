
# # S3 Bucket for Terraform State
# resource "aws_s3_bucket" "terraform_state" {
#   bucket = "allianz-vpc-state-bucket"

#   versioning {
#     enabled = true
#   }
# }


terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }

  backend "s3" {
    bucket = "allianz-vpc-state-bucket" 
    key    = "terraform.tfstate"
    region = "us-east-1" 
  }
}

provider "aws" {
  region = "us-east-1"
  profile = "default"
}



# DynamoDB Table for VPC Metadata
resource "aws_dynamodb_table" "vpc_metadata" {
  name           = "VpcMetadata"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "vpc_id"

  attribute {
    name = "vpc_id"
    type = "S"
  }
}

# Cognito User Pool
resource "aws_cognito_user_pool" "vpc_api_user_pool" {
  name = "vpc-api-user-pool"
}

# Cognito App Client
# resource "aws_cognito_user_pool_client" "vpc_api_client" {
#   name         = "vpc-api-client"
#   user_pool_id = aws_cognito_user_pool.vpc_api_user_pool.id
# }

resource "aws_cognito_user_pool_client" "vpc_api_client" {
  name         = "vpc-api-client"
  user_pool_id = aws_cognito_user_pool.vpc_api_user_pool.id

  id_token_validity   = 24 # Example: 60 minutes
  access_token_validity = 24 # Example: 60 minutes
  refresh_token_validity =  30 # Example: 30 days (in seconds, convert to minutes if needed)
  # refresh_token_validity = 43200 # Example: 30 days (in minutes) - Check AWS Docs for units
  token_validity_units {
    access_token  = "hours"
    id_token      = "hours"
    refresh_token = "days"
  }

  # ... other configurations ...
}

# IAM Role for Lambda Functions
resource "aws_iam_role" "lambda_role" {
  name = "vpc-api-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Effect = "Allow",
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

# IAM Policy for Lambda Functions
resource "aws_iam_policy" "lambda_policy" {
  name = "vpc-api-lambda-policy"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket",
          "ec2:CreateVpc",
          "ec2:CreateSubnet",
          "ec2:CreateInternetGateway",
          "ec2:AttachInternetGateway",
          "ec2:CreateRouteTable",
          "ec2:CreateRoute",
          "ec2:AssociateRouteTable",
          "ec2:DescribeVpcs",
          "ec2:DescribeSubnets",
          "ec2:DescribeInternetGateways",
          "ec2:DescribeRouteTables"
        ],
        Effect   = "Allow",
        Resource = "*"
      }
    ]
  })
}

# Attach Policy to Role
resource "aws_iam_role_policy_attachment" "lambda_policy_attachment" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_policy.arn
}

# IAM Role for API Gateway
resource "aws_iam_role" "api_gateway_role" {
  name = "vpc-api-api-gateway-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Effect = "Allow",
      Principal = {
        Service = "apigateway.amazonaws.com"
      }
    }]
  })
}


resource "aws_api_gateway_account" "main" {
  cloudwatch_role_arn = aws_iam_role.api_gateway_role.arn
}
# IAM Policy for API Gateway to Invoke Lambda
resource "aws_iam_policy" "api_gateway_policy" {
  name = "vpc-api-api-gateway-policy"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "lambda:InvokeFunction",
      Effect = "Allow",
      Resource = "*"
    }]
  })
}

# Attach Policy to Role
resource "aws_iam_role_policy_attachment" "api_gateway_policy_attachment" {
  role       = aws_iam_role.api_gateway_role.name
  policy_arn = aws_iam_policy.api_gateway_policy.arn
}


resource "aws_iam_role_policy_attachment" "main" {
  role       = aws_iam_role.api_gateway_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonAPIGatewayPushToCloudWatchLogs"
}


# Lambda Function for Create VPC
resource "aws_lambda_function" "create_vpc" {
  function_name = "create-vpc-lambda"
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.9"
  role          = aws_iam_role.lambda_role.arn

  filename      = "../../api/api_lambda_functions_create_vpc.zip"
  source_code_hash = filebase64sha256("../../api/api_lambda_functions_create_vpc.zip")

  timeout = 300
  memory_size = 512

  environment {
    variables = {
      TF_DATA_DIR = "/tmp"
    }
  }

}

# Lambda Function for Get VPC
resource "aws_lambda_function" "get_vpc" {
  function_name = "get-vpc-lambda"
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.9"
  role          = aws_iam_role.lambda_role.arn

  filename      = "../../api/api_lambda_functions_get_vpc.zip"
  source_code_hash = filebase64sha256("../../api/api_lambda_functions_get_vpc.zip")

  timeout = 30
  memory_size = 256
}




# API Gateway
resource "aws_api_gateway_rest_api" "vpc_api" {
  name = "VPC_API"
}



# resource "aws_lambda_permission" "api_gateway_create_vpc" {
#   statement_id  = "AllowAPIGatewayInvoke"
#   action        = "lambda:InvokeFunction"
#   function_name = aws_lambda_function.create_vpc.arn
#   principal     = "apigateway.amazonaws.com"

#   source_arn = "${aws_api_gateway_rest_api.vpc_api.execution_arn}/*/*"
# }

resource "aws_lambda_permission" "api_gateway_get_vpc" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.get_vpc.arn
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_api_gateway_rest_api.vpc_api.execution_arn}/*/*"
}
# Cognito Authorizer
resource "aws_api_gateway_authorizer" "cognito_auth" {
  name            = "cognito-authorizer"
  rest_api_id     = aws_api_gateway_rest_api.vpc_api.id
  type            = "COGNITO_USER_POOLS"
  identity_source = "method.request.header.Authorization"
  provider_arns   = [aws_cognito_user_pool.vpc_api_user_pool.arn]
}

# API Gateway Resource: /vpcs
resource "aws_api_gateway_resource" "vpcs" {
  rest_api_id = aws_api_gateway_rest_api.vpc_api.id
  parent_id   = aws_api_gateway_rest_api.vpc_api.root_resource_id
  path_part   = "vpcs"
}

# API Gateway Resource: /vpcs/{vpc_id}
resource "aws_api_gateway_resource" "vpc_by_id" {
  rest_api_id = aws_api_gateway_rest_api.vpc_api.id
  parent_id   = aws_api_gateway_resource.vpcs.id
  path_part   = "{vpc_id}"
}

# API Gateway Method: POST /vpcs
resource "aws_api_gateway_method" "create_vpc_method" {
  rest_api_id   = aws_api_gateway_rest_api.vpc_api.id
  resource_id   = aws_api_gateway_resource.vpcs.id
  http_method   = "POST"
  authorization = "COGNITO_USER_POOLS"
  authorizer_id = aws_api_gateway_authorizer.cognito_auth.id
}

# API Gateway Method: GET /vpcs/{vpc_id}
resource "aws_api_gateway_method" "get_vpc_method" {
  rest_api_id   = aws_api_gateway_rest_api.vpc_api.id
  resource_id   = aws_api_gateway_resource.vpc_by_id.id
  http_method   = "GET"
  authorization = "COGNITO_USER_POOLS"
  authorizer_id = aws_api_gateway_authorizer.cognito_auth.id
}

# API Gateway Integration: POST /vpcs
# resource "aws_api_gateway_integration" "create_vpc_integration" {
#   rest_api_id = aws_api_gateway_rest_api.vpc_api.id
#   resource_id = aws_api_gateway_resource.vpcs.id
#   http_method = aws_api_gateway_method.create_vpc_method.http_method

#   integration_http_method = "POST"
#   type                    = "AWS_PROXY"
#   uri                     = aws_lambda_function.create_vpc.invoke_arn
# }

resource "aws_api_gateway_integration" "create_vpc_integration" {
  rest_api_id = aws_api_gateway_rest_api.vpc_api.id
  resource_id = aws_api_gateway_resource.vpcs.id
  http_method = aws_api_gateway_method.create_vpc_method.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.trigger_vpc_workflow.invoke_arn
}

# API Gateway Integration: GET /vpcs/{vpc_id}
resource "aws_api_gateway_integration" "get_vpc_integration" {
  rest_api_id = aws_api_gateway_rest_api.vpc_api.id
  resource_id = aws_api_gateway_resource.vpc_by_id.id
  http_method = aws_api_gateway_method.get_vpc_method.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.get_vpc.invoke_arn
}

# API Gateway Deployment
resource "aws_api_gateway_deployment" "deploy" {
  rest_api_id = aws_api_gateway_rest_api.vpc_api.id

  depends_on = [
    aws_api_gateway_integration.create_vpc_integration,
    aws_api_gateway_integration.get_vpc_integration,
  ]

  stage_name = "prod"
}

# resource "aws_api_gateway_stage" "prod" {
#   deployment_id = aws_api_gateway_deployment.deploy.id
#   rest_api_id   = aws_api_gateway_rest_api.vpc_api.id
#   stage_name    = "prod"

# #   execution_log_settings {
# #     log_group_arn = aws_cloudwatch_log_group.api_gateway_execution_logs.arn
# #     logging_level = "INFO"
# #     data_trace    = true
# #   }

#   access_log_settings {
#     destination_arn = aws_cloudwatch_log_group.api_gateway_access_logs.arn
#     format          = "$context.identity.sourceIp ..."
#   }
# }

# resource "aws_cloudwatch_log_group" "api_gateway_access_logs" {
#   name              = "/aws/api_gateway/${aws_api_gateway_rest_api.vpc_api.name}/access_logs"
#   retention_in_days = 7
# }

# resource "aws_cloudwatch_log_group" "api_gateway_execution_logs" {
#   name              = "/aws/api_gateway/${aws_api_gateway_rest_api.vpc_api.name}/execution_logs"
#   retention_in_days = 7
# }


resource "aws_iam_role" "trigger_vpc_workflow_role" {
  name = "triggerVpcWorkflowRole"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Effect = "Allow"
        Sid = ""
      },
    ]
  })
}

# resource "aws_iam_policy" "trigger_vpc_workflow_policy" {
#   name        = "triggerVpcWorkflowPolicy"
#   description = "Policy to allow triggering Step Functions"
#   policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       {
#         Effect   = "Allow"
#         Action   = "states:StartExecution"
#         Resource = aws_sfn_state_machine.vpc_workflow.arn
#       }
#     ]
#   })
# }

# resource "aws_iam_policy" "vpc_workflow_policy" {
#   # ...
#   policy = jsonencode({
#     # ...
#     Statement = [
#       {
#         Effect   = "Allow"
#         Action   = "lambda:InvokeFunction"
#         Resource = aws_lambda_function.create_vpc.arn
#       }
#     ]
#   })
# }

# resource "aws_iam_role_policy_attachment" "trigger_vpc_workflow_attach" {
#   role       = aws_iam_role.trigger_vpc_workflow_role.name
#   policy_arn = aws_iam_policy.trigger_vpc_workflow_policy.arn
# }

# resource "aws_lambda_function" "trigger_vpc_workflow" {
#   function_name = "trigger-vpc-workflow"
#   runtime       = "python3.9" # Or your desired runtime
#   handler       = "trigger-vpc-workflow.lambda_handler"
#   memory_size   = 128
#   timeout       = 30
#   role          = aws_iam_role.trigger_vpc_workflow_role.arn
#   filename      = "trigger-vpc-workflow.zip" # Ensure your ZIP is named correctly and contains trigger-vpc-workflow.py

#   environment {
#     variables = {
#       VPC_WORKFLOW_ARN = aws_sfn_state_machine.vpc_workflow.arn
#     }
#   }
# }

# data "archive_file" "trigger_vpc_workflow_zip" {
#   type        = "zip"
#   source_file = "trigger-vpc-workflow.py"
#   output_path = "trigger-vpc-workflow.zip"
# }



resource "aws_iam_role" "vpc_workflow_role" {
  name = "vpcWorkflowRole"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Principal = {
          Service = "states.amazonaws.com"
        }
        Effect = "Allow"
        Sid = ""
      },
    ]
  })
}

resource "aws_iam_policy" "vpc_workflow_policy" {
  name        = "vpcWorkflowPolicy"
  description = "Policy to allow invoking the VPC creation Lambda"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "lambda:InvokeFunction"
        Resource = "arn:aws:lambda:us-east-1:952399911041:function:create-vpc-lambda" # Replace
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "vpc_workflow_attach" {
  role       = aws_iam_role.vpc_workflow_role.name
  policy_arn = aws_iam_policy.vpc_workflow_policy.arn
}

resource "aws_sfn_state_machine" "vpc_workflow" {
  name     = "VpcCreationWorkflow"
  role_arn = aws_iam_role.vpc_workflow_role.arn
  definition = jsonencode({
    Comment = "Invoke the existing VPC creation Lambda function"
    StartAt = "InvokeVpcLambda"
    States = {
      InvokeVpcLambda = {
        Type = "Task"
        Resource = "arn:aws:states:::lambda:invoke"
        Parameters = {
          FunctionName = "arn:aws:lambda:us-east-1:952399911041:function:create-vpc-lambda"
          Payload = "$$.Input"
        }
        End = true
      }
    }
  })
}