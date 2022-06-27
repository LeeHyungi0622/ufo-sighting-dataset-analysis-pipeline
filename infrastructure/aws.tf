# aws.tf : AWS Platform plugin 다운 및 aws provider 설정

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