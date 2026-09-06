#!/bin/bash
# Reference commands used to configure network isolation between the
# EC2 (web) and RDS (db) tiers. Replace placeholders before running.
#
#   <WEB_SG_ID>   - security group ID attached to the EC2 instance
#   <DB_SG_ID>    - security group ID attached to the RDS instance
#   <YOUR_IP>     - your current public IP, e.g. 203.0.113.10/32

# --- Web tier security group (EC2) ---
# SSH restricted to a single admin IP
aws ec2 authorize-security-group-ingress \
  --group-id <WEB_SG_ID> \
  --protocol tcp --port 22 --cidr <YOUR_IP>/32

# HTTP / HTTPS open to the public (this is a public-facing storefront)
aws ec2 authorize-security-group-ingress \
  --group-id <WEB_SG_ID> \
  --protocol tcp --port 80 --cidr 0.0.0.0/0

aws ec2 authorize-security-group-ingress \
  --group-id <WEB_SG_ID> \
  --protocol tcp --port 443 --cidr 0.0.0.0/0

# --- Database tier security group (RDS) ---
# MySQL reachable ONLY from the web tier's security group -
# not from any IP address, including the admin's own.
aws ec2 authorize-security-group-ingress \
  --group-id <DB_SG_ID> \
  --protocol tcp --port 3306 \
  --source-group <WEB_SG_ID>

# --- Verification ---
aws ec2 describe-security-groups \
  --group-ids <WEB_SG_ID> <DB_SG_ID> \
  --query "SecurityGroups[*].[GroupName,IpPermissions]" \
  --output json
