# Plain-bash-over-S3 baseline for count-call-stack (mirrors log-summary .bash.sh):
# read each object from S3, run the same pure_func, write back to S3.
IN=agent/inputs/callstack/
OUT=agent/outputs/terminal-bench-count-call-stack.bash/
MANIFEST=${MANIFEST:-$PASH_TOP/evaluation/benchmarks/agent/callstack.txt}
ENTRIES=${ENTRIES:-1}

echo "ENTRIES=$ENTRIES"

pure_func() {
    tmp=$(mktemp); sigs=$(mktemp)
    cat > "$tmp"
    awk '
        function flush(){ if(nf>0){ s=fr[1]; for(k=2;k<=3 && k<=nf;k++) s=s "@@@" fr[k]; print s } }
        /^[0-9]+$/ { if(started) flush(); started=1; nf=0; next }
        /^[[:space:]]*in / { if(nf<3){ line=$0; sub(/^[[:space:]]*in[[:space:]]+/,"",line); nf++; fr[nf]=line } next }
        END { if(started) flush() }
    ' "$tmp" > "$sigs"
    total=$(grep -cE '^[0-9]+$' "$tmp")
    analyzed=$(wc -l < "$sigs")
    uniqc=$(sort "$sigs" | uniq | wc -l)
    printf 'Found %s stack traces\n' "$total"
    printf 'Number of unique call sites (based on top 3 frames): %s\n' "$uniqc"
    printf 'Total stack traces analyzed: %s\n\n' "$analyzed"
    printf 'Most common call sites:\n'
    sort "$sigs" | uniq -c | sort -rn | head -10 | awk '
        { match($0,/^ *[0-9]+ /); cnt=substr($0,1,RLENGTH); gsub(/ /,"",cnt); rest=substr($0,RLENGTH+1);
          n=split(rest, fm, "@@@");
          printf "\n%d. Count: %s\n", ++rank, cnt;
          for(k=1;k<=n;k++) printf "   Frame %d: %s\n", k, fm[k];
        }'
    rm -f "$tmp" "$sigs"
}
export -f pure_func

# Simulate agent thinking/reasoning time
sleep 150

for fname in $(cat "$MANIFEST"); do
    for i in $(seq 1 "$ENTRIES"); do
        python3 $PASH_TOP/aws/s3-get-object.py "$IN$fname" /dev/stdout | pure_func | python3 $PASH_TOP/aws/s3-put-object.py "${OUT}callsites.${fname}.${i}.stdout" /dev/stdin
    done
done

echo "Done"
