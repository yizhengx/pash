# Intrusion detection -- faithful to the original intrusion_detector.sh:
# iterate the detection rules in detection_rules.json and, for each rule, grep
# its pattern across the logs, count matching lines, and extract the unique
# source IPs.  Scaled for PaSh across many log files (MANIFEST) and ENTRIES
# repetitions: the offloaded unit is one (rule, file) pipeline, so PaSh emits
# one Lambda per (rule, file) under --serverless_exec --parallel_pipelines.
#
#   IN        prefix of the log files (trailing slash); S3 key prefix under -serverless.
#   OUT       output-path prefix; results go to ${OUT}<rule-id>.<file>.<i>.stdout
#   MANIFEST  file listing the log basenames, one per line.
#   RULES     detection_rules.json (same schema as the original task).
#   ENTRIES   process each file this many times (repetition scales the workload).
#   PASH_TOP  root of the pash checkout.

IN=${IN:-$PASH_TOP/evaluation/benchmarks/agent/inputs/intrusion/}
OUT=${OUT:-$PASH_TOP/evaluation/benchmarks/agent/outputs/}
MANIFEST=${MANIFEST:-$PASH_TOP/evaluation/benchmarks/agent/intrusion.txt}
RULES=${RULES:-$PASH_TOP/evaluation/benchmarks/agent/detection_rules.json}
ENTRIES=${ENTRIES:-1}

echo "ENTRIES=$ENTRIES"

mkdir -p "$OUT"

# For one rule pattern over one log file (piped on stdin): emit
#   <rule-id>,<severity>,<match-count>,<comma-separated unique source IPs>
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

# Simulate agent thinking/reasoning time
sleep 628
wait

# Load rules from JSON with jq (as in the original) into id<TAB>pattern<TAB>severity.
rules_tsv=$(mktemp)
jq -r '.rules[] | [.id, .pattern, .severity] | @tsv' "$RULES" > "$rules_tsv"

# Outer loop: detection rules (as in the original).  Inner loop: files x ENTRIES.
# The innermost loop body is a single clean pipeline so consecutive per-file
# pipelines batch into concurrent Lambdas.
TAB=$(printf '\t')
while IFS="$TAB" read -r id pattern severity; do
    for fname in $(cat "$MANIFEST"); do
        for i in $(seq 1 "$ENTRIES"); do
            cat "${IN}${fname}" | pure_func "$id" "$pattern" "$severity" > "${OUT}${id}.${fname}.${i}.stdout"
        done
    done
done < "$rules_tsv"

rm -f "$rules_tsv"
echo "Done"