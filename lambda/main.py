import boto3
import os
import json
import requests
import urllib.parse

client_s3 = boto3.client("s3")
client_ssm = boto3.client("ssm")

scan_files_api_key = get_ssm_parameter(client_ssm, os.environ["SCAN_FILES_API_KEY_PARAMETER_NAME"])
scan_files_url = os.environ["SCAN_FILES_URL"]

def handler(event, context):
    "Lambda handler invoked when a new object is created in the S3 bucket"

    # Get the s3 bucket and object key from the event
    bucket = event["Records"][0]["s3"]["bucket"]["name"]
    object_key = urllib.parse.unquote_plus(event["Records"][0]["s3"]["object"]["key"], encoding="utf-8")

    # Retrieve the file from S3, trigger the scan and tag the object
    print(f"Scanning object {object_key} from bucket {bucket}")
    s3_object = get_s3_object(client_s3, bucket, object_key)
    response = start_scan(scan_files_url, scan_files_api_key, s3_object)
    tag_s3_object(client_s3, bucket, object_key, response)  

    # Response from Scan Files API
    return {
        "statusCode": response.status_code,
        "headers": {
            "Content-Type": "application/json"
        },
        "body": response.json()
    }


def get_ssm_parameter(client, param_name):
    "Rtrieve a parameter value from SSM"
    response = client.get_parameters(Names=[param_name], WithDecryption=True)
    return response["Parameters"][0]["Value"]


def get_s3_object(client, bucket, key):
    "Retrieve an S3 object from a bucket"
    response = client.get_object(Bucket=bucket, Key=key)
    return response["ContentType"]


def tag_s3_object(client, bucket, key, response):
    "Tags an S3 object with the scan results"

    # Set the tags based on the Scan Files API response code
    tags = [{"Key": "scan_status", "Value": "FAILED_TO_SCAN"}]
    if response.status_code == 200:
        tags = [
            {"Key": "scan_id", "Value": response.json()["scan_id"]}, 
            {"Key": "scan_status", "Value": "IN_PROGRESS"}
        ]
    client.put_object_tagging(
        Bucket=bucket,
        Key=key,    
        Tagging={"TagSet": tags}
)


def start_scan(scan_files_url, api_key, s3_object):
    "Triggers a scan on the given S3 object"
    headers = {
        "Content-Type": "multipart/form-data",
        "Accept": "application/json",
        "Authorization": api_key
    }
    return requests.post(
        f"{scan_files_url}/assemblyline",         
        files={"file": s3_object},
        headers=headers
    )