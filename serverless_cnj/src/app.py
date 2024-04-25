import json
import requests
import boto3
import os
import logging
from botocore.exceptions import ClientError

def lambda_handler(event, context):
    logger = logging.getLogger(__name__)
    logger.setLevel(logging.INFO)
    # logger.info("request: " + json.dumps(event))


    response = requests.get("https://api.chucknorris.io/jokes/random")
    print(response.text)
    response_json = json.loads(response.text)

    cnj = response_json["value"]


    topic_arn = os.environ.get('TOPIC_ARN')

    sns_client = boto3.client("sns")

    try:
        sent_message = sns_client.publish(
            TargetArn=topic_arn,
            Message=cnj
        )
        
    

        if sent_message is not None:
            logger.info(f"Success - Message ID: {sent_message['MessageId']}")
        return {
            "statusCode": 200,
            "body": json.dumps(event)
        }

    except ClientError as e:
        logger.error(e)
        return None

    # return {
    #     'statusCode': 200,
    #     'body': json.dumps(response_json["value"])
    # }


    