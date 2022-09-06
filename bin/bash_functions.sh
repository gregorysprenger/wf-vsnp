#!/usr/bin/env bash

send_mail=true

msg() {
  # A function, designed for logging, that prints current date and timestamp
  #  as a prefix to the rest of the message. Default sends to stdout but can
  #  redirected during execution.
  echo "[$(date '+%Y-%b-%d %a %H:%M:%S')] $@"
}

verify_file_minimum_size()
{
  # $1=filename
  # $2=file description
  # $3=size in Bytes (requires c, k, M, or G prefix)
  if [ -f  "${1}" ]; then
    if [ -s  "${1}" ]; then
      if [[ $(find -L "${1}" -type f -size +"${3}") ]]; then
        return
      else
        size=$(echo ${3} | sed 's/c//g')
        msg "ERROR: ${2} file ${1} present but too small (< ${3}B)" >&2
        false
      fi
    else
      msg "ERROR: ${2} file ${1} present but empty" >&2
      false
    fi
  else
    msg "ERROR: ${2} file ${1} absent" >&2
    false
  fi
}

