#!/bin/bash

aws dynamodb create-table \
	--table-name table \
	--attribute-definitions \
		AttributeName=id,AttributeType=S \
	--key-schema \
		AttributeName=id,KeyType=HASH \
	--provisioned-throughput \
		ReadCapacityUnits=5,WriteCapacityUnits=5 \
	--table-class STANDARD | cat

for i in 2 4
do
	aws dynamodb put-item \
		--table-name table \
		--item '{"id": {"S": "'aggr$i'"}, "w1": {"S": "0"}, "w2": {"S": "0"}}'
done

aws s3api create-bucket --bucket yizhengx --region us-east-1 | cat

aws s3 cp 32K.txt s3://yizhengx/32K.txt
