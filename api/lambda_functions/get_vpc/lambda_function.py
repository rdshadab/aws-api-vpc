import json
import boto3

def lambda_handler(event, context):
    try:
        vpc_id = event['pathParameters']['vpc_id']
        dynamodb = boto3.resource('dynamodb')
        table = dynamodb.Table('VpcMetadata')
        response = table.get_item(Key={'vpc_id': vpc_id})

        if 'Item' in response:
            return {
                'statusCode': 200,
                'body': json.dumps(response['Item'])
            }
        else:
            return {
                'statusCode': 404,
                'body': json.dumps({'message': 'VPC not found'})
            }
    except Exception as e:
        return {
            'statusCode': 500,
            'body': json.dumps({'error': str(e)})
        }