#!/usr/bin/env bash

if [ -z "$1" ] || [ -z "$2" ]; then
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
echo "username,org_name,space_name,role" >> ${output_file}

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

# Check if the user exists
if [[ -z $guid ]]; then
  echo "User $username doesn't exist."
  rm ${json_file}
  exit
fi

# Store user summary
next_url="/v2/users/$guid/summary?results-per-page=${results_per_page}"
while [[ "${next_url}" != "null" ]]; do
  cf curl ${next_url} >> ${json_file}
  next_url=$(cf curl ${next_url} | jq -r -c ".next_url")
done

# Check if the user belong to any org
if [[ $(jq -r '.entity.organizations[]' ${json_file} | wc -l) -eq 0 ]]; then
  echo "User $username doesn't belong to any org."
  rm ${json_file}
  exit
fi

# Get user's OrgManager role(s) if any
if [[ $(jq -r '.entity.managed_organizations[]' ${json_file} | wc -l) -ne 0 ]]; then
  org_names=$(jq -r '.entity.managed_organizations[] | .entity.name' ${json_file})
  for org_name in $org_names; do
    echo "$username,$org_name,,OrgManager" >> ${output_file}
  done
fi

# Get user's BillingManager role(s) if any
if [[ $(jq -r '.entity.billing_managed_organizations[]' ${json_file} | wc -l) -ne 0 ]]; then
  org_names=$(jq -r '.entity.billing_managed_organizations[] | .entity.name' ${json_file})
  for org_name in $org_names; do
    echo "$username,$org_name,,BillingManager" >> ${output_file}
  done
fi

# Get user's OrgAuditor role(s) if any
if [[ $(jq -r '.entity.audited_organizations[]' ${json_file} | wc -l) -ne 0 ]]; then
  org_names=$(jq -r '.entity.audited_organizations[] | .entity.name' ${json_file})
  for org_name in $org_names; do
    echo "$username,$org_name,,OrgAuditor" >> ${output_file}
  done
fi

# Get user's SpaceManager role(s) if any
if [[ $(jq -r '.entity.managed_spaces[]' ${json_file} | wc -l) -ne 0 ]]; then
  space_guids=$(jq -r '.entity.managed_spaces[] | .metadata.guid' ${json_file})
  for space_guid in $space_guids; do
    org_name=$(jq -r --arg value $space_guid '.entity.organizations[] | select(.entity.spaces[].metadata.guid == $value) | .entity.name' ${json_file})
    space_name=$(jq -r --arg value $space_guid '.entity.managed_spaces[] | select(.metadata.guid == $value) | .entity.name' ${json_file})
    echo "$username,$org_name,$space_name,SpaceManager" >> ${output_file}
  done
fi

# Get user's SpaceDeveloper role(s) if any
if [[ $(jq -r '.entity.spaces[]' ${json_file} | wc -l) -ne 0 ]]; then
  space_guids=$(jq -r '.entity.spaces[] | .metadata.guid' ${json_file})
  for space_guid in $space_guids; do
    org_name=$(jq -r --arg value $space_guid '.entity.organizations[] | select(.entity.spaces[].metadata.guid == $value) | .entity.name' ${json_file})
    space_name=$(jq -r --arg value $space_guid '.entity.spaces[] | select(.metadata.guid == $value) | .entity.name' ${json_file})
    echo "$username,$org_name,$space_name,SpaceDeveloper" >> ${output_file}
  done
fi

# Get user's SpaceAuditor role(s) if any
if [[ $(jq -r '.entity.audited_spaces[]' ${json_file} | wc -l) -ne 0 ]]; then
  space_guids=$(jq -r '.entity.audited_spaces[] | .metadata.guid' ${json_file})
  for space_guid in $space_guids; do
    org_name=$(jq -r --arg value $space_guid '.entity.organizations[] | select(.entity.spaces[].metadata.guid == $value) | .entity.name' ${json_file})
    space_name=$(jq -r --arg value $space_guid '.entity.audited_spaces[] | select(.metadata.guid == $value) | .entity.name' ${json_file})
    echo "$username,$org_name,$space_name,SpaceAuditor" >> ${output_file}
  done
fi

rm ${json_file}
exit
