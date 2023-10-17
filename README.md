## Project Title

2-Tier Application Architecture

## Overview

Wrote a module for deploying a simple 2 Tier Web Application Architecture.  
Made use of the following services:  

- AWS EC2 (ELB, ASG, Launch Templates, Target Groups, Security Groups)  
- AWS VPC (Public/Private Subnets, Gateway Endpoint, Route Tables, Internet Gateways)  
- AWS DynamoDB (Tables, Gateway Endpoint)  
- AWS CloudFront (Setup the ELB as the Origin)  
- AWS Route53 (Setup ALIAS record to point to the CloudFront Distribution)  

## General Requirements

- An AWS account
- Terraform
- ~$1/month
- Creating your own root module to call

## Terraform Requirements

- An already created VPC. Easy to use AWS' official VPC module to deploy this. Supply the VPC ID in the module call.  
- A Route 53 Hosted Zone. Supply the hosted zone's FQDN in the module call.  
- A SSL/TLS certificate from AWS ACM. Supply in the module call.  
- A AWS region. Supply in the module call.  
- Endpoint route tables. Used for creating the DynamoDB gateway endpoint. Supply in module call.  

