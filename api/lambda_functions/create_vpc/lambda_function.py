import json
import subprocess
import os
import boto3
import shutil


# def lambda_handler(event, context):

#     print('## ENVIRONMENT VARIABLES')
#     print(os.environ['AWS_LAMBDA_LOG_GROUP_NAME'])
#     print(os.environ['AWS_LAMBDA_LOG_STREAM_NAME'])
#     print('## EVENT')
#     print(event)
#     try:

#         d = json.loads(event['body'])
#         # Prepare Terraform command and variables
#         vpc_cidr = d['vpc_cidr']
#         public_subnets = d['public_subnets']
#         private_subnets = d['private_subnets']
#         availability_zones = d['availability_zones']

#         # Navigate to Terraform directory
#         terraform_dir = "/tmp/terraform_code"
#         os.makedirs(terraform_dir, exist_ok=True)

#         # Source directory within the Lambda deployment package
#         source_terraform_dir = os.path.join(os.getcwd(), "terraform_code")

#         print(f"Source Terraform directory: {source_terraform_dir}")
#         print(f"Destination Terraform directory: {terraform_dir}")
#         print(f"Files in source Terraform directory: {os.listdir(source_terraform_dir)}")


#         # Copy Terraform files from the deployment package to /tmp/terraform_code
#     #     if os.path.exists(source_terraform_dir):
#     #         for item in os.listdir(source_terraform_dir):
#     #             s = os.path.join(source_terraform_dir, item)
#     #             d = os.path.join(terraform_dir, item)
#     #             if os.path.isfile(s):
#     #                 shutil.copy2(s, d)
#     #             elif os.path.isdir(s):
#     #                 shutil.copytree(s, d, dirs_exist_ok=True)
#     #     else:
#     #         raise Exception(f"Terraform configuration directory not found in the deployment package at: {source_terraform_dir}")

#     #     # Navigate to Terraform directory in /tmp
#     #     os.chdir(terraform_dir)

#     #    # Write the input variables into a tfvars file.
#     #     with open("terraform.tfvars", "w") as f:
#     #         f.write(f"vpc_cidr = \"{vpc_cidr}\"\n")
#     #         f.write(f"public_subnet_cidrs = [\"{public_subnets[0]}\", \"{public_subnets[1]}\"]\n")
#     #         f.write(f"private_subnet_cidrs = [\"{private_subnets[0]}\", \"{private_subnets[1]}\"]\n")
#     #         f.write(f"availability_zones = [\"{availability_zones[0]}\", \"{availability_zones[1]}\"]\n")

#     #     # Define the path to the Terraform binary
#     #     terraform_binary_path = os.path.join(os.getcwd(), "terraform")

#     #     # Make the Terraform binary executable
#     #     if os.path.exists(terraform_binary_path):
#     #         subprocess.run(["chmod", "+x", terraform_binary_path], check=True)
#     #     else:
#     #         raise Exception(f"Terraform binary not found at: {terraform_binary_path}")

#     #     # Initialize Terraform
#     #     # subprocess.run([terraform_binary_path, "init"], check=True)

#     #     # Apply Terraform
#     #     subprocess.run([terraform_binary_path, "apply", "-auto-approve"], capture_output=True, text=True, check=True)
        

#     #     # Parse Terraform output
#     #     output = subprocess.run([terraform_binary_path, "output", "-json"], capture_output=True, text=True, check=True)
#     #     terraform_output = json.loads(output.stdout)

        
#         vpc = ec2.create_vpc(CidrBlock=vpc_cidr)
#         # Assign a name to the VPC
#         vpc.create_tags(Tags=[{"Key": "Name", "Value": "my_vpc"}])
#         vpc.wait_until_available()
#         print(vpc.id)

#         # Create and Attach the Internet Gateway
#         ig = ec2.create_internet_gateway()
#         vpc.attach_internet_gateway(InternetGatewayId=ig.id)
#         print(ig.id)

#         # Create a route table and a public route to Internet Gateway
#         route_table = vpc.create_route_table()
#         route = route_table.create_route(
#             DestinationCidrBlock='0.0.0.0/0',
#             GatewayId=ig.id
#         )
#         print(route_table.id)

#         # Create a Subnet
#         subnet = ec2.create_subnet(CidrBlock='192.168.1.0/24', VpcId=vpc.id)
#         print(subnet.id)

#         # associate the route table with the subnet
#         route_table.associate_with_subnet(SubnetId=subnet.id)



#         # Store results in DynamoDB
#         dynamodb = boto3.resource('dynamodb')
#         table = dynamodb.Table('VpcMetadata')
#         table.put_item(
#             Item={
#                 'vpc_id': terraform_output['vpc_id']['value'],
#                 'public_subnet_ids': terraform_output['public_subnet_ids']['value'],
#                 'private_subnet_ids': terraform_output['private_subnet_ids']['value'],
#                 'request_data': event
#             }
#         )

#         return {
#             'statusCode': 200,
#             'body': json.dumps(terraform_output)
#         }
#     except subprocess.CalledProcessError as e:
#         print(f"Error running Terraform: {e}")
#         print(f"Stdout: {e.stdout}")
#         print(f"Stderr: {e.stderr}")  # Log the stderr
#         return {
#             'statusCode': 500,
#             'body': json.dumps({'error': f'Terraform apply failed: {e.stderr}'}) # Return stderr in the error
#         }
#     except FileNotFoundError as e:
#         return {
#             'statusCode': 500,
#             'body': json.dumps({'error': str(e)})
#         }
#     except Exception as e:
#         return {
#             'statusCode': 500,
#             'body': json.dumps({'error': str(e)})
#         }
ec2 = boto3.client('ec2')
dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table('VpcResources')

def lambda_handler(event, context):
    try:

        d = json.loads(event['body'])
        # Prepare Terraform command and variables
        vpc_cidr = d['vpc_cidr']
        public_subnets = d['public_subnets']
        private_subnets = d['private_subnets']
        availability_zones = d['availability_zones']
        request_data = json.loads(event['body'])
        vpc_cidr = d['vpc_cidr']
        subnet_cidr_1 = public_subnets[0]
        subnet_cidr_2 = public_subnets[1]
        az1 = availability_zones[0]
        az2 = availability_zones[1]
        # Create VPC
        vpc_response = ec2.create_vpc(CidrBlock=vpc_cidr)
        vpc_id = vpc_response["Vpc"]["VpcId"]
        print(f"Created VPC: {vpc_id}")
        
        ec2.modify_vpc_attribute(VpcId=vpc_id, EnableDnsSupport={"Value": True})
        ec2.modify_vpc_attribute(VpcId=vpc_id, EnableDnsHostnames={"Value": True})

        # Assign a name to the VPC
        igw_response = ec2.create_internet_gateway()
        igw_id = igw_response["InternetGateway"]["InternetGatewayId"]
        ec2.attach_internet_gateway(VpcId=vpc_id, InternetGatewayId=igw_id)
        print(f"Created and attached Internet Gateway: {igw_id}")

        route_table_response = ec2.create_route_table(VpcId=vpc_id)
        route_table_id = route_table_response["RouteTable"]["RouteTableId"]
        ec2.create_route(RouteTableId=route_table_id, DestinationCidrBlock="0.0.0.0/0", GatewayId=igw_id)
        print(f"Created Route Table: {route_table_id}")

        
        subnets = []
        
        subnet_response1 = ec2.create_subnet(
                VpcId=vpc_id, 
                CidrBlock=subnet_cidr_1, 
                AvailabilityZone=az1
            )
        subnet_id1 = subnet_response1["Subnet"]["SubnetId"]
        subnets.append(subnet_id1)
        print(f"Created Subnet: {subnet_id1} in {az1}")

        # Associate Route Table with Subnet
        ec2.associate_route_table(SubnetId=subnet_id1, RouteTableId=route_table_id)
        

        subnet_response2 = ec2.create_subnet(
                VpcId=vpc_id, 
                CidrBlock=subnet_cidr_2, 
                AvailabilityZone=az2
            )
        subnet_id2 = subnet_response2["Subnet"]["SubnetId"]
        subnets.append(subnet_id2)
        print(f"Created Subnet: {subnet_id2} in {az2}")

        # Associate Route Table with Subnet
        ec2.associate_route_table(SubnetId=subnet_id2, RouteTableId=route_table_id)


        # Store VPC details in DynamoDB
        vpc_data = {
            "vpc_id": vpc_id,
            "vpc_cidr": vpc_cidr,
            "subnets": [
                {"subnet_id": subnet_id1, "cidr": subnet_cidr_1},
                {"subnet_id": subnet_id2, "cidr": subnet_cidr_2}
            ]
        }
        table.put_item(Item=vpc_data)

        return {
            "statusCode": 201,
            "body": json.dumps({"message": "VPC created", "vpc": vpc_data})
        }

    except Exception as e:
        return {"statusCode": 500, "body": json.dumps({"error": str(e)})}