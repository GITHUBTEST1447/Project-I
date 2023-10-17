provider "aws" {
    region = "us-east-1"
}

terraform {
    backend "s3" {
        bucket         = "terraform-remote-backend-57"
        key            = "global/2tierapp/terraform.tfstate"
        region         = "us-east-1"
        dynamodb_table = "terraform-state-locking"
        encrypt        = true
    }
}