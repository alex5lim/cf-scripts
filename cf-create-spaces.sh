#!/usr/bin/env bash

if [ -z "$1" ]; then
  echo " "
  echo "usage: $0 input_file"
  echo " "
  echo "example: $0 space_list.csv"
  echo " "
  exit 1
fi

if [[ "$(which cf)x" == "x" ]]; then
  echo "please install cf cli - https://github.com/cloudfoundry/cli"
  exit 1
fi

if [[ "$(which jq)x" == "x" ]]; then
  echo "please install jq - http://stedolan.github.io/jq/download/"
  exit 1
fi

export CF_COLOR=false
start_line=2
input_file="$1"

while IFS="," read -r space_name org_name; do
  cf create-space $space_name -o $org_name
done < <(tail -n +"$start_line" "$input_file")
