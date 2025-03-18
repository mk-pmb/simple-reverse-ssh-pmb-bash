#!/bin/bash
# -*- coding: utf-8, tab-width: 2 -*-


function revssh_cli_init () {
  unset TASK TODO KEY VAL
  # ^- In case those were set as env vars, because unset_most_env_vars
  #    won't be able to unset them later once we've declared them locally.
  local TASK="${REVSSH_TASK:-start_server}"
  unset REVSSH_TASK # avoid accidential recursion
  [ "$TASK" != start_server ] || revssh_unset_most_env_vars || return $?$(
    echo E: $FUNCNAME: "Failed to cleanup env vars, rv=$?" >&2)

  export LANG{,UAGE}=en_US.UTF-8  # make error messages search engine-friendly
  local SELFFILE="$(readlink -m -- "$BASH_SOURCE")"
  local SELFPATH="$(dirname -- "$SELFFILE")"
  local SELFNAME="$(basename -- "$SELFFILE" .sh)"
  local SELF_BFN="$(basename -- "$SELFFILE")"
  cd -- "$SELFPATH" || return $?

  # Declare global facts:
  local TCP_MAX_PORT=65535

  revssh_"$TASK" "$@"; return "$?"
}


function revssh_start_server () {
  local LSN="TCP-LISTEN:${REVSSH_PORT:-1212}"
  LSN+=",reuseaddr,fork,$REVSSH_LSN_OPT"
  LSN="${LSN%,}"
  export REVSSH_TASK='establish_client_metadata'
  exec 2>&1
  local SOCAT_CMD=(
    exec -a revssh_server
    socat
    $REVSSH_SOCAT_OPT
    "$LSN"
    EXEC:"bash $SELF_BFN"
    )
  "${SOCAT_CMD[@]}"
  echo E: $FUNCNAME: "Failed (rv=$?) to$(
    printf -- ' ‹%s›' "${SOCAT_CMD[@]}") in $PWD" >&2
  exit 4
}


function revssh_unset_most_env_vars () {
  local TODO="$(env | cut -d = -sf 1 | tr '\n' =)"
  local KEY=
  while [ -n "${TODO%=}" ]; do
    KEY="${TODO%%=*}"
    TODO="${TODO#*=}"
    case "$KEY" in
      [^A-Za-z_]* | *[^A-Za-z0-9_-]* )
        echo E: $FUNCNAME: "Flinching: Scary env var name: '$KEY'" >&2
        return 4;;

      TASK | TODO | KEY | VAL )
        echo E: $FUNCNAME: >&2 \
          "Flinching: Env var '$KEY' should have been unset already!"
        return 4;;

      HOME | \
      LOGNAME | \
      PATH | \
      REVSSH_* | \
      '' ) continue;; # keep selected essential env vars

      * ) unset "$KEY";;
    esac
  done
}


function revssh_establish_client_metadata () {
  exec 2> >(ts "%F %T [$$]" >&2)
  local ENV_PFX=
  read -d '' -rs ENV_PFX <"/proc/$PPID/cmdline"
  ENV_PFX="${ENV_PFX^^}_"
  ENV_PFX="${ENV_PFX//[^A-Z0-9_-]/}"
  eval "$(env |
    sed -nre 's~\x27~~g; s~$~\x27~; s~^'"$ENV_PFX"'([A-Z]+)=~\1=\x27~p' |
    sed -nre 's~^SOCK~ LSN_~; s~^PEER~ DRONE_~; s~^ ~export ~p')"
  unset -- $(env | cut -d = -sf 1 | sed -nre "/^$ENV_PFX/p")
  echo D: "Drone $DRONE_ADDR:$DRONE_PORT connected to $LSN_ADDR:$LSN_PORT" >&2
  export REVSSH_TASK='negotiate'
  exec -a revssh_negotiate bash "$SELF_BFN" "$LSN_ADDR:$LSN_PORT" \
    "$DRONE_ADDR:$DRONE_PORT" || return $?$(
      echo E: "Failed to re-exec for $REVSSH_TASK" >&2)
}


function revssh_negotiate () {
  # Debug stuff:
  # local -p >&2
  # ps hu $PPID $$ >&2
  # pstree-up $$ >&2
  # env | sort -V >&2
  # revssh_debug_list_socat_sockets >&2

  local REQ_HOST= REQ_PORT=
  revssh_read_http_request || return 0

  # exec 64<>&0 ./sendfd
}


function revssh_debug_list_socat_sockets () {
  ( ls -lF -- /proc/$$/fd/* | cut -d / -sf 5- |
      sed -nre 's~^(\S+) -> (socket:\S+)$~\2 @ conn fd \1~p'
    ls -lF -- /proc/$PPID/fd/* | cut -d / -sf 5- |
      sed -nre 's~^(\S+) -> (socket:\S+)$~\2 @ server fd \1~p'
  ) 2>/dev/null | tr -d '[]' | sort -V
}


function revssh_read_http_request () {
  local VAL= AUX=
  read -rs -t 10 VAL || return 2$(echo E: 'No request was received.' >&2)
  VAL="${VAL%$'\r'}"
  case "$VAL" in
    'CONNECT '*:*' HTTP/'[01].[01] ) ;;
    * ) echo E: "Bad request line: '$VAL')" >&2; return 2;;
  esac
  VAL="${VAL#* }"
  VAL="${VAL% *}"

  AUX="$(revssh_validate_hostname_nofinaldot_colon_port "$VAL")"
  [ -z "$AUX" ] || return 2$(
    echo E: "Bad host/port for CONNECT: $AUX" >&2)

  REQ_HOST="${VAL%:*}"
  REQ_PORT="${VAL##*:}"
  echo D: "Valid request for hive $REQ_PORT group '$REQ_HOST'." >&2
  while read -rs -t 10 VAL; do
    VAL="${VAL%$'\r'}"
    [ -n "$VAL" ] || return 0
    echo D: "HTTP request header: '$VAL'" >&2
  done
  echo E: 'Incomplete HTTP request.' >&2
  return 2
}


function revssh_validate_hostname_nofinaldot_colon_port () {
  local E=
  [ "${#1}" -lt 160 ] || E='address is too long'
  # ^-- The real rules for maximum hostname length are a bit complicated
  #   but for our purposes here we can just pick a sane maximum for the
  #   entire address, including the port number.

  # The upcoming validations don't actually need to properly match RFCs, as
  # we map the address to a file path instead of using it for networking.
  # I was just curious how strict a single `case … in` block could check.
  [ -n "$E" ] || case "$1" in
    '' ) E='empty address';;
    *:*:* ) E='too many ports';;
    *: ) E='no port number';;
    :* ) E='no host name';;
    *:*[^0-9]* ) E='non-digits in port number';;
    *[^A-Za-z0-9._-]*:* ) E='unsupported characters in hostname';;
    .* ) E='hostname must not start with a dot';;
    *..* ) E='hostname contains empty label';;
    *.:* ) E='expected fewer dots at end of hostname';;
    -* | *.-* ) E='hostname labels must not start with a hyphen';;
    *-.* | *-:* ) E='hostname labels must not end with a hyphen';;
    * ) [ "${1##*:}" -le "$TCP_MAX_PORT" ] || E='port out of range';;
  esac
  [ -n "$E" ] || return 0
  echo "$E"
  return 2
}













revssh_cli_init "$@"; exit $?
