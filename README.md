# AWS scan object
Lambda function that triggers a [scan](https://scan-files.alpha.canada.ca) of newly created S3 objects.  The function is invoked by `s3:ObjectCreated:*` events.

```sh
make docker
make tfapply
```

# ⚠️ Note
The first `make tfapply` on a fresh account will fail since the Elastic Container Register (ECR) won't have the Docker image needed to create the Lambda function.  You'll need to push the image once the ECR has been created and re-run `make tfapply`.

