# Plain-bash-over-S3 baseline for the rule-driven intrusion-detection benchmark
# (mirrors terminal-bench-log-summary.bash.sh): reads each object from S3 and
# writes each result back to S3 via the aws/ helpers, same rules/pure_func as
# the PaSh version.
IN=agent/inputs/intrusion/
OUT=agent/outputs/terminal-bench-intrusion-detection.bash/
MANIFEST=${MANIFEST:-$PASH_TOP/evaluation/benchmarks/agent/intrusion.txt}
RULES=${RULES:-$PASH_TOP/evaluation/benchmarks/agent/detection_rules.json}
ENTRIES=${ENTRIES:-50}

pure_func() {
    id="$1"; pat="$2"; sev="$3"
    ipre='([0-9]{1,3}\.){3}[0-9]{1,3}'
    tmp=$(mktemp)
    cat > "$tmp"
    cnt=$(grep -Ec "$pat" "$tmp")
    ips=$(grep -E "$pat" "$tmp" | grep -Eo "$ipre" | sort -u | paste -sd, -)
    printf '%s,%s,%s,%s\n' "$id" "$sev" "$cnt" "$ips"
    rm -f "$tmp"
}
export -f pure_func

rules_tsv=$(mktemp)
jq -r '.rules[] | [.id, .pattern, .severity] | @tsv' "$RULES" > "$rules_tsv"

TAB=$(printf '\t')
while IFS="$TAB" read -r id pattern severity; do
    for fname in $(cat "$MANIFEST"); do
        for i in $(seq 1 "$ENTRIES"); do
            python3 $PASH_TOP/aws/s3-get-object.py "$IN$fname" /dev/stdout | pure_func "$id" "$pattern" "$severity" | python3 $PASH_TOP/aws/s3-put-object.py "${OUT}${id}.${fname}.${i}.stdout" /dev/stdin
        done
    done
done < "$rules_tsv"

rm -f "$rules_tsv"
echo "Done"
