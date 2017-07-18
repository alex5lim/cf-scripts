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
json_file=$(mktemp)
echo "asg_name,running_default,staging_default,protocol,ports,destination,description" >> ${output_file}

# Capture the output of security_groups
next_url="/v2/security_groups?results-per-page=${results_per_page}"
while [[ "${next_url}" != "null" ]]; do
  cf curl ${next_url} >> ${json_file}
  next_url=$(cf curl ${next_url} | jq -r -c ".next_url")
done

# Summarize ASGs in output_file separated by semicolon
asg_rules=$(jq -r '.resources[] | .entity.name + ";" + (.entity.running_default | tostring) + ";" + (.entity.staging_default | tostring) + ";" + (.entity.rules[] | .protocol + ";" + .ports + ";"  + .destination + ";" + .description)' ${json_file})

echo "$asg_rules" >> ${output_file}
