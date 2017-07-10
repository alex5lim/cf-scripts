#!/usr/bin/env bash

if [ -z "$1" ]; then
  echo " "
  echo "usage: $0 input_file"
  echo " "
  echo "example: $0 user_roles.csv"
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

while ifs="," read -r username org_name space_name role task; do
  echo "user:$username org:$org_name space:$space_name role:$role task:$task"
  if [[ $role == 'OrgManager' ]] || [[ $role == 'BillingManager' ]] || [[ $role == 'OrgAuditor' ]]; then
    if [[ $task == 'set' ]]; then
      cf set-org-role $username $org_name $role
    elif [[ $task == 'unset' ]]; then
      cf unset-org-role $username $org_name $role
    else
      echo "Task $task for $username in $org_name org is unknown."
    fi
  elif [[ $role == 'SpaceManager' ]] || [[ $role == 'SpaceDeveloper' ]] || [[ $role == 'SpaceAuditor' ]]; then
    if [[ $task == 'set' ]]; then
      cf set-space-role $username $org_name $space_name $role
    elif [[ $task == 'unset' ]]; then
      cf unset-space-role $username $org_name $space_name $role
    else
      echo "Task $task for $username in $org_name org/$space_name space is unknown."
    fi
  else
    echo "$role role is not a valid role."
  fi
done < <(tail -n +"$start_line" "$input_file")
