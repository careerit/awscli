#!/bin/bash

set -xe 

REGION="us-west-1"
PREFIX="PowerInc"
VPC_CIDR="10.0.0.0/16"
SUBNET1="Public"
SUBNET2="Private"
SUBNET1_CIDR="10.0.1.0/24"
SUBNET2_CIDR="10.0.2.0/24"
instance_type="t2.small"


echo "Creating a VPC"
#Create a VPC and also capture it's VPC ID in the variable vpcId
vpcId=$(aws ec2 create-vpc --region $REGION --cidr-block $VPC_CIDR   | jq -r ".Vpc.VpcId") 
echo "ID of the VPC is $vpcId"
# Add tags to the VPC
aws ec2 create-tags --resource $vpcId --region $REGION --tags "Key=Name,Value=$PREFIX-vpc" "Key=Environment,Value=Testing"

echo "Creating a Subnet"
# Create a Subnet and capture the subnetId1 in $subnetId1
subnetId1=$(aws ec2 create-subnet --vpc-id $vpcId --region $REGION --cidr-block $SUBNET1_CIDR  | jq -r ".Subnet.SubnetId")

subnetId2=$(aws ec2 create-subnet --vpc-id $vpcId --region $REGION --cidr-block $SUBNET2_CIDR  | jq -r ".Subnet.SubnetId")

echo "Creating an Internet Gateway"
# Create an Internet Gateway and capture Internet Gateway ID in igwId
igwId=$(aws ec2 create-internet-gateway --region $REGION --tag-specifications 'ResourceType=internet-gateway,Tags=[{Key=Name,Value="'${PREFIX}'-igw"}]'  | jq -r ".InternetGateway.InternetGatewayId") 

# Attach Internet Gateway to VPC
aws ec2 attach-internet-gateway --vpc-id $vpcId  --internet-gateway-id $igwId --region $REGION --no-cli-auto-prompt 

echo "Creating a Route Table "
# Create a route-table and capture the routetableId in $publicrtIdrtId
publicrtId=$(aws ec2 create-route-table --vpc-id $vpcId --region $REGION --tag-specifications 'ResourceType=route-table,Tags=[{Key=Name,Value="'${PREFIX}'-public-rt"}]' | jq -r ".RouteTable.RouteTableId" )
# Creating Routes
aws ec2 create-route --route-table-id $publicrtId --region $REGION --destination-cidr-block 0.0.0.0/0 --gateway-id $igwId

# Associate Route Table to Subnet1
aws ec2 associate-route-table --subnet-id $subnetId1 --route-table-id $publicrtId --no-cli-auto-prompt --region $REGION  

# Associate Route Table to Subnet2
aws ec2 associate-route-table --subnet-id $subnetId2 --route-table-id $publicrtId --no-cli-auto-prompt --region $REGION  



echo "Creating a Security Group"
# Create Security Group and capture teh SecurityGroup ID in webSgId
webSgId=$(aws ec2 create-security-group --region $REGION --vpc-id $vpcId --group-name $PREFIX-web-sg  --description "SG For Web Instances" --tag-specifications | jq -r ".GroupId")

sleep 45


# Add Security Group Rule
aws ec2 authorize-security-group-ingress --region $REGION  --group-id $webSgId --protocol tcp --port 22 --cidr 0.0.0.0/0
aws ec2 authorize-security-group-ingress --region $REGION  --group-id $webSgId --protocol tcp --port 80 --cidr 0.0.0.0/0

# Subnet Modification to create Public IP on Launch
aws ec2 modify-subnet-attribute --region $REGION --subnet-id $subnetId1 --map-public-ip-on-launch


# Subnet Modification to create Public IP on Launch
aws ec2 modify-subnet-attribute --region $REGION  --subnet-id $subnetId2 --map-public-ip-on-launch


# Get the AMI ID for the Ubuntu
echo "Fetching AMI ID for Ubunut for the $REGION"
amiId=$(aws ec2 describe-images --owners 099720109477 --region $REGION \
    --filters "Name=name,Values=ubuntu/images/hvm-ssd/ubuntu-*-18.04-amd64-server-*" \
    --query 'sort_by(Images,&CreationDate)[-1].ImageId' --output text | sort -k2 -r | head -n1 )


echo "Creating a KeyPair"
aws ec2 create-key-pair --region $REGION  --key-name ${PREFIX}demo --query 'KeyMaterial' --output text > ${PREFIX}demo.pem



echo "Creating an ec2 instance"
#Create ec2 instance in the Subnet1 using the ${PREFIX}demo keypair and associate the security Group
aws ec2 run-instances  --image-id $amiId --instance-type $instance_type --region $REGION \
                       --subnet-id $subnetId1 --associate-public-ip-address  --security-group-ids $webSgId  \
                       --key-name ${PREFIX}demo --no-cli-auto-prompt  \
                       --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value="'${PREFIX}'-instanceA1"}]'


aws ec2 run-instances  --image-id $amiId --instance-type $instance_type --region $REGION \
                       --subnet-id $subnetId1 --associate-public-ip-address  --security-group-ids $webSgId  \
                       --key-name ${PREFIX}demo --no-cli-auto-prompt  \
                       --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value="'${PREFIX}'-instanceA2"}]'



# Create 2 instances in Subnet 2

#Create ec2 instance in the Subnet1 using the ${PREFIX}demo keypair and associate the security Group
aws ec2 run-instances  --image-id $amiId --instance-type $instance_type --region $REGION \
                       --subnet-id $subnetId2 --associate-public-ip-address  --security-group-ids $webSgId  \
                       --key-name ${PREFIX}demo --no-cli-auto-prompt  \
                       --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value="'${PREFIX}'-instanceB1"}]'


aws ec2 run-instances  --image-id $amiId --instance-type $instance_type --region $REGION \
                       --subnet-id $subnetId2 --associate-public-ip-address  --security-group-ids $webSgId  \
                       --key-name ${PREFIX}demo --no-cli-auto-prompt  \
                       --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value="'${PREFIX}'-instanceB2"}]'



