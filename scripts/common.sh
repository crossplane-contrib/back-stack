#!/bin/bash

waitfor() {
  xtrace=$(set +o|grep xtrace); set +x
  local ns=${1?namespace is required}; shift
  local type=${1?type is required}; shift

  echo "Waiting for $type $*"
  # wait for resource to exist. See: https://github.com/kubernetes/kubernetes/issues/83242
  COUNT=0
  until kubectl -n "$ns" get "$type" "$@" -o=jsonpath='{.items[0].metadata.name}' >/dev/null 2>&1; do
    echo -e "\r\033[1A\033[0KWaiting for $type $* [${COUNT}s]"
    sleep 1
    ((COUNT++))
  done
  echo -e "\r\033[1A\033[0KWaiting for $type $* ...found"
  eval "$xtrace"
}

loadenv() {
  local envfile=${1?env file is required}; shift

  set -a
  source $envfile 
  set +a
}