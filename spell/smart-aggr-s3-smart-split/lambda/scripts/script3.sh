#!/bin/bash

cd "$(dirname $0)"

num=$1
data=$2
id=$3

rm_pash_fifos() {
	rm -f /tmp/{data,fifo{1..5}}
}
mkfifo_pash_fifos() {
	mkfifo /tmp/{data,fifo{1..5}}
}

rm_pash_fifos
mkfifo_pash_fifos
pids_to_kill=""

python ../aws/s3-get-object.py yizhengx ${data}1 /tmp/fifo4 &
pids_to_kill="${!} ${pids_to_kill}"

python ../aws/s3-get-object.py yizhengx ${data}2 /tmp/fifo5 &
pids_to_kill="${!} ${pids_to_kill}"

cat /tmp/fifo4 /tmp/fifo5 >/tmp/data &
pids_to_kill="${!} ${pids_to_kill}"

tr -c -s A-Za-z "\\n" </tmp/data >/tmp/fifo1 &
pids_to_kill="${!} ${pids_to_kill}"

../other/auto-split.sh /tmp/fifo1 /tmp/fifo2 /tmp/fifo3 &
pids_to_kill="${!} ${pids_to_kill}"

python ../aws/s3-put-object.py yizhengx data31 /tmp/fifo2 &
pids_to_kill="${!} ${pids_to_kill}"

python ../aws/s3-put-object.py yizhengx data32 /tmp/fifo3 &
pids_to_kill="${!} ${pids_to_kill}"

source ../other/wait_for_output_and_sigpipe_rest.sh ${!}
rm_pash_fifos

python ../aws/lambda-invoke.py lambda data3 1 $((num+1))

python ../aws/lambda-invoke.py lambda data3 2 $((num+1))

( exit "${internal_exec_status}" )
