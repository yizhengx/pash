aws iam create-policy \
	--policy-name DynamoDBGetPutUpdateItemPolicy \
	--policy-document file://dynamodb-item-policy.json

aws iam get-role --role-name lambda-ex

aws iam attach-role-policy --role-name lambda-ex --policy-arn arn:aws:iam::347768412644:policy/DynamoDBGetPutUpdateItemPolicy

aws iam create-policy \
	--policy-name LambdaSQSPolicy \
	--policy-document file://lambda-sqs-policy.json

aws iam attach-role-policy \
	--role-name lambda-ex \
	--policy-arn arn:aws:iam::347768412644:policy/LambdaSQSPolicy

aws iam create-policy --policy-name S3PutGetListBucketsPolicy --policy-document file://policies/s3-put-get-listbuckets.json

aws iam attach-role-policy \
	--role-name lambda-ex \
	--policy-arn arn:aws:iam::347768412644:policy/S3PutGetListBucketsPolicy
