#!/bin/bash

data=$1

if [ -z "$data" ]
then
	data=32K.txt
fi

# aws lambda invoke \
# 	--function-name 1 \
# 	--log-type Tail \
# 	--query 'LogResult' \
# 	--output text \
# 	--cli-binary-format raw-in-base64-out \
# 	out | base64 -d

# cat out

for i in 2 4
do
	aws dynamodb update-item \
		--table-name table \
		--key '{ "id": {"S": "'aggr$i'"}}' \
		--update-expression "SET w1 = :w1, w2 = :w2" \
		--expression-attribute-values '{":w1" : {"S":"0"}, ":w2" : {"S":"0"}}' \
		--return-values ALL_NEW | cat
done

num=2

aws lambda invoke \
	--function-name lambda \
	--invocation-type Event \
	--cli-binary-format raw-in-base64-out \
	--payload '{"data": "'$data'", "num": "'$num'", "id": "1"}' \
	out

aws lambda invoke \
	--function-name lambda \
	--invocation-type Event \
	--cli-binary-format raw-in-base64-out \
	--payload '{"data": "'$data'", "num": "'$num'", "id": "2"}' \
	out
# cat out

while true
do
	QUEUE_URL=https://sqs.us-east-1.amazonaws.com/192165654483/queue

	output=$(aws sqs receive-message --queue-url "$QUEUE_URL" --wait-time-seconds 1)

	if [[ "$output" == "" ]]
	then
		echo "No messages in the queue"
	else
		message_body=$(echo "$output" | jq -r '.Messages[0].Body')
		echo "Received message: $message_body"

		receipt_handle=$(echo "$output" | jq -r '.Messages[0].ReceiptHandle')

		aws sqs delete-message --queue-url "$QUEUE_URL" --receipt-handle "$receipt_handle"

		echo "Message deleted."

		# aws dynamodb get-item \
		# 	--table-name table \
		# 	--key '{"id": {"S": "data50"}}' \
		# 	--projection-expression "#attr" \
		# 	--expression-attribute-names '{"#attr": "data"}' \
		# 	--query "Item.data.S" \
		# 	--output text | cat

		aws s3 cp s3://yizhengx/data50 out
		# cat out

		break
	fi
done
