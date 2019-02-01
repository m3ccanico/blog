#!/usr/bin/env python3

import boto3
import json

PREFIX = "python"
CIDR = "10.1.0.0/16"
REGION = "ap-southeast-2"
PUBLIC_SRC = "128.66.0.1/32"
AMI_IMAGE = "ami-07a3bd4944eb120a0"

session = boto3.Session(profile_name="lab01")
ec2 = session.resource("ec2")

topology = {
    "vpc": [],
    "instance": [],
    "security-group": [],
    "subnet": [],
    "internet-gateway": [],
    "route-table": [],
}

# VPC
vpc = ec2.create_vpc(CidrBlock=CIDR)
vpc.modify_attribute(EnableDnsHostnames={"Value": True})
vpc.wait_until_available()
vpc.create_tags(Tags=[{"Key": "Name", "Value": f"vpc-{PREFIX}"}])
topology["vpc"].append(vpc.id)

# Internet Gateway
igw = ec2.create_internet_gateway()
vpc.attach_internet_gateway(InternetGatewayId=igw.id)
igw.create_tags(Tags=[{"Key": "Name", "Value": f"igw-{PREFIX}"}])
topology["internet-gateway"].append(igw.id)

# Subnets
fe_a_subnet = ec2.create_subnet(
    VpcId=vpc.id, CidrBlock="10.1.0.0/24", AvailabilityZone=f"{REGION}a"
)
fe_a_subnet.meta.client.modify_subnet_attribute(
    SubnetId=fe_a_subnet.id, MapPublicIpOnLaunch={"Value": True}
)
fe_a_subnet.create_tags(Tags=[{"Key": "Name", "Value": f"sn-{PREFIX}-fe-a"}])
topology["subnet"].append(fe_a_subnet.id)

fe_b_subnet = ec2.create_subnet(
    VpcId=vpc.id, CidrBlock="10.1.1.0/24", AvailabilityZone=f"{REGION}b"
)
fe_b_subnet.meta.client.modify_subnet_attribute(
    SubnetId=fe_b_subnet.id, MapPublicIpOnLaunch={"Value": True}
)
fe_b_subnet.create_tags(Tags=[{"Key": "Name", "Value": f"sn-{PREFIX}-fe-b"}])
topology["subnet"].append(fe_b_subnet.id)

be_a_subnet = ec2.create_subnet(
    VpcId=vpc.id, CidrBlock="10.1.16.0/24", AvailabilityZone=f"{REGION}a"
)
be_a_subnet.meta.client.modify_subnet_attribute(
    SubnetId=be_a_subnet.id, MapPublicIpOnLaunch={"Value": True}
)
be_a_subnet.create_tags(Tags=[{"Key": "Name", "Value": f"sn-{PREFIX}-be-a"}])
topology["subnet"].append(be_a_subnet.id)

be_b_subnet = ec2.create_subnet(
    VpcId=vpc.id, CidrBlock="10.1.17.0/24", AvailabilityZone=f"{REGION}b"
)
be_b_subnet.meta.client.modify_subnet_attribute(
    SubnetId=be_b_subnet.id, MapPublicIpOnLaunch={"Value": True}
)
be_b_subnet.create_tags(Tags=[{"Key": "Name", "Value": f"sn-{PREFIX}-be-b"}])
topology["subnet"].append(be_b_subnet.id)

# Route table
route_table = vpc.create_route_table()
route = route_table.create_route(DestinationCidrBlock="0.0.0.0/0", GatewayId=igw.id)
route_table.create_tags(Tags=[{"Key": "Name", "Value": f"rtb-{PREFIX}"}])
topology["route-table"].append(route_table.id)

route_table.associate_with_subnet(SubnetId=fe_a_subnet.id)
route_table.associate_with_subnet(SubnetId=fe_b_subnet.id)
route_table.associate_with_subnet(SubnetId=be_a_subnet.id)
route_table.associate_with_subnet(SubnetId=be_b_subnet.id)

# Security Groups
sg_admin = ec2.create_security_group(
    GroupName="admin", Description="Admin access", VpcId=vpc.id
)
sg_admin.create_tags(Tags=[{"Key": "Name", "Value": f"sg-{PREFIX}-admin"}])
sg_admin.authorize_ingress(CidrIp=PUBLIC_SRC, IpProtocol="tcp", FromPort=22, ToPort=22)
sg_admin.authorize_ingress(CidrIp=PUBLIC_SRC, IpProtocol="icmp", FromPort=8, ToPort=-1)
topology["security-group"].append(sg_admin.id)

sg_fe = ec2.create_security_group(
    GroupName="frontend", Description="Frontend access", VpcId=vpc.id
)
sg_fe.create_tags(Tags=[{"Key": "Name", "Value": f"sg-{PREFIX}-fe"}])
topology["security-group"].append(sg_fe.id)

sg_be = ec2.create_security_group(
    GroupName="backend", Description="Backend access", VpcId=vpc.id
)
sg_be.create_tags(Tags=[{"Key": "Name", "Value": f"sg-{PREFIX}-be"}])
sg_be.authorize_ingress(
    IpPermissions=[{"IpProtocol": "-1", "UserIdGroupPairs": [{"GroupId": sg_fe.id}]}]
)
topology["security-group"].append(sg_be.id)

# EC2
instances = ec2.create_instances(
    ImageId=AMI_IMAGE,
    InstanceType="t2.micro",
    MaxCount=1,
    MinCount=1,
    NetworkInterfaces=[
        {
            "SubnetId": fe_a_subnet.id,
            "DeviceIndex": 0,
            "AssociatePublicIpAddress": True,
            "Groups": [sg_admin.id, sg_fe.id],
            "PrivateIpAddress": "10.1.0.10",
        }
    ],
    Placement={"AvailabilityZone": f"{REGION}a"},
    KeyName="aws-lab00",
)
i_fe_a = instances[0]
i_fe_a.create_tags(Tags=[{"Key": "Name", "Value": "i-fe-a0"}])
topology["instance"].append(i_fe_a.id)

instances = ec2.create_instances(
    ImageId=AMI_IMAGE,
    InstanceType="t2.micro",
    MaxCount=1,
    MinCount=1,
    NetworkInterfaces=[
        {
            "SubnetId": fe_b_subnet.id,
            "DeviceIndex": 0,
            "AssociatePublicIpAddress": True,
            "Groups": [sg_admin.id, sg_fe.id],
            "PrivateIpAddress": "10.1.1.10",
        }
    ],
    Placement={"AvailabilityZone": f"{REGION}b"},
    KeyName="aws-lab00",
)
i_fe_b = instances[0]
i_fe_b.create_tags(Tags=[{"Key": "Name", "Value": "i-fe-b0"}])
topology["instance"].append(i_fe_b.id)

instances = ec2.create_instances(
    ImageId=AMI_IMAGE,
    InstanceType="t2.micro",
    MaxCount=1,
    MinCount=1,
    NetworkInterfaces=[
        {
            "SubnetId": be_a_subnet.id,
            "DeviceIndex": 0,
            "AssociatePublicIpAddress": True,
            "Groups": [sg_admin.id, sg_be.id],
            "PrivateIpAddress": "10.1.16.10",
        }
    ],
    Placement={"AvailabilityZone": f"{REGION}a"},
    KeyName="aws-lab00",
)
i_be_a = instances[0]
i_be_a.create_tags(Tags=[{"Key": "Name", "Value": "i-be-a0"}])
topology["instance"].append(i_be_a.id)

instances = ec2.create_instances(
    ImageId=AMI_IMAGE,
    InstanceType="t2.micro",
    MaxCount=1,
    MinCount=1,
    NetworkInterfaces=[
        {
            "SubnetId": be_b_subnet.id,
            "DeviceIndex": 0,
            "AssociatePublicIpAddress": True,
            "Groups": [sg_admin.id, sg_be.id],
            "PrivateIpAddress": "10.1.17.10",
        }
    ],
    Placement={"AvailabilityZone": f"{REGION}b"},
    KeyName="aws-lab00",
)
i_be_b = instances[0]
i_be_b.create_tags(Tags=[{"Key": "Name", "Value": "i-be-b0"}])
topology["instance"].append(i_be_b.id)

# write topology
with open("topology.json", "w") as f:
    json.dump(topology, f)

# wait for instances to start
i_fe_a.wait_until_running()
i_fe_b.wait_until_running()
i_be_a.wait_until_running()
i_be_b.wait_until_running()
