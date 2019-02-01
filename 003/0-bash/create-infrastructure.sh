#!/bin/bash

AWS_REGION="ap-southeast-2"       # used only to chose the availability zone by appending "a" or "b"
PUBLIC_SRC="128.66.0.1/32"
AMI_IMAGE="ami-07a3bd4944eb120a0" # ubuntu/images/hvm-ssd/ubuntu-bionic-18.04-amd64-server-20180912
PREFIX="bash"

echo "Create ${PREFIX}:"

#
# VPC
#

# create VPC
vpc_id=$(aws ec2 create-vpc \
  --cidr-block 10.1.0.0/16 \
  --query "Vpc.{VpcId:VpcId}" \
  --output text)

# enable DNS names
aws ec2 modify-vpc-attribute \
  --vpc-id $vpc_id \
  --enable-dns-hostnames

# add a name tag
aws ec2 create-tags \
  --resources $vpc_id \
  --tags Key=Name,Value="vpc-${PREFIX}"

echo "- VPC"

#
# Internet Gateway
#

igw_id=$(aws ec2 create-internet-gateway \
  --query 'InternetGateway.{InternetGatewayId:InternetGatewayId}' \
  --output text \
  --region $AWS_REGION)

aws ec2 attach-internet-gateway \
  --vpc-id $vpc_id \
  --internet-gateway-id $igw_id

aws ec2 create-tags \
  --resources $igw_id \
  --tags "Key=Name,Value=igw-${PREFIX}"

echo "- Internet Gateway"


#
# Subnets
#

# Frontend A
fe_a_subnet_id=$(aws ec2 create-subnet \
  --vpc-id $vpc_id \
  --cidr-block "10.1.0.0/24" \
  --availability-zone "${AWS_REGION}a" \
  --query 'Subnet.{SubnetId:SubnetId}' \
  --output text)

aws ec2 create-tags \
  --resources $fe_a_subnet_id \
  --tags "Key=Name,Value=sn-${PREFIX}-fe-a"

aws ec2 modify-subnet-attribute \
  --subnet-id $fe_a_subnet_id \
  --map-public-ip-on-launch


# Frontend B
fe_b_subnet_id=$(aws ec2 create-subnet \
  --vpc-id $vpc_id \
  --cidr-block "10.1.1.0/24" \
  --availability-zone "${AWS_REGION}b" \
  --query 'Subnet.{SubnetId:SubnetId}' \
  --output text)

aws ec2 create-tags \
  --resources $fe_b_subnet_id \
  --tags "Key=Name,Value=sn-${PREFIX}-fe-b"

aws ec2 modify-subnet-attribute \
  --subnet-id $fe_b_subnet_id \
  --map-public-ip-on-launch


# Backend A
be_a_subnet_id=$(aws ec2 create-subnet \
  --vpc-id $vpc_id \
  --cidr-block "10.1.16.0/24" \
  --availability-zone "${AWS_REGION}b" \
  --query 'Subnet.{SubnetId:SubnetId}' \
  --output text)

aws ec2 create-tags \
  --resources $be_a_subnet_id \
  --tags "Key=Name,Value=sn-${PREFIX}-be-a" \
  --region $AWS_REGION

aws ec2 modify-subnet-attribute \
  --subnet-id $be_a_subnet_id \
  --map-public-ip-on-launch


# Backend B
be_b_subnet_id=$(aws ec2 create-subnet \
  --vpc-id $vpc_id \
  --cidr-block "10.1.17.0/24" \
  --availability-zone "${AWS_REGION}b" \
  --query 'Subnet.{SubnetId:SubnetId}' \
  --output text)

aws ec2 create-tags \
  --resources $be_b_subnet_id \
  --tags "Key=Name,Value=sn-${PREFIX}-be-b"

aws ec2 modify-subnet-attribute \
  --subnet-id $be_b_subnet_id \
  --map-public-ip-on-launch

echo "- Subnets"



# 
# Routing Table
#

rtb_id=$(aws ec2 create-route-table \
  --vpc-id $vpc_id \
  --query 'RouteTable.{RouteTableId:RouteTableId}' \
  --output text)

aws ec2 create-route  \
  --region $AWS_REGION \
  --route-table-id $rtb_id \
  --destination-cidr-block 0.0.0.0/0 \
  --gateway-id $igw_id >/dev/null

aws ec2 create-tags \
  --resources $rtb_id \
  --tags "Key=Name,Value=rtb-${PREFIX}"

aws ec2 associate-route-table \
 --subnet-id $fe_a_subnet_id \
 --route-table-id $rtb_id >/dev/null

aws ec2 associate-route-table \
 --subnet-id $fe_b_subnet_id \
 --route-table-id $rtb_id >/dev/null

aws ec2 associate-route-table \
 --subnet-id $be_a_subnet_id \
 --route-table-id $rtb_id >/dev/null

aws ec2 associate-route-table \
 --subnet-id $be_b_subnet_id \
 --route-table-id $rtb_id >/dev/null

echo "- Routing Table"


#
# Security Groups
#

# Admin
sg_admin_id=$(aws ec2 create-security-group \
  --vpc-id $vpc_id \
  --group-name "${PREFIX}-admin" \
  --description "Admin access" \
  --query "GroupId" \
  --output text)

aws ec2 create-tags \
  --resources $sg_admin_id \
  --tags "Key=Name,Value=sg-${PREFIX}-admin"

aws ec2 authorize-security-group-ingress \
  --group-id $sg_admin_id \
  --protocol tcp --port 22 \
  --cidr "$PUBLIC_SRC"

aws ec2 authorize-security-group-ingress \
  --group-id $sg_admin_id \
  --ip-permissions "IpProtocol=icmp,FromPort=8,ToPort=-1,IpRanges=[{CidrIp=$PUBLIC_SRC}]"

# Frontend
sg_fe_id=$(aws ec2 create-security-group \
  --vpc-id $vpc_id \
  --group-name "${PREFIX}-fe" \
  --description "Frontend access" \
  --query "GroupId" \
  --output text)

aws ec2 create-tags \
  --resources $sg_fe_id \
  --tags "Key=Name,Value=sg-${PREFIX}-fe"

# Backend
sg_be_id=$(aws ec2 create-security-group \
  --vpc-id $vpc_id \
  --group-name "${PREFIX}-be" \
  --description "Backend access" \
  --query "GroupId" \
  --output text)

aws ec2 create-tags \
  --resources $sg_be_id \
  --tags "Key=Name,Value=sg-${PREFIX}-be"

aws ec2 authorize-security-group-ingress \
  --group-id $sg_be_id \
  --protocol all \
  --source-group $sg_fe_id

echo "- Security Groups"


#
# EC2 instances
#

i_fe_a=$(aws ec2 run-instances \
  --image-id $AMI_IMAGE \
  --count 1 \
  --instance-type t2.micro \
  --key-name aws-lab00 \
  --security-group-ids $sg_admin_id $sg_fe_id \
  --subnet-id $fe_a_subnet_id \
  --private-ip-address "10.1.0.10" \
  --query "Instances[0].InstanceId" \
  --output text)

aws ec2 create-tags \
  --resources $i_fe_a \
  --tags "Key=Name,Value=i-fe-a0"


i_fe_b=$(aws ec2 run-instances \
  --image-id $AMI_IMAGE \
  --count 1 \
  --instance-type t2.micro \
  --key-name aws-lab00 \
  --security-group-ids $sg_admin_id $sg_fe_id \
  --subnet-id $fe_b_subnet_id \
  --private-ip-address "10.1.1.10" \
  --query "Instances[0].InstanceId" \
  --output text)

aws ec2 create-tags \
  --resources $i_fe_b \
  --tags "Key=Name,Value=i-fe-b0"


i_be_a=$(aws ec2 run-instances \
  --image-id $AMI_IMAGE \
  --count 1 \
  --instance-type t2.micro \
  --key-name aws-lab00 \
  --security-group-ids $sg_admin_id $sg_be_id \
  --subnet-id $be_a_subnet_id \
  --private-ip-address "10.1.16.10" \
  --query "Instances[0].InstanceId" \
  --output text)

aws ec2 create-tags \
  --resources $i_be_a \
  --tags "Key=Name,Value=i-be-a0"


i_be_b=$(aws ec2 run-instances \
  --image-id $AMI_IMAGE \
  --count 1 \
  --instance-type t2.micro \
  --key-name aws-lab00 \
  --security-group-ids $sg_admin_id $sg_be_id \
  --subnet-id $be_b_subnet_id \
  --private-ip-address "10.1.17.10" \
  --query "Instances[0].InstanceId" \
  --output text)
aws ec2 create-tags \
  --resources $i_be_b \
  --tags "Key=Name,Value=i-be-b0"

echo "- Instances"


#
# Write environment
#

echo "i_fe_a=$i_fe_a"  > "${PREFIX}.topo"
echo "i_fe_b=$i_fe_b" >> "${PREFIX}.topo"
echo "i_be_a=$i_be_a" >> "${PREFIX}.topo"
echo "i_be_b=$i_be_b" >> "${PREFIX}.topo"

echo "sg_be_id=$sg_be_id" >> "${PREFIX}.topo"
echo "sg_fe_id=$sg_fe_id" >> "${PREFIX}.topo"
echo "sg_admin_id=$sg_admin_id" >> "${PREFIX}.topo"

echo "fe_a_subnet_id=$fe_a_subnet_id" >> "${PREFIX}.topo"
echo "fe_b_subnet_id=$fe_b_subnet_id" >> "${PREFIX}.topo"
echo "be_a_subnet_id=$be_a_subnet_id" >> "${PREFIX}.topo"
echo "be_b_subnet_id=$be_b_subnet_id" >> "${PREFIX}.topo"

echo "rtb_id=$rtb_id" >> "${PREFIX}.topo"
echo "igw_id=$igw_id" >> "${PREFIX}.topo"

echo "vpc_id=$vpc_id" >> "${PREFIX}.topo"
