#!/bin/bash
# Input preparation for the `agent` benchmark. One dataset per benchmark script,
# each wrapped in its own function; both write a manifest and upload to S3.
#
#   ./inputs.sh log-summary     # terminal-bench-log-summary.sh  -> inputs/logs/,  logs.txt
#   ./inputs.sh intrusion       # terminal-bench-intrusion-*.sh  -> inputs/intrusion/, intrusion.txt
#   ./inputs.sh all             # both
#
# S3 layout (read by the serverless runs):  s3://$AWS_BUCKET/agent/inputs/<dataset>/
set -u
cd "$(dirname "$0")" || exit 1
: "${PASH_TOP:?PASH_TOP not set}"
: "${AWS_BUCKET:?AWS_BUCKET not set}"
S3_BASE="agent/inputs"

# ---------------------------------------------------------------------------
# log-summary: NBASE distinct ~SIZE_MB files generated + uploaded, then fanned
# out to NTOTAL objects via server-side S3 copies (so 100s of GB never sit on
# local disk).  Writes logs.txt with all NTOTAL names.
#   NBASE=50 NTOTAL=1000 SIZE_MB=100
# ---------------------------------------------------------------------------
gen_log_summary() {
    local NBASE=${NBASE:-50} NTOTAL=${NTOTAL:-1000} SIZE_MB=${SIZE_MB:-100}
    local S3_PREFIX="$S3_BASE/logs" AVG_LINE=64
    local N=$(( SIZE_MB * 1024 * 1024 / AVG_LINE ))
    local STAGE; STAGE=$(mktemp -d)

    local gen_awk='
    BEGIN {
        split("ERROR WARNING INFO INFO WARNING INFO ERROR DEBUG INFO WARNING", LV, " "); nlv = 10;
        msg[0]="Database connection established"; msg[1]="Deadlock detected in transaction ID";
        msg[2]="Disk space low: remaining"; msg[3]="Scheduled backup completed successfully";
        msg[4]="API response time exceeded threshold"; msg[5]="User login successful for user";
        msg[6]="Unhandled exception: TimeoutError"; msg[7]="Cache cleared successfully";
        msg[8]="High memory usage detected"; msg[9]="Slow query detected: execution time"; nmsg = 10;
        state = SEED;
        for (i = 0; i < N; i++) {
            state=(state*1103515245+12345)%2147483648; hh=int(state/60)%24;
            state=(state*1103515245+12345)%2147483648; mm=state%60;
            state=(state*1103515245+12345)%2147483648; ss=state%60;
            state=(state*1103515245+12345)%2147483648; lv=LV[(state%nlv)+1];
            state=(state*1103515245+12345)%2147483648; m=msg[state%nmsg];
            state=(state*1103515245+12345)%2147483648; nnum=state%10000;
            printf "%s %02d:%02d:%02d [%s] %s %d\n", DATE, hh, mm, ss, lv, m, nnum;
        }
    }'

    local srcs=(api app auth db) names=() i s nm base
    for i in $(seq 1 "$NTOTAL"); do
        s=${srcs[$(( (i-1) % 4 ))]}
        printf -v nm "2025-08-12_%s_%04d.log" "$s" "$i"
        names+=("$nm")
    done
    printf "%s\n" "${names[@]}" > logs.txt
    echo "[log-summary] wrote logs.txt with ${#names[@]} names"

    echo "[log-summary] generating + uploading $NBASE base files (~${SIZE_MB}MB each, N=$N lines)..."
    for i in $(seq 0 $((NBASE-1))); do
        nm="${names[$i]}"
        awk -v SEED="$((i+1))" -v N="$N" -v DATE="2025-08-12" "$gen_awk" > "$STAGE/$nm"
        aws s3 cp "$STAGE/$nm" "s3://$AWS_BUCKET/$S3_PREFIX/$nm" --no-progress >/dev/null
        rm -f "$STAGE/$nm"
    done
    echo "[log-summary] creating $((NTOTAL-NBASE)) server-side copies..."
    for i in $(seq "$NBASE" $((NTOTAL-1))); do
        nm="${names[$i]}"; base="${names[$(( i % NBASE ))]}"
        aws s3 cp "s3://$AWS_BUCKET/$S3_PREFIX/$base" "s3://$AWS_BUCKET/$S3_PREFIX/$nm" --no-progress >/dev/null
        if [ $(( (i+1) % 100 )) -eq 0 ]; then echo "  copied up to $((i+1))/$NTOTAL"; fi
    done
    rm -rf "$STAGE"
    echo "[log-summary] done: $NTOTAL objects under s3://$AWS_BUCKET/$S3_PREFIX/"
}

# ---------------------------------------------------------------------------
# intrusion: NFILES mixed auth+http "sensor" logs with attack patterns + source
# IPs (SSH brute force, web scans, invalid users, sudo commands) + benign noise.
# Generated locally under inputs/intrusion/, uploaded, manifest intrusion.txt.
#   NFILES=8 LINES=20000
# ---------------------------------------------------------------------------
gen_intrusion() {
    local NFILES=${NFILES:-8} SIZE_MB=${SIZE_MB:-100} AVG_LINE=88
    local LINES=${LINES:-$(( SIZE_MB * 1024 * 1024 / AVG_LINE ))}
    local DIR="inputs/intrusion" S3_PREFIX="$S3_BASE/intrusion"
    mkdir -p "$DIR"

    local gen_awk='
    BEGIN {
        na=split("45.32.67.89 61.177.172.13 185.220.101.5 103.94.12.7 45.32.67.90", ATK, " ");
        ni=split("192.168.0.34 10.0.0.44 192.168.3.10 192.168.3.14", INT, " ");
        nu=split("root admin postgres ubuntu guest test devuser", U, " ");
        nsp=split("/admin /phpmyadmin /wp-admin /manager/html /.env /config.php", SP, " ");
        nbp=split("/index.html /images/banner.jpg /documentation /favicon.ico", BP, " ");
        ncmd=split("/usr/bin/less /usr/bin/vi /bin/cat", CMD, " ");
        state = (SEED*1103515245 + 12345) % 2147483648;
        for (i = 0; i < N; i++) {
            state=(state*1103515245+12345)%2147483648; t=state%10;
            state=(state*1103515245+12345)%2147483648; dd=(state%28)+1;
            state=(state*1103515245+12345)%2147483648; hh=state%24;
            state=(state*1103515245+12345)%2147483648; mm=state%60;
            state=(state*1103515245+12345)%2147483648; ss=state%60;
            state=(state*1103515245+12345)%2147483648; pid=(state%9000)+1000;
            state=(state*1103515245+12345)%2147483648; aip=ATK[(state%na)+1];
            state=(state*1103515245+12345)%2147483648; iip=INT[(state%ni)+1];
            state=(state*1103515245+12345)%2147483648; usr=U[(state%nu)+1];
            state=(state*1103515245+12345)%2147483648; port=(state%40000)+1024;
            if (t == 0) {
                printf "Apr %02d %02d:%02d:%02d server sshd[%d]: Failed password for invalid user %s from %s port %d ssh2\n", dd,hh,mm,ss,pid,usr,aip,port;
            } else if (t < 3) {
                printf "Apr %02d %02d:%02d:%02d server sshd[%d]: Failed password for %s from %s port %d ssh2\n", dd,hh,mm,ss,pid,usr,aip,port;
            } else if (t == 3) {
                state=(state*1103515245+12345)%2147483648; cmd=CMD[(state%ncmd)+1];
                printf "Apr %02d %02d:%02d:%02d server sudo:  %s : TTY=pts/0 ; PWD=/home/%s ; USER=root ; COMMAND=%s\n", dd,hh,mm,ss,usr,usr,cmd;
            } else if (t < 6) {
                state=(state*1103515245+12345)%2147483648; sp=SP[(state%nsp)+1];
                printf "%s - - [%02d/Apr/2023:%02d:%02d:%02d +0000] GET %s HTTP/1.1 403 512\n", aip,dd,hh,mm,ss,sp;
            } else if (t < 9) {
                state=(state*1103515245+12345)%2147483648; bp=BP[(state%nbp)+1];
                printf "%s - - [%02d/Apr/2023:%02d:%02d:%02d +0000] GET %s HTTP/1.1 200 1024\n", iip,dd,hh,mm,ss,bp;
            } else {
                printf "Apr %02d %02d:%02d:%02d server sshd[%d]: Accepted password for %s from %s port %d ssh2\n", dd,hh,mm,ss,pid,usr,iip,port;
            }
        }
    }'

    local i nm
    : > intrusion.txt
    echo "[intrusion] generating $NFILES files (~${SIZE_MB}MB / $LINES lines each)..."
    for i in $(seq 1 "$NFILES"); do
        printf -v nm "sensor%03d.log" "$i"
        awk -v SEED="$i" -v N="$LINES" "$gen_awk" > "$DIR/$nm"
        echo "$nm" >> intrusion.txt
    done
    echo "[intrusion] uploading to s3://$AWS_BUCKET/$S3_PREFIX/ ..."
    aws s3 sync "$DIR/" "s3://$AWS_BUCKET/$S3_PREFIX/" --exclude '*' --include '*.log' --no-progress | tail -1
    echo "[intrusion] done: $NFILES objects; manifest intrusion.txt"
}

# ---------------------------------------------------------------------------
# access-logs: Apache/combined access logs (IP - - [date] "METHOD /url HTTP/1.1"
# status size).  Field positions match the task: $1=IP, $7=url, $9=status.
# Generated under inputs/access/, uploaded, manifest access.txt.
#   NFILES=8 SIZE_MB=100
# ---------------------------------------------------------------------------
gen_accesslog() {
    local NFILES=${NFILES:-8} SIZE_MB=${SIZE_MB:-100} AVG_LINE=90
    local LINES=${LINES:-$(( SIZE_MB * 1024 * 1024 / AVG_LINE ))}
    local DIR="inputs/access" S3_PREFIX="$S3_BASE/access"
    mkdir -p "$DIR"

    local gen_awk='
    BEGIN {
        nu=split("/ /index.html /login /logout /cart /checkout /profile /search /api/items /api/orders /css/style.css /js/app.js /images/banner.jpg /health /admin /missing-page /old-link", U, " ");
        nm=split("GET GET GET GET POST POST PUT DELETE", M, " ");
        ns=split("200 200 200 200 200 301 302 404 404 500", S, " ");
        state=(SEED*1103515245+12345)%2147483648;
        for (i=0;i<N;i++){
            state=(state*1103515245+12345)%2147483648; a=state%256;
            state=(state*1103515245+12345)%2147483648; b=state%256;
            state=(state*1103515245+12345)%2147483648; c=state%256;
            state=(state*1103515245+12345)%2147483648; d=state%256;
            state=(state*1103515245+12345)%2147483648; mth=M[(state%nm)+1];
            state=(state*1103515245+12345)%2147483648; url=U[(state%nu)+1];
            state=(state*1103515245+12345)%2147483648; st=S[(state%ns)+1];
            state=(state*1103515245+12345)%2147483648; sz=(state%9000)+100;
            state=(state*1103515245+12345)%2147483648; hh=state%24;
            printf "%d.%d.%d.%d - - [15/Nov/2024:%02d:00:00 +0000] \"%s %s HTTP/1.1\" %s %d\n", a,b,c,d, hh, mth, url, st, sz;
        }
    }'

    local i nm
    : > access.txt
    echo "[access] generating $NFILES files (~${SIZE_MB}MB / $LINES lines each)..."
    for i in $(seq 1 "$NFILES"); do
        printf -v nm "access_%03d.log" "$i"
        awk -v SEED="$i" -v N="$LINES" "$gen_awk" > "$DIR/$nm"
        echo "$nm" >> access.txt
    done
    echo "[access] uploading to s3://$AWS_BUCKET/$S3_PREFIX/ ..."
    aws s3 sync "$DIR/" "s3://$AWS_BUCKET/$S3_PREFIX/" --exclude '*' --include '*.log' --no-progress | tail -1
    echo "[access] done: $NFILES objects; manifest access.txt"
}

# ---------------------------------------------------------------------------
# call-stack: profiler stack-trace logs.  Each trace = a digits-only header line
# followed by indented "\t in <frame>" lines.  Frames drawn from a fixed pool so
# top-3-frame call sites repeat (matching the task's grouping).  Generated under
# inputs/callstack/, uploaded, manifest callstack.txt.
#   NFILES=8 SIZE_MB=100
# ---------------------------------------------------------------------------
gen_callstack() {
    local NFILES=${NFILES:-8} SIZE_MB=${SIZE_MB:-100} AVG_LINE=95
    local LINES=${LINES:-$(( SIZE_MB * 1024 * 1024 / AVG_LINE ))}
    local DIR="inputs/callstack" S3_PREFIX="$S3_BASE/callstack"
    mkdir -p "$DIR"

    # ~N lines total; ~8 frames per trace.
    local gen_awk='
    BEGIN {
        nf=split("printStack()@CallProfiling.cpp:322:3|llvm::cl::Option::addArgument()@CommandLine.cpp:448:17|llvm::MallocAllocator::Allocate()@AllocatorBase.h:85:12|llvm::StringRef::strLen()@StringRef.h:86:14|llvm::allocate_buffer()@MemAlloc.cpp:15:10|llvm::raw_ostream::operator<<()@raw_ostream.h:218:14|llvm::StringMap::insert()@StringMap.h:297:12|llvm::opt::OptTable::getOption()@OptTable.cpp|std::string::append()@basic_string.h:1225:9|llvm::cl::OptionCategory::registerCategory()@CommandLine.cpp:482:3", FR, "|");
        base="/usr/local/server/home/user1/llvm-project/";
        state=(SEED*1103515245+12345)%2147483648;
        printed=0;
        while (printed < N) {
            state=(state*1103515245+12345)%2147483648; hdr=(state%900)+1;
            print hdr; printed++;
            state=(state*1103515245+12345)%2147483648; depth=(state%8)+4;   # 4..11 frames
            for (j=0;j<depth && printed<N;j++){
                state=(state*1103515245+12345)%2147483648; fx=(state%nf)+1;
                split(FR[fx], p, "@");
                printf "\t in %s %s%s\n", p[1], base, p[2];
                printed++;
            }
        }
    }'

    local i nm
    : > callstack.txt
    echo "[callstack] generating $NFILES files (~${SIZE_MB}MB / ~$LINES lines each)..."
    for i in $(seq 1 "$NFILES"); do
        printf -v nm "trace_%03d.stack" "$i"
        awk -v SEED="$i" -v N="$LINES" "$gen_awk" > "$DIR/$nm"
        echo "$nm" >> callstack.txt
    done
    echo "[callstack] uploading to s3://$AWS_BUCKET/$S3_PREFIX/ ..."
    aws s3 sync "$DIR/" "s3://$AWS_BUCKET/$S3_PREFIX/" --exclude '*' --include '*.stack' --no-progress | tail -1
    echo "[callstack] done: $NFILES objects; manifest callstack.txt"
}

WHICH=${1:?usage: $0 <log-summary|intrusion|access|callstack|all>}
case "$WHICH" in
    log-summary) gen_log_summary ;;
    intrusion)   gen_intrusion ;;
    access)      gen_accesslog ;;
    callstack)   gen_callstack ;;
    all)         gen_log_summary; gen_intrusion; gen_accesslog; gen_callstack ;;
    *) echo "unknown dataset: $WHICH (use log-summary|intrusion|access|callstack|all)"; exit 2 ;;
esac
