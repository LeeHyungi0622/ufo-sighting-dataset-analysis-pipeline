resource "aws_api_gateway_rest_api" "kinesis_api" {
    name        = "KinesisAPI"
    description = "외부로부터 전송되는 데이터를 Kinesis stream으로 전달해주는 API"
}

# AWS API GATEWAY path 설정 
resource "aws_api_gateway_resource" "kinesis_api_resource_check" {
  rest_api_id = aws_api_gateway_rest_api.kinesis_api.id
  parent_id   = aws_api_gateway_rest_api.kinesis_api.root_resource_id
  path_part   = "v1"
}

// AWS API GATEWAY 리소스의 method 정의(GET, POST 등)
resource "aws_api_gateway_method" "kinesis_api_post" {
  authorization = "NONE"
  http_method   = "POST"
  resource_id   = aws_api_gateway_resource.kinesis_api_resource_check.id
  rest_api_id   = aws_api_gateway_rest_api.kinesis_api.id
}

# AWS API GATEWAY와 통합할 AWS service 정의
resource "aws_api_gateway_integration" "kinesis_api_post" {
  http_method = aws_api_gateway_method.kinesis_api_post.http_method
  resource_id = aws_api_gateway_resource.kinesis_api_resource_check.id
  rest_api_id = aws_api_gateway_rest_api.kinesis_api.id
  type        = "AWS"
  integration_http_method = aws_api_gateway_method.kinesis_api_post.http_method
  uri = "arn:aws:apigateway:ap-northeast-2:kinesis:action/PutRecord"
  # Transforms the incoming XML request to JSON
  passthrough_behavior = "WHEN_NO_TEMPLATES"
  credentials = aws_iam_role.apigateway_role.arn
  request_parameters = {
    "integration.request.header.Content-Type" = "'application/x-amz-json-1.1'"
  }
  # Request template
  request_templates = {
    "application/json" = <<EOF
#set($enter = "
") 
#set($json = "$input.json('$')$enter")
{
    "Data": "$util.base64Encode("$json")",
    "PartitionKey": "$input.params('X-Amzn-Trace-Id')",
    "StreamName": "project-stream"
}
EOF
}
}

# API Gateway Response 
resource "aws_api_gateway_method_response" "kinesis_api_ok" {
  rest_api_id = aws_api_gateway_rest_api.kinesis_api.id
  resource_id = aws_api_gateway_resource.kinesis_api_resource_check.id
  http_method = aws_api_gateway_method.kinesis_api_post.http_method
  status_code = "200"
}

resource "aws_api_gateway_integration_response" "kinesis_api" {
  rest_api_id = aws_api_gateway_rest_api.kinesis_api.id
  resource_id = aws_api_gateway_resource.kinesis_api_resource_check.id
  http_method = aws_api_gateway_method.kinesis_api_post.http_method
  status_code = aws_api_gateway_method_response.kinesis_api_ok.status_code

  depends_on = [
    aws_api_gateway_integration.kinesis_api_post
  ]

  # Passthrough the JSON response
  response_templates = {
    "application/json" = <<EOF
EOF
}
}

resource "aws_api_gateway_deployment" "kinesis_api_prod" {
  rest_api_id = aws_api_gateway_rest_api.kinesis_api.id

  triggers = {
    # NOTE: The configuration below will satisfy ordering considerations,
    #       but not pick up all future REST API changes. More advanced patterns
    #       are possible, such as using the filesha1() function against the
    #       Terraform configuration file(s) or removing the .id references to
    #       calculate a hash against whole resources. Be aware that using whole
    #       resources will show a difference after the initial implementation.
    #       It will stabilize to only change when resources change afterwards.
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.kinesis_api_resource_check.id,
      aws_api_gateway_method.kinesis_api_post.id,
      aws_api_gateway_integration.kinesis_api_post.id,
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }
}