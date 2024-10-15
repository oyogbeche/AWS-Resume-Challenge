//creation of dynamodb table
resource "aws_dynamodb_table" "count_table" {
  name         = "resume-count"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "ID"

  attribute {
    name = "ID"
    type = "S"
  }

  attribute {
    name = "views"
    type = "N"
  }

  global_secondary_index {
    name            = "visitor_views"
    hash_key        = "views"
    projection_type = "ALL"
    read_capacity   = 1
    write_capacity  = 1
  }

  tags = {
    Project = "cloud resume challenge"
  }
}

//Dynamodb Table Item
resource "aws_dynamodb_table_item" "table_item" {
  table_name = aws_dynamodb_table.count_table.name
  hash_key   = aws_dynamodb_table.count_table.hash_key

  item = <<ITEM
  {
  "ID": {"S": "0"},
  "views": {"N": "1"}
  }
  ITEM
}

//retrieve the current AWS region 
data "aws_region" "current" {}

//retrieve the current AWS account ID
data "aws_caller_identity" "current" {}

//lambda role
resource "aws_iam_role" "iam_for_lambda" {
  name = "iam_for_lambda"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}


//creation of iam role policy for lambda function
resource "aws_iam_policy" "iam_policy_for_resume_challenge" {
  name = "terraform_resume_challenge_policy"
  path = "/"
  policy = jsonencode(
    {
      "Version" : "2012-10-17",
      "Statement" : [
        {
          "Effect" : "Allow",
          "Action" : [
            "dynamodb:BatchGetItem",
            "dynamodb:GetItem",
            "dynamodb:Query",
            "dynamodb:Scan",
            "dynamodb:BatchWriteItem",
            "dynamodb:PutItem",
            "dynamodb:UpdateItem"
          ],
          "Resource" : "arn:aws:dynamodb:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:*"
        },
        {
          "Effect" : "Allow",
          "Action" : [
            "logs:CreateLogStream",
            "logs:PutLogEvents"
          ],
          "Resource" : "arn:aws:dynamodb:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:*"
        },
        {
          "Effect" : "Allow",
          "Action" : "logs:CreateLogGroup",
          "Resource" : "*"
        }
      ]
  })
}

//attaching the dynamodb policy to the lambda role
resource "aws_iam_role_policy_attachment" "attach_policy_to_role" {
  role       = aws_iam_role.iam_for_lambda.name
  policy_arn = aws_iam_policy.iam_policy_for_resume_challenge.arn
}

//zip python code
data "archive_file" "python_zip" {
  type        = "zip"
  source_file = "${path.module}/lambda/myfunction.py"
  output_path = "${path.module}/lambda/myfunction.zip"
}

//creation of the lambda function
resource "aws_lambda_function" "myfunction" {
  filename         = data.archive_file.python_zip.output_path
  function_name    = "resume_challenge_func"
  role             = aws_iam_role.iam_for_lambda.arn
  handler          = "myfunction.lambda_handler"
  source_code_hash = data.archive_file.python_zip.output_base64sha256
  runtime          = "python3.9"
  depends_on       = [aws_iam_role_policy_attachment.attach_policy_to_role]
  environment {
    variables = {
      databaseName = "resume-count"
    }
  }
}

//creation of the api gateway
resource "aws_apigatewayv2_api" "views_api" {
  name          = "views_api"
  protocol_type = "HTTP"
  cors_configuration {
    allow_credentials = false
    allow_headers     = []
    allow_methods = [
      "GET",
      "POST",
      "OPTIONS",
    ]
    allow_origins  = ["*"]
    expose_headers = []
    max_age        = 0
  }
}

//api gateway stage
resource "aws_apigatewayv2_stage" "views_api_st" {
  api_id      = aws_apigatewayv2_api.views_api.id
  name        = "default"
  auto_deploy = true
}

//api gateway integration
resource "aws_apigatewayv2_integration" "views_api_stage_integration" {
  api_id                 = aws_apigatewayv2_api.views_api.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.myfunction.invoke_arn
  integration_method     = "POST"
  payload_format_version = "2.0"
}

//api gateway route 
resource "aws_apigatewayv2_route" "views_api_route" {
  api_id    = aws_apigatewayv2_api.views_api.id
  route_key = "ANY /views"
  target    = "integrations/${aws_apigatewayv2_integration.views_api_stage_integration.id}"
}

//api gateway permission for lambda invocation
resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:invokeFunction"
  function_name = aws_lambda_function.myfunction.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.views_api.execution_arn}/*/*"
}

output "api_url" {
  value = "${aws_apigatewayv2_stage.views_api_st.invoke_url}/views"
}