data "aws_caller_identity" "current" {}

# api gateway에 적용할 IAM role 생성(API Gateway -> Kinesis stream)
resource "aws_iam_role" "apigateway_role" {
name = "${var.stream_name}-apigateway-iam-role"

assume_role_policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "",
            "Effect": "Allow",
            "Principal": {
                "Service": "apigateway.amazonaws.com"
            },
            "Action": "sts:AssumeRole"
        }
    ]
}
EOF
}

# 위에서 생성한 IAM role에 적용할 정책(policy) 작성
resource "aws_iam_role_policy" "apigateway_policy" {
name  = "${var.stream_name}-apigateway-iam-policy"
role  = aws_iam_role.apigateway_role.id

policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": "kinesis:*",
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "logs:CreateLogGroup",
                "logs:CreateLogStream",
                "logs:DescribeLogGroups",
                "logs:DescribeLogStreams",
                "logs:PutLogEvents",
                "logs:GetLogEvents",
                "logs:FilterLogEvents"
            ],
            "Resource": "*"
        }
    ]
}
EOF
}



# firehose에 적용할 IAM role 생성
resource "aws_iam_role" "firehose_iam_role" {
name  = "${var.stream_name}-firehose-iam-role"

assume_role_policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Service": "firehose.amazonaws.com"
            },
            "Action": "sts:AssumeRole"
        }
    ]
}
EOF
}

# 위에서 생성한 IAM role에 적용할 정책(Policy) 적용
resource "aws_iam_role_policy" "firehose_policy" {
name  = "${var.stream_name}-firehose-iam-policy"
role  = "${aws_iam_role.firehose_iam_role.id}"

policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": "s3:*",
            "Resource": [
                "${aws_s3_bucket.bucket.arn}",
                "${aws_s3_bucket.bucket.arn}/*"
            ]
        },
        {
            "Effect": "Allow",
            "Action": "kinesis:*",
            "Resource": "${aws_kinesis_stream.test_stream.arn}"
        },
        {
        "Effect": "Allow",
        "Action": "firehose:*",
        "Resource" : "*"
        }
    ]
}
EOF
}



resource "aws_iam_role_policy" "write_role_policy" {
  name  = "${var.stream_name}-write-policy"
  role = "${aws_iam_role.gateway_execution_role.id}"
  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "kinesis:DescribeStream",
                "kinesis:PutRecord",
                "kinesis:PutRecords"
            ],
            "Resource": [
                "arn:aws:kinesis:${var.aws_region}:${data.aws_caller_identity.current.account_id}:stream/${var.stream_name}"
            ]
        },
        {
            "Effect": "Allow",
            "Action": [
                "kinesis:ListStreams"
            ],
            "Resource": [
                "*"
            ]
        }
    ]
}
EOF
}

resource "aws_iam_role" "gateway_execution_role" {
  name  = "${var.stream_name}-gateway-execution-role"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "apigateway.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}