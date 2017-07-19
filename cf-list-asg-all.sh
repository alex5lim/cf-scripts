#!/usr/bin/env bash

if [ -z "$1" ]; then
  echo " "
  echo "usage: $0 output_file"
  echo " "
  echo "example: $0 asg.json"
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

output_file="$1"
results_per_page=100
json_file1=$(mktemp)
json_file2=$(mktemp)

# Capture the output of security_groups
next_url="/v2/security_groups?results-per-page=${results_per_page}"
while [[ "${next_url}" != "null" ]]; do
  cf curl ${next_url} >> ${json_file1}
  next_url=$(cf curl ${next_url} | jq -r -c ".next_url")
done

# Summarize ASGs in output_file separated by semicolon
jq '.resources[] | {asg_name: .entity.name, spaces: .entity.spaces_url, rules: .entity.rules} | {asg_name: .asg_name, spaces: .spaces, rules: [.rules[] | .protocol + " " + .ports + " to " + .destination]} | {asg_name: .asg_name, spaces: .spaces, rules: .rules|join("; ")} ' ${json_file1} \
>> ${json_file2}

for url in $(jq -r '.spaces' ${json_file2}); do
  org_space_set=
  for space_guid in $(cf curl $url | jq -r '.resources[] | .metadata.guid'); do
    space_name=$(cf curl $url | jq -r --arg value $space_guid '.resources[] | select(.metadata.guid == $value) | .entity.name')
    org_url=$(cf curl $url | jq -r --arg value $space_guid '.resources[] | select(.metadata.guid == $value) | .entity.organization_url')
    org_name=$(cf curl $org_url | jq -r '.entity.name')
    org_space_set+="$org_name org"
    org_space_set+="/"
    org_space_set+="$space_name space"
    org_space_set+="; "
  done
  jq -r --arg url "$url" --arg replacement "$org_space_set" 'select(.spaces == $url) | .spaces |= $replacement' ${json_file2} >> ${output_file}
done
