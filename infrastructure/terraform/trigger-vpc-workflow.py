import json
import boto3
import os

def lambda_handler(event, context):
    stepfunctions = boto3.client('stepfunctions')
    state_machine_arn = os.environ.get('VPC_WORKFLOW_ARN')

    if not state_machine_arn:
        return {
            'statusCode': 500,
            'body': json.dumps({'error': 'VPC_WORKFLOW_ARN environment variable not set'})
        }

    try:
        # The API Gateway event will have a 'body' key containing the JSON payload
        request_body = json.loads(event['body']) if 'body' in event else event

        response = stepfunctions.start_execution(
            stateMachineArn=state_machine_arn,
            input=json.dumps(request_body)
        )
        return {
            'statusCode': 200,
            'body': json.dumps({'executionArn': response['executionArn'], 'message': 'VPC creation workflow started'})
        }
    except Exception as e:
        print(f"Error starting Step Function execution: {e}")
        return {
            'statusCode': 500,
            'body': json.dumps({'error': f'Failed to start VPC creation workflow: {str(e)}'})
        }