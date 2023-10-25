#!/bin/bash

# for i in 1 2 3 4 5
# do
# 	rm -f $i.zip
# 	zip -j $i.zip $i/*
# 	aws lambda delete-function --function-name $i
# 	aws lambda create-function \
# 		--function-name $i \
# 		--zip-file fileb://$i.zip \
# 		--handler lambda_function.lambda_handler \
# 		--runtime python3.10 \
# 		--role arn:aws:iam::192165654483:role/lambda-ex \
# 		--memory 2048 \
# 		--timeout 30 | cat
# done

rm -f lambda.zip

cd lambda
zip -r ../lambda.zip .
cd ..

aws lambda delete-function --function-name lambda
aws lambda create-function \
	--function-name lambda \
	--zip-file fileb://lambda.zip \
	--handler lambda-function.lambda_handler \
	--runtime python3.10 \
	--role arn:aws:iam::192165654483:role/lambda-ex \
	--memory 2048 \
	--timeout 30 | cat
