#!/bin/bash

cd "$(dirname $0)"

num=$1
data=$2
id=$3

rm_pash_fifos() {
	rm -f /tmp/fifo{1..3}
}
mkfifo_pash_fifos() {
	mkfifo /tmp/fifo{1..3}
}

rm_pash_fifos
mkfifo_pash_fifos
pids_to_kill=""

python ../aws/s3-get-object.py yizhengx $data /tmp/fifo1 &
pids_to_kill="${!} ${pids_to_kill}"

../other/auto-split.sh /tmp/fifo1 /tmp/fifo2 /tmp/fifo3 &
pids_to_kill="${!} ${pids_to_kill}"

python ../aws/s3-put-object.py yizhengx data11 /tmp/fifo2 &
pids_to_kill="${!} ${pids_to_kill}"

python ../aws/s3-put-object.py yizhengx data12 /tmp/fifo3 &
pids_to_kill="${!} ${pids_to_kill}"

source ../other/wait_for_output_and_sigpipe_rest.sh ${!}

rm_pash_fifos

python ../aws/lambda-invoke.py lambda data1 1 $((num+1))

python ../aws/lambda-invoke.py lambda data1 2 $((num+1))

( exit "${internal_exec_status}" )
