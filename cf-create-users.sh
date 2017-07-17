#!/usr/bin/env bash

if [ -z "$1" ] || [ -z "$2" ]; then
  echo " "
  echo "usage: $0 input_file output_file"
  echo " "
  echo "example: $0 user_list.csv output.csv"
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
output_file="$2"

while IFS="," read -r username password; do
  # comment out following two lines if you're providing password in the input file
  password=$(openssl rand -hex 12)
  echo "$username,$password" >> $output_file
  cf create-user $username $password
done < <(tail -n +"$start_line" "$input_file")
