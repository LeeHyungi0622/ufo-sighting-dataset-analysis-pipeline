
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