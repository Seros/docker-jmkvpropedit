#!/usr/bin/with-contenv sh

set -u # Treat unset variables as an error.

trap "exit" TERM QUIT INT
trap "kill_jmpe" EXIT

log() {
    echo "[jmpesupervisor] $*"
}

getpid_jmpe() {
    PID=UNSET
    if [ -f /config/JMkvpropedit.pid ]; then
        PID="$(cat /config/JMkvpropedit.pid)"
        # Make sure the saved PID is still running and is associated to
        # JMkvpropedit.
        if [ ! -f /proc/$PID/cmdline ] || ! cat /proc/$PID/cmdline | grep -qw "JMkvpropedit.jar"; then
            PID=UNSET
        fi
    fi
    if [ "$PID" = "UNSET" ]; then
        PID="$(ps -o pid,args | grep -w "JMkvpropedit.jar" | grep -vw grep | tr -s ' ' | cut -d' ' -f2)"
    fi
    echo "${PID:-UNSET}"
}

is_jmpe_running() {
    [ "$(getpid_jmpe)" != "UNSET" ]
}

start_jmpe() {
    java \
        -Dawt.useSystemAAFontSettings=gasp \
        -Djava.awt.headless=false \
        -jar /config/JMkvpropedit.jar &> /config/logs/output.log 2>&1 &
}

kill_jmpe() {
    PID="$(getpid_jmpe)"
    if [ "$PID" != "UNSET" ]; then
        log "Terminating JMkvpropedit2..."
        kill $PID
        wait $PID
    fi
}

if ! is_jmpe_running; then
    log "JMkvpropedit not started yet.  Proceeding..."
    start_jmpe
fi

JMPE_NOT_RUNNING=0
while [ "$JMPE_NOT_RUNNING" -lt 5 ]
do
    if is_jmpe_running; then
        JMPE_NOT_RUNNING=0
    else
        JMPE_NOT_RUNNING="$(expr $JMPE_NOT_RUNNING + 1)"
    fi
    sleep 1
done

log "JMkvpropedit no longer running.  Exiting..."