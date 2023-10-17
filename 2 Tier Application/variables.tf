variable "vpc_id" { # Gathers the VPC
    description = "The VPC ID that the infrastructure should be deployed in."
    type = string
}

variable "endpoint_route_tables" {
    description = "List of private route table IDs for creating DynamoDB endpoint"
    type = list(string)
}

variable "region" {
    type = string
    description = "Region to deploy in AWS"
}

variable "launch_ami" {
    description = "The default launch AMI for instances in the auto scaling group, defaults to Amazon Linux 2 if not overriden"
    default = "ami-03a6eaae9938c858c"
}

variable "launch_instance_type" {
    description = "Instance type for instances in the ASG"
    default = "t2.micro"
}

variable "certificate_arn" {
    description = "SSL/TLS Certificate"
    type = string
}

data "aws_subnets" "subnets" { # Gathers all subnets in the VPC
    filter {
        name   = "vpc-id"
        values = [var.vpc_id]
    }

    filter {
        name   = "tag:Tier"
        values = ["Public"]
    }
}

locals {
    subnets = data.aws_subnets.subnets.ids
}

variable "hosted_zone" {
    description = "Hosted zone of your route53"
    type = string
}

data "aws_route53_zone" "hosted_zone_data" {
  name = var.hosted_zone
}



