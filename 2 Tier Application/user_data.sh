#!/bin/bash

# Update and install httpd (Apache)
yum update -y
yum install -y httpd

# Fetch a token for IMDSv2
TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")

# Use the token to fetch EC2 instance metadata
INSTANCE_ID=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/instance-id)
INSTANCE_TYPE=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/instance-type)
AZ=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/placement/availability-zone)
PRIVATE_IP=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/local-ipv4)

# Create a basic HTML page with the instance information
cat > /var/www/html/index.html <<EOL
<html>
<head>
    <title>EC2 Instance Information</title>
</head>
<body>
    <h1>Welcome to the EC2 instance!</h1>
    <p><strong>Instance ID:</strong> ${INSTANCE_ID}</p>
    <p><strong>Instance Type:</strong> ${INSTANCE_TYPE}</p>
    <p><strong>Availability Zone:</strong> ${AZ}</p>
    <p><strong>Private IP:</strong> ${PRIVATE_IP}</p>
</body>
</html>
EOL

# Start and enable the httpd service to start on boot
systemctl start httpd
systemctl enable httpd