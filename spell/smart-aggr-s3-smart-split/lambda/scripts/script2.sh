#!/bin/bash

cd "$(dirname $0)"

num=$1
data=$2
id=$3

rm_pash_fifos() {
	rm -f /tmp/{data,fifo{1..4}}
}

mkfifo_pash_fifos() {
	mkfifo /tmp/{data,fifo{1..4}}
}

rm_pash_fifos
mkfifo_pash_fifos
pids_to_kill=""

# python ../aws/s3-get-object.py yizhengx $data$id /tmp/data &
python ../aws/s3-get-object-offset.py yizhengx $data /tmp/data $id 2 &
pids_to_kill="${!} ${pids_to_kill}"

tr A-Z a-z </tmp/data >/tmp/fifo1 &
pids_to_kill="${!} ${pids_to_kill}"

python ../aws/s3-put-object.py yizhengx data2$id /tmp/fifo1 &
pids_to_kill="${!} ${pids_to_kill}"

source ../other/wait_for_output_and_sigpipe_rest.sh ${!}

should_aggregate=$(python ../aws/dynamodb-update-item.py table aggr2 $id)

if [[ $should_aggregate == 1 ]]
then
	python ../aws/lambda-invoke.py lambda data2 0 $((num+1))
fi

rm_pash_fifos

( exit "${internal_exec_status}" )
