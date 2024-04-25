import json
import requests
import boto3

def lambda_handler(event, context):
    response = requests.get("https://api.chucknorris.io/jokes/random")
    print(response.text)
    response_json = json.loads(response.text)

    print(response_json["value"])

    return {
        'statusCode': 200,
        'body': json.dumps(response_json["value"])
    }


    