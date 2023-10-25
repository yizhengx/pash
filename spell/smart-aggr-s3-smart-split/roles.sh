#!/bin/bash

# Create new lambda execution role
aws iam create-role \
	--role-name lambda-ex \
	--assume-role-policy-document file://policies/trust-policy.json

# Create DynamoDB access policy
aws iam create-policy \
	--policy-name DynamoDBGetPutUpdateItemPolicy \
	--policy-document file://policies/dynamodb-put-get-updateitem.json

# Create lambda invocation policy (so lambdas can call other lambdas)
aws iam create-policy \
	--policy-name LambdaInvokeOtherLambdasPolicy \
	--policy-document file://policies/lambda-invoke-function.json

# Create S3 access policy
aws iam create-policy \
	--policy-name S3PutGetListBucketsPolicy \
	--policy-document file://policies/s3-put-get-listbuckets.json

# Create SQS access policy
aws iam create-policy \
	--policy-name LambdaSQSPolicy \
	--policy-document file://policies/sqs-send-message.json

# TODO Fill your AWS account ID here
ACCOUNT_ID=...

# Attach policies to the newly created lambda execution role
aws iam attach-role-policy \
	--role-name lambda-ex \
	--policy-arn arn:aws:iam::$ACCOUNT_ID:policy/DynamoDBGetPutUpdateItemPolicy

aws iam attach-role-policy \
	--role-name lambda-ex \
	--policy-arn arn:aws:iam::$ACCOUNT_ID:policy/LambdaInvokeOtherLambdasPolicy

aws iam attach-role-policy \
	--role-name lambda-ex \
	--policy-arn arn:aws:iam::$ACCOUNT_ID:policy/S3PutGetListBucketsPolicy

aws iam attach-role-policy \
	--role-name lambda-ex \
	--policy-arn arn:aws:iam::$ACCOUNT_ID:policy/LambdaSQSPolicy
