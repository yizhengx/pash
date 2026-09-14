# Plain-bash-over-S3 baseline for analyze-access-logs (mirrors the log-summary
# .bash.sh): read each object from S3, run the same pure_func, write back to S3.
IN=agent/inputs/access/
OUT=agent/outputs/terminal-bench-analyze-access-logs.bash/
MANIFEST=${MANIFEST:-$PASH_TOP/evaluation/benchmarks/agent/access.txt}
ENTRIES=${ENTRIES:-1}

echo "ENTRIES=$ENTRIES"

pure_func() {
    tmp=$(mktemp)
    cat > "$tmp"
    total=$(wc -l < "$tmp")
    uips=$(awk '{print $1}' "$tmp" | sort -u | wc -l)
    e404=$(awk '$9=="404"' "$tmp" | wc -l)
    top=$(awk '{print $7}' "$tmp" | sort | uniq -c | sort -nr | head -3)
    printf 'Total requests: %s\n' "$total"
    printf 'Unique IP addresses: %s\n' "$uips"
    printf 'Top 3 URLs:\n'
    printf '%s\n' "$top" | awk '{printf "  %s: %d\n", $2, $1}'
    printf '404 errors: %s\n' "$e404"
    rm -f "$tmp"
}
export -f pure_func

# Simulate agent thinking/reasoning time
sleep 454

for fname in $(cat "$MANIFEST"); do
    for i in $(seq 1 "$ENTRIES"); do
        python3 $PASH_TOP/aws/s3-get-object.py "$IN$fname" /dev/stdout | pure_func | python3 $PASH_TOP/aws/s3-put-object.py "${OUT}report.${fname}.${i}.stdout" /dev/stdin
    done
done

echo "Done"
