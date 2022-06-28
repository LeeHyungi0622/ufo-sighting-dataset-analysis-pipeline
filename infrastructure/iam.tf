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
            "Sid": "",
            "Effect": "Allow",
            "Action": [
                "glue:GetTable",
                "glue:GetTableVersion",
                "glue:GetTableVersions"
            ],
            "Resource": [
                "arn:aws:glue:ap-northeast-2:833496479373:catalog",
                "arn:aws:glue:ap-northeast-2:833496479373:database/%FIREHOSE_POLICY_TEMPLATE_PLACEHOLDER%",
                "arn:aws:glue:ap-northeast-2:833496479373:table/%FIREHOSE_POLICY_TEMPLATE_PLACEHOLDER%/%FIREHOSE_POLICY_TEMPLATE_PLACEHOLDER%"
            ]
        },
        {
            "Sid": "",
            "Effect": "Allow",
            "Action": [
                "s3:AbortMultipartUpload",
                "s3:GetBucketLocation",
                "s3:GetObject",
                "s3:ListBucket",
                "s3:ListBucketMultipartUploads",
                "s3:PutObject"
            ],
            "Resource": [
                "arn:aws:s3:::hg-project-stream-event-backup",
                "arn:aws:s3:::hg-project-stream-event-backup/*"
            ]
        },
        {
            "Sid": "",
            "Effect": "Allow",
            "Action": [
                "lambda:InvokeFunction",
                "lambda:GetFunctionConfiguration"
            ],
            "Resource": "arn:aws:lambda:ap-northeast-2:833496479373:function:%FIREHOSE_POLICY_TEMPLATE_PLACEHOLDER%"
        },
        {
            "Effect": "Allow",
            "Action": [
                "kms:GenerateDataKey",
                "kms:Decrypt"
            ],
            "Resource": [
                "arn:aws:kms:ap-northeast-2:833496479373:key/%FIREHOSE_POLICY_TEMPLATE_PLACEHOLDER%"
            ],
            "Condition": {
                "StringEquals": {
                    "kms:ViaService": "s3.ap-northeast-2.amazonaws.com"
                },
                "StringLike": {
                    "kms:EncryptionContext:aws:s3:arn": [
                        "arn:aws:s3:::%FIREHOSE_POLICY_TEMPLATE_PLACEHOLDER%/*",
                        "arn:aws:s3:::%FIREHOSE_POLICY_TEMPLATE_PLACEHOLDER%"
                    ]
                }
            }
        },
        {
            "Sid": "",
            "Effect": "Allow",
            "Action": [
                "logs:PutLogEvents"
            ],
            "Resource": [
                "arn:aws:logs:ap-northeast-2:833496479373:log-group:/aws/kinesisfirehose/KDS-S3-5tizk:log-stream:*",
                "arn:aws:logs:ap-northeast-2:833496479373:log-group:%FIREHOSE_POLICY_TEMPLATE_PLACEHOLDER%:log-stream:*"
            ]
        },
        {
            "Sid": "",
            "Effect": "Allow",
            "Action": [
                "kinesis:DescribeStream",
                "kinesis:GetShardIterator",
                "kinesis:GetRecords",
                "kinesis:ListShards"
            ],
            "Resource": "arn:aws:kinesis:ap-northeast-2:833496479373:stream/project-stream"
        },
        {
            "Effect": "Allow",
            "Action": [
                "kms:Decrypt"
            ],
            "Resource": [
                "arn:aws:kms:ap-northeast-2:833496479373:key/%FIREHOSE_POLICY_TEMPLATE_PLACEHOLDER%"
            ],
            "Condition": {
                "StringEquals": {
                    "kms:ViaService": "kinesis.ap-northeast-2.amazonaws.com"
                },
                "StringLike": {
                    "kms:EncryptionContext:aws:kinesis:arn": "arn:aws:kinesis:ap-northeast-2:833496479373:stream/project-stream"
                }
            }
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