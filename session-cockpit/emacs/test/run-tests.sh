#!/bin/bash
# Runs the Emacs tests in a throwaway `emacs -Q` daemon with only the plugin
# and magit-section on the load path.  A daemon rather than batch mode, since
# the tests type keys and that needs a real command loop.

set -euo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVER="session-cockpit-test-$$"
# A test waiting for input it never gets would otherwise hang the run.
TIMEOUT_SECONDS=${TIMEOUT_SECONDS:-60}

main() {
    local results
    results="$(mktemp)"
    trap "stop_emacs; rm -f '$results'" EXIT

    emacs -Q --daemon="$SERVER" > /dev/null 2>&1
    EMACS_PID="$(emacsclient -s "$SERVER" -e "(emacs-pid)")"
    SOCKET_FILE="$(emacsclient -s "$SERVER" -e "(expand-file-name server-name server-socket-dir)" | tr -d '"')"

    if ! run_with_timeout emacsclient -s "$SERVER" -e \
        "(progn (load \"$TEST_DIR/run-tests.el\") (session-cockpit-run-tests \"$results\"))"; then
        echo "FAILED: the test run did not finish within ${TIMEOUT_SECONDS}s"
        exit 1
    fi

    cat "$results"
    ! grep -q "^FAILED" "$results"
}

run_with_timeout() {
    "$@" > /dev/null &
    local command_pid=$!
    # Detached from stdout, since its sleep would otherwise keep a reader of
    # this script's output waiting until the timeout.
    (sleep "$TIMEOUT_SECONDS" && kill "$command_pid" 2> /dev/null) > /dev/null 2>&1 &
    local watchdog_pid=$!
    local status=0
    wait "$command_pid" 2> /dev/null || status=$?
    pkill -P "$watchdog_pid" 2> /dev/null || true
    kill "$watchdog_pid" 2> /dev/null || true
    wait "$watchdog_pid" 2> /dev/null || true
    return "$status"
}

stop_emacs() {
    # By PID, since a daemon stuck in a test would not answer emacsclient.
    # SIGKILL, since on SIGTERM Emacs runs `kill-emacs-hook', which can fail
    # halfway through and make it abort with a crash report.  Nothing then
    # removes its server socket, so do that here.
    kill -KILL "${EMACS_PID:-}" 2> /dev/null || true
    rm -f "${SOCKET_FILE:-}"
}

main "$@"
