#!/usr/bin/env bash

if [ -z "$1" -o -z "$2" ]; then
  echo " "
  echo "usage: $0 username output_file"
  echo " "
  echo "example: $0 alexanderlimha alexanderlimha.csv"
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

results_per_page=1
username="$1"
output_file="$2"
json_file=$(mktemp)

# Find user's guid
next_url="/v2/users?results-per-page=${results_per_page}"
while [[ "${next_url}" != "null" ]]; do
  curl_result=$(cf curl ${next_url} | jq -r --arg key username --arg value $username \
  '.resources[] | select(.entity?[$key]==$value) | .metadata.guid')
  if [[ -n "$curl_result" ]]; then
    guid="$curl_result"
  fi
  next_url=$(cf curl ${next_url} | jq -r -c ".next_url")
done

# Store user summary
next_url="/v2/users/$guid/summary?results-per-page=${results_per_page}"
while [[ "${next_url}" != "null" ]]; do
  cf curl ${next_url} >> ${json_file}
  next_url=$(cf curl ${next_url} | jq -r -c ".next_url")
done

# Check if the user belong to any org
if [[ $(jq -r '.entity.organizations[]' ${json_file} | wc -l) -eq 0 ]]; then
  echo "User doesn't belong to any org."
  exit
fi

exit

# Get user spaces
echo "username,org_name,space_name,role" >> ${output_file}
space_guids=$(cat ${json_file} | jq -r '.entity.spaces[] | .metadata.guid')
for space_guid in $space_guids; do
  org_name=$(cat ${json_file} | jq -r --arg value $space_guid '.entity.organizations[] | select(.entity.spaces[].metadata.guid == $value) | .entity.name')
  space_name=$(cat ${json_file} | jq -r --arg value $space_guid '.entity.spaces[] | select(.metadata.guid == $value) | .entity.name')
  echo "$username,$org_name,$space_name,SpaceDeveloper" >> ${output_file}
done

rm ${json_file}
