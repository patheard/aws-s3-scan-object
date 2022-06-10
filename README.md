# AWS scan object
Lambda function that triggers a [scan](https://scan-files.alpha.canada.ca) of newly created S3 objects.  The function is invoked by `s3:ObjectCreated:*` events.

```sh
# Init, plan and apply
cd aws/aws-s3-scan-object
terraform init
terraform plan
terraform apply
```

