#!/bin/bash

# Config de valores para execução do script
#Jenkins_url=
#Job_name=
#Job_token=
#User_api=
#User_token=


function startBuild()
{
  response=$(curl -i -s -m 10 --netrc -X GET "http://$Jenkins_host/job/$Job_name/build?token=$Job_token" --user "$User_api:$User_token")
  http_code=$(echo "$response" | grep HTTP | awk '{print $2}')

  if [[ $http_code == '201' ]]
  then
    number_queue=$(echo "$response" | grep Location | cut -d\/ -f6)
    status_queue=$(curl -s -X GET "http://$Jenkins_host/queue/item/$number_queue/api/xml" --user "$User_api:$User_token")

    echo $status_queue

  elif [[ ! -z $http_code && $http_code != '201' ]]
  then
    echo "Error - $http_code - check job data configuration";
    exit 1
  else
    echo "Error curl - time-out or invalid host - '$Jenkins_host'"
    exit 1
  fi
}

case $1 in
  start) startBuild;;
esac
