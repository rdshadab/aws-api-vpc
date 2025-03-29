cd api
rm api_lambda_functions_create_vpc.zip
mkdir create_vpc_package
cp lambda_functions/create_vpc/lambda_function.py create_vpc_package/
# cp -r terraform_code create_vpc_package/  # Copy the entire terraform directory
# cp terraform_binary/terraform create_vpc_package/ # Assuming Linux Terraform binary is in 'terraform_binary'

cd create_vpc_package
zip -r ../api_lambda_functions_create_vpc.zip .
cd ..
rm -rf create_vpc_package


rm api_lambda_functions_get_vpc.zip
mkdir get_vpc_package
cp lambda_functions/get_vpc/lambda_function.py get_vpc_package/
# cp -r terraform_code create_vpc_package/  # Copy the entire terraform directory
# cp terraform_binary/terraform create_vpc_package/ # Assuming Linux Terraform binary is in 'terraform_binary'

cd get_vpc_package
zip -r ../api_lambda_functions_get_vpc.zip .
cd ..
rm -rf get_vpc_package