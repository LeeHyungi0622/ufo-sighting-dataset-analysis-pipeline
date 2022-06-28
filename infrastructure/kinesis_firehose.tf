resource "aws_s3_bucket" "bucket" {
  bucket = "hg-${var.stream_name}-event-backup"
}

resource "aws_kinesis_firehose_delivery_stream" "extended_s3_stream" {
  name        = "${var.stream_name}"

  destination = "s3"

  kinesis_source_configuration {
    // kinesis_stream.tf에서 resource로 정의한 aws_kinesis_stream의 arn
    kinesis_stream_arn = aws_kinesis_stream.test_stream.arn
    // 
    role_arn = aws_iam_role.firehose_iam_role.arn
  }

  s3_configuration {
    role_arn   = aws_iam_role.firehose_iam_role.arn
    bucket_arn = aws_s3_bucket.bucket.arn
  }
}

resource "aws_s3_bucket_acl" "bucket_acl" {
  bucket = aws_s3_bucket.bucket.id
  acl    = "private"
}