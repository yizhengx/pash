import boto3
import sys

# range format: bytes=start-end (Note: )
# indicator format: 0->first_split, 1->middle_split, -1->last_split
bucket_name, object_key, outfile, index, total_split = sys.argv[1:]
index = int(index)
total_split=int(total_split)

file_size = 0
if object_key=="32K.txt":
    file_size = 32*1024
elif object_key=="100K.txt":
    file_size = 100*1024
elif object_key=="1M.txt":
    file_size = 1000*1024
elif object_key=="100M.txt":
    file_size = 100*1000*1024
normal_range = file_size//total_split + (file_size%total_split>0)
start = 0+normal_range*(index-1)
end = start+normal_range-1
extra_buffer = 200
s3_range = "bytes="+str(start)+"-"+str(end+extra_buffer)

session = boto3.Session()

s3 = session.client("s3")

response = s3.get_object(Bucket=bucket_name, Key=object_key, Range=s3_range)

with open(outfile, "w") as f:
    body = response["Body"].read()
    start, end = 0, len(body)-1
    # discard the chars before first \n in normal range
    if index!=1:
        for i in range(len(body)):
            # ASCII Code for \n
            if body[i]==10:
                start = i+1
                break
    # discard chars after first \n in extra range
    if index!=total_split:
        for i in range(normal_range, len(body)):
            if body[i]==10:
                end = i
                break
    print(body[start:end+1].decode("utf-8"), file=f, end="")
    # print(response["Body"].read().decode("utf-8"), file=f, end="")

