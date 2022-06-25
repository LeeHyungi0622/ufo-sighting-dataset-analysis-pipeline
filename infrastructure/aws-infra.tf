# AWS Platform plugin 다운받기
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
}

# Configure the AWS Provider
# Seoul - ap-northeast-2
provider "aws" {
  access_key = "${var.aws_access_key}"
  secret_key = "${var.aws_secret_key}"
  region = "${var.aws_region}"
}

# VPC 생성
resource "aws_vpc" "prod-vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "production"
  }
}

# IGW(Internet Gateway) 생성
# VPC
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.prod-vpc.id
}

# Route table 생성
resource "aws_route_table" "prod-route-table" {
  vpc_id = aws_vpc.prod-vpc.id

  route {
    # cidr_block address를 IGW로 보내고, 
    cidr_block = "0.0.0.0/0" 
    # 0.0.0.0/0 send all traffic before ip will route to IGW. 
    # 모든 트래픽이 aws IGW로 전송되기 때문에 gaqteway_id에 대한 설정이 필요하다.
    gateway_id = aws_internet_gateway.gw.id
  }

  route {
    # 실제로는 IPv6를 사용하지 않지만 All traffic이 동일한 IGW로 routing되도록 설정한다.
    ipv6_cidr_block        = "::/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "Prod"
  }
}

# Subnet 생성
# AZ(Data centre에 대한 setup)
# 생성한 Subnet을 상단에서 설정한 Route table에 넣어준다.
resource "aws_subnet" "subnet-1" {
  vpc_id = aws_vpc.prod-vpc.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "ap-northeast-2a"
  tags = {
    Name = "prod-subnet"
  }
}

# Associate subnet with route table
resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.subnet-1.id
  route_table_id = aws_route_table.prod-route-table.id
}

# API Gateway 생성

// API 정의
resource "aws_api_gateway_rest_api" "kinesis_api" {
  name        = "KinesisAPI"
  description = "외부로부터 전송되는 데이터를 Kinesis stream으로 전달해주는 API"
}

// API 리소스 정의 (/v1 같은 경로)
resource "aws_api_gateway_resource" "kinesis_api_resource_check" {
  rest_api_id = "${aws_api_gateway_rest_api.kinesis_api.id}"
  parent_id   = "${aws_api_gateway_rest_api.kinesis_api.root_resource_id}"
  path_part   = "v1"
}

// API 리소스의 메서드 정의 (GET, POST 등)
resource "aws_api_gateway_method" "kinesis_api_resource_check_post" {
  rest_api_id   = "${aws_api_gateway_rest_api.kinesis_api.id}"
  resource_id   = "${aws_api_gateway_resource.kinesis_api_resource_check.id}"
  http_method   = "POST"
  authorization = "NONE"
}

// https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/api_gateway_integration
resource "aws_api_gateway_integration" "kinesis_api_resource_check_post" {
  rest_api_id = "${aws_api_gateway_rest_api.kinesis_api.id}"
  resource_id = "${aws_api_gateway_resource.kinesis_api_resource_check.id}"
  http_method = "${aws_api_gateway_method.kinesis_api_resource_check_post.http_method}"
  type = "AWS"
  integration_http_method = "POST"
  # arn:aws:apigateway:{region}:{subdomain.service|service}:{path|action}/{service_api}
  uri = "arn:aws:apigateway:ap-northeast-2:kinesis:action/PutRecord"
  # Transforms the incoming XML request to JSON
  passthrough_behavior    = "WHEN_NO_TEMPLATES"
  credentials             = "arn:aws:iam::833496479373:role/apigatewayToKinesis"  

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

# Api Gateway 배포
// API 배포 (production)
resource "aws_api_gateway_deployment" "kinesis_api_prod" {
  depends_on = ["aws_api_gateway_integration.kinesis_api_resource_check_post"]
  rest_api_id = "${aws_api_gateway_rest_api.kinesis_api.id}"
  stage_name  = "prod"
  stage_description = "${timestamp()}"
  description = "Deployed at ${timestamp()}"
}

# Kinesis data stream 생성 (project-stream)
# https://registry.terraform.io/providers/hashicorp/aws/2.34.0/docs/resources/kinesis_stream
resource "aws_kinesis_stream" "mod" {
  name             = "${var.stream_name}"
  shard_count      = "${var.shard_count}"
  retention_period = "${var.retention_period}"

  shard_level_metrics = [
    "IncomingBytes",
    "OutgoingBytes",
    "OutgoingRecords",
    "ReadProvisionedThroughputExceeded",
    "WriteProvisionedThroughputExceeded",
    "IncomingRecords",
    "IteratorAgeMilliseconds",
  ]
}

# AWS S3 bucket
resource "aws_s3_bucket" "mod" {
  bucket = "hg-${var.stream_name}-event-backup"
}

# Kinesis firehose
resource "aws_kinesis_firehose_delivery_stream" "mod" {
  name  = "${var.stream_name}-backup"

  destination = "s3"

  s3_configuration {
    role_arn   = "${aws_iam_role.firehose_role.arn}"
    bucket_arn = "${aws_s3_bucket.mod.arn}"
  }
}

# firehose에 적용할 IAM role 생성
resource "aws_iam_role" "firehose_role" {
  name  = "${var.stream_name}-firehose-role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "firehose.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

# 위에서 생성한 IAM role에 적용할 정책(Policy) 적용
resource "aws_iam_role_policy" "firehose_policy" {
  name  = "${var.stream_name}-firehose-policy"
  role  = "${aws_iam_role.firehose_role.id}"

  policy = <<EOF
{
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "s3:*",
                "s3-object-lambda:*"
            ],
            "Resource": "*"
        }
    ]
}
EOF
}