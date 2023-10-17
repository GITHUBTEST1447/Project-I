provider "aws" {
    region = "us-east-1"
}

# Create target group for load balancer
resource "aws_lb_target_group" "target_group" {
    name =      "terraform-target-group"
    port =      80
    protocol =  "HTTP"
    vpc_id =    var.vpc_id
}

# Create security group for load balancer
resource "aws_security_group" "lb_security_group" {
    name        = "terraform-lb-security-group"
    vpc_id      = var.vpc_id
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
    ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Create load balancer
resource "aws_lb" "load_balancer" {
    name               = "terraform-load-balancer"
    internal           = false
    load_balancer_type = "application"
    security_groups    = [aws_security_group.lb_security_group.id]
    subnets            = local.subnets # This needs to be public subnets
}

# Create HTTPS listener for load balancer
resource "aws_lb_listener" "lb_listener" {
    load_balancer_arn = aws_lb.load_balancer.arn
    port              = "443"
    protocol          = "HTTPS"
    ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
    certificate_arn   = var.certificate_arn

    default_action {
        type             = "forward"
        target_group_arn = aws_lb_target_group.target_group.arn
    }
}

# Create security group for launch template
resource "aws_security_group" "lg_security_group" {
    name        = "terraform-lg-security-group"
    vpc_id      = var.vpc_id

    ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    security_groups = [aws_security_group.lb_security_group.id] 
    }
    egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

}

# Create launch template for auto scaling group
resource "aws_launch_template" "launch_template" {
    name                        = "terraform-launch-template"
    image_id                    = var.launch_ami
    instance_type               = var.launch_instance_type
    network_interfaces {
    associate_public_ip_address = true
    security_groups             = [aws_security_group.lg_security_group.id]
    }
    user_data                   = base64encode(file("${path.module}/user_data.sh"))

}
# Create auto scaling group
resource "aws_autoscaling_group" "autoscaling_group" {
    name                = "terraform-asg"
    desired_capacity    = 2
    min_size            = 2
    max_size            = 4
    vpc_zone_identifier = local.subnets
    launch_template {
        id              = aws_launch_template.launch_template.id
        version         = "$Latest"
    }
    target_group_arns   = [aws_lb_target_group.target_group.arn]
}

# Create Route 53 record that points to CloudFront distrubition
resource "aws_route53_record" "route53_record" {
    zone_id = data.aws_route53_zone.hosted_zone_data.zone_id
    name = "twotierapp.${var.hosted_zone}"
    type = "A"
    alias {
    name                   = aws_cloudfront_distribution.cloudfront_distribution.domain_name
    zone_id                = aws_cloudfront_distribution.cloudfront_distribution.hosted_zone_id
    evaluate_target_health = false
  }
}

# Create cache policy for CloudFront distribution
resource "aws_cloudfront_cache_policy" "cache_policy" {
  name = "Terraform-Cache-Policy"
  default_ttl = 60
  min_ttl = 30
  max_ttl = 120

  parameters_in_cache_key_and_forwarded_to_origin {
    headers_config {
      header_behavior = "none"
    }
    cookies_config {
      cookie_behavior = "none"
    }
    query_strings_config {
      query_string_behavior = "none"
    }
  }
}

# Create origin request policy for CloudFront distribution
resource "aws_cloudfront_origin_request_policy" "origin_request_policy" {
  name    = "allow-all-policy"
  cookies_config {
    cookie_behavior = "all"
  }
  headers_config {
    header_behavior = "allViewer"
  }
  query_strings_config {
    query_string_behavior = "all"
  }
}

# Create CloudFront distribution
resource "aws_cloudfront_distribution" "cloudfront_distribution" {

  # Configuration for Cloudfront Origin
  origin {
      domain_name = aws_lb.load_balancer.dns_name
      origin_id = "TERRAFORM-ORIGIN"

      custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  # Configuration for the default caching behavior
  default_cache_behavior {
    viewer_protocol_policy = "allow-all"
    allowed_methods = ["GET", "HEAD"]
    cached_methods = ["GET", "HEAD"]
    compress = true

    cache_policy_id = aws_cloudfront_cache_policy.cache_policy.id
    origin_request_policy_id = aws_cloudfront_origin_request_policy.origin_request_policy.id
    target_origin_id = "TERRAFORM-ORIGIN"
  }

  # Configuration for the SSL/TLS certificate
  viewer_certificate {
    acm_certificate_arn      = var.certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2018"
  }

  # Configuration for the Cloudfront's restrictions
  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  } 

    # Additional Cloudfront Configurations
    enabled = true
    is_ipv6_enabled = true
    price_class = "PriceClass_200"
    web_acl_id = ""
    aliases = ["twotierapp.steffenaws.net"]


}

# Configuration for VPC Gateway Endpoint to allow DynamoDB
resource "aws_vpc_endpoint" "dynamodb_endpoint" {
  vpc_id = var.vpc_id
  service_name = "com.amazonaws.${var.region}.dynamodb"
  vpc_endpoint_type = "Gateway"
  route_table_ids = var.endpoint_route_tables

  tags = {
    Name = "dynamodb-vpc-endpoint"
  }
}

# Configuration of DynamoDB table
resource "aws_dynamodb_table" "instances" {
  name = "instances"
  billing_mode = "PROVISIONED"
  read_capacity = 2
  write_capacity = 2
  hash_key = "InstanceID"

  attribute {
    name = "InstanceID"
    type = "S"
  }
}