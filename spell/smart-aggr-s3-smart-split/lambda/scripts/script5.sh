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

python ../aws/s3-get-object.py yizhengx ${data}1 /tmp/fifo3 &
pids_to_kill="${!} ${pids_to_kill}"

python ../aws/s3-get-object.py yizhengx ${data}2 /tmp/fifo4 &
pids_to_kill="${!} ${pids_to_kill}"

sort -m /tmp/fifo3 /tmp/fifo4 >/tmp/data &
pids_to_kill="${!} ${pids_to_kill}"

#DEBUG START
# python ../aws/s3-put-object.py yizhengx data50 /tmp/data &
# pids_to_kill="${!} ${pids_to_kill}"
#DEBUG END

uniq </tmp/data >/tmp/fifo1 &
pids_to_kill="${!} ${pids_to_kill}"

comm -1 -3 ../other/sorted_words /tmp/fifo1 >/tmp/fifo2 &
pids_to_kill="${!} ${pids_to_kill}"

python ../aws/s3-put-object.py yizhengx data50 /tmp/fifo2 &
pids_to_kill="${!} ${pids_to_kill}"

source ../other/wait_for_output_and_sigpipe_rest.sh ${!}

python ../aws/sqs-send-message.py https://sqs.us-east-1.amazonaws.com/192165654483/queue done

rm_pash_fifos
( exit "${internal_exec_status}" )
