import boto3
import random
import os

# Initialize S3 client
s3_client = boto3.client('s3')


def lambda_handler(event, context):
    try:
        bucket = os.environ['BUCKET_NAME']
        # Fetch the file from S3
        response = s3_client.get_object(Bucket=bucket, Key='jokes.txt')
        file_content = response['Body'].read().decode()

        # Split the content by lines and choose a random joke
        jokes = file_content.splitlines()
        random_joke = random.choice(jokes)

        # Return the random joke in the response
        return {
            'statusCode': 200,
            'body': random_joke
        }

    except Exception as e:
        # Return error if any exception occurs
        return {
            'statusCode': 500,
            'body': str(e)
        }
