# VPC Management API

This project provides an API for creating and retrieving Virtual Private Clouds (VPCs) in AWS. It utilizes AWS API Gateway as the entry point and backend Lambda functions (`create-vpc-lambda` and `get-vpc-lambda`) to handle the requests. VPC metadata is stored in a DynamoDB table. Authentication is handled using Cognito User Pools.

## Architecture

The architecture of this project includes the following components:

* **API Gateway:** Provides the HTTP endpoints for interacting with the VPC management service (`/vpcs` for creation and `vpcs/{vpc_id}` for retrieval).
* **Cognito User Pool:** Manages user authentication for accessing the API.
* **`create-vpc-lambda` Function:** A Python Lambda function that uses the AWS SDK (boto3) to create the VPC, subnets, internet gateway, and route table based on the input received from API Gateway.
* **`get-vpc-lambda` Function:** A Python Lambda function that retrieves details of a specific VPC from AWS using boto3, based on the `vpc_id` provided in the API request.
* **DynamoDB Table (`VpcMetadata`):** Stores metadata about the created VPCs, with `vpc_id` as the primary key.
* **IAM Roles and Policies:** Define the necessary permissions for each AWS resource to interact with other services.
* **S3 Backend for Terraform:** Stores the Terraform state file.

## Prerequisites

Before deploying this project, ensure you have the following:

* **AWS Account:** You need an active AWS account.
* **AWS CLI:** The AWS Command Line Interface should be installed and configured with credentials that have the necessary permissions to create and manage the AWS resources used in this project.
* **Terraform:** Terraform (version >= 1.0) should be installed on your local machine.
* **Python 3.x:** Python 3 is required to run the Lambda function code locally (for testing).
* **ZIP Utility:** A ZIP utility is needed to create the Lambda function deployment packages.

## Deployment

The infrastructure for this project is managed using Terraform. Follow these steps to deploy it:

1.  **Clone the Repository (or have your Terraform files ready):** Ensure you have all the Terraform configuration files (`.tf`) in a local directory, along with the Lambda function code files. The expected file structure is:

    ```
    your-project-root/
    ├── api/
    │   ├── api_lambda_functions_create_vpc.zip
    │   └── api_lambda_functions_get_vpc.zip
    └── your_terraform_files.tf  (e.g., main.tf, lambda.tf, apigateway.tf)
    ```

2.  **Create Lambda Function ZIP Files:**
    * **`api/api_lambda_functions_create_vpc.zip`:** This ZIP file should contain the `lambda_function.py` for your `create-vpc-lambda` function (which uses boto3 for VPC creation) and any other necessary dependencies.
    * **`api/api_lambda_functions_get_vpc.zip`:** This ZIP file should contain the `lambda_function.py` for your `get-vpc-lambda` function and any dependencies.

3.  **Initialize Terraform:** Navigate to the directory containing your Terraform files in your terminal and run:

    ```bash
    terraform init
    ```

4.  **Plan the Deployment:** Review the resources that Terraform will create or modify:

    ```bash
    terraform plan
    ```

5.  **Apply the Terraform Configuration:** Deploy the infrastructure to your AWS account:

    ```bash
    terraform apply
    ```

    You will be prompted to confirm the deployment by typing `yes`.

6.  **Note API Gateway Endpoint:** After the deployment is successful, Terraform will output the invoke URL of your API Gateway. Make note of this URL.

## Configuration

The Terraform configuration allows you to customize various aspects of the deployment, such as:

* **AWS Region:** Defined in the `provider` block.
* **S3 Bucket Name for Terraform State:** Defined in the `backend "s3"` block. Ensure this bucket exists or Terraform will create it (if permissions allow).
* **DynamoDB Table Name:** Currently set to `VpcMetadata`.
* **Cognito User Pool Name and Client Configuration:** Configured in the `aws_cognito_user_pool` and `aws_cognito_user_pool_client` resources.
* **`create-vpc-lambda` and `get-vpc-lambda` Function Configurations:** Runtime, handler, memory size, timeout, and environment variables.
* **API Gateway Configuration:** Paths, methods, authorizers, and integrations.

You can modify these configurations in the respective Terraform files as needed.

## Usage

1.  **Sign Up/Sign In to Cognito:** Use the AWS CLI or a frontend application integrated with your Cognito User Pool to sign up and sign in to obtain an ID token.

2.  **Create a VPC:** Send a `POST` request to the `/vpcs` endpoint of your API Gateway invoke URL. Include the necessary VPC configuration parameters in the JSON request body. You will need to include your Cognito ID token in the `Authorization` header of the request.

    **Example Request Body:**

    ```json
    {
        "vpc_cidr": "10.5.0.0/16",
        "public_subnets": ["10.5.1.0/24", "10.5.2.0/24"],
        "private_subnets": ["10.5.3.0/24", "10.5.4.0/24"],
        "availability_zones": ["us-east-1a", "us-east-1b"],
        "tags": [{"Key": "Environment", "Value": "Staging"}]
    }
    ```

    The API will directly invoke the `create-vpc-lambda` function.

3.  **Retrieve VPC Details:** Send a `GET` request to the `/vpcs/{vpc_id}` endpoint of your API Gateway invoke URL, replacing `{vpc_id}` with the ID of the VPC you want to retrieve. Include your Cognito ID token in the `Authorization` header.

    **Example Request URL:**

    ```
    https://your-api-gateway-invoke-url/prod/vpcs/vpc-xxxxxxxxxxxxxxxxx
    ```

    The API will return a 200 OK response with the details of the requested VPC in JSON format.

## Cleanup

To remove all the resources created by this project, run the following command in your terminal from the directory containing your Terraform files:

```bash
terraform destroy