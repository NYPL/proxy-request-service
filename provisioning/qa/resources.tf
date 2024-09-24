provider "aws" {
  region     = "us-east-1"
}

terraform {
  # Use s3 to store terraform state
  backend "s3" {
    bucket  = "nypl-github-actions-builds-qa"
    key     = "proxy-request-service-terraform-state"
    region  = "us-east-1"
  }
}

module "base" {
  source = "../base"
  environment = "qa"
}

data "archive_file" "lambda_zip" {
  type        = "zip"
  output_path = "${path.module}/dist.zip"
  source_dir  = "../../"
  excludes    = [".git", ".terraform", "provisioning"]
}

# Upload the zipped app to S3:
resource "aws_s3_object" "uploaded_zip" {
  bucket = "nypl-github-actions-builds-qa"
  key    = "proxy-request-service-qa-dist.zip"
  acl    = "private"
  source = data.archive_file.lambda_zip.output_path
  etag   = filemd5(data.archive_file.lambda_zip.output_path)
}

resource "aws_lambda_function" "lambda_instance" {
  description   = "Lambda that sits behind API Gateway to serve as a proxy for arbitrary endpoints that we want to make asynchronous."
  function_name = "ProxyRequestService-qa"
  handler       = "application.handle_event"
  memory_size   = 128
  role          = "arn:aws:iam::946183545209:role/lambda-full-access"
  runtime       = "ruby3.3"
  timeout       = 60

  # Location of the zipped code in S3:
  s3_bucket     = aws_s3_object.uploaded_zip.bucket
  s3_key        = aws_s3_object.uploaded_zip.key

  # Trigger pulling code from S3 when the zip has changed:
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  # Load ENV vars from ./config/{environment}.env
  environment {
    variables = {
      for tuple in regexall("(.*?)=(.*)", file("../../config/qa.env")) : tuple[0] => tuple[1]
    }
  }
}