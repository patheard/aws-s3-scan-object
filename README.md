# AWS scan object
Lambda function that triggers a [scan](https://scan-files.alpha.canada.ca) of newly created S3 objects and updates the object with the scan results via an SNS topic subscription.

The function is invoked by `s3:ObjectCreated:*` events and messages published to its SNS `s3-object-scan-complete` topic.

```sh
make docker
make tfapply
```

# ⚠️ Note
The first `make tfapply` on a fresh account will fail since the Elastic Container Register (ECR) won't have the Docker image needed to create the Lambda function.  You'll need to push the image once the ECR has been created and re-run `make tfapply`.

# To publish a message
If you want to test how the function handles an SNS message, you can publish a message like so:
```sh
cat > payload.json <<EOL 
{
    "av-filepath": {
        "DataType": "String",
        "StringValue": "s3://bucket-name/object-name.png"
    },
    "av-status": {
        "DataType": "String",
        "StringValue": "clean"
    }
}
EOL

aws sns publish \
    --topic-arn "arn:aws:sns:${REGION}:${ACCOUNT_ID}:s3-object-scan-complete" \
    --message "Scan results" \
    --message-attributes "$(cat payload.json)"
```

