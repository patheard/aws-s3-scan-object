docker:
	docker build -t s3-scan-object:latest lambda

tfapply:
	terraform -chdir=aws/s3-scan-object apply

tfplan:
	terraform -chdir=aws/s3-scan-object plan

.PHONY: \
	docker \
	tfapply \
	tfplan