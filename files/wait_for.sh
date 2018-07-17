#!/bin/bash

set -e

die(){
    echo "$2" &> /dev/stderr
    exit $1
}

[[ "$#" -ge "4" ]] || die 6 "Usage: $(basename $0) <retries> <delay> <host> <port> [port]..."
[[ -n "$(type -P ncat || type -P nc)" ]] || die 7 "Either the ncat or nc executable is required"

RETRIES=$1
shift
DELAY=$1
shift
HOST=$1
shift
PORTS=$@

TIMEOUT="$[$RETRIES * $DELAY + 1]"

for (( i=0 ; i < $RETRIES ; i++ ));
do
    for port in $PORTS
    do
        if "$(type -P ncat || type -P nc)" -z "$HOST" "$port"
        then
            echo "Try $i: $HOST:$port OPEN" > /dev/stderr
            echo "$port" > /dev/stdout
            exit 0
        else
            echo "Try $i: $HOST:$port CLOSED" > /dev/stderr
        fi
    done
    sleep "$DELAY"
done
echo "Retries exceeded looking for open port" > /dev/stderr
exit 1
