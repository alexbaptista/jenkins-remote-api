#!/bin/bash
# -----------------------------------------------------------------------------
#
# jenkinsAPI.sh - Realiza a inicialização e obtém status remotamente de um job cadastrado no Jenkins
#
# -----------------------------------------------------------------------------
#
#
#
#

# Config de valores para execução do script
# Exemplo:
# Jenkins_url="meujenkins.com.br:port"
# Job_name="ave_ridicula"
# Job_token=""
# User_api="ave"
# User_token=""

# startBuild() - Função para realizar o start remoto do job no jenkins
# Sobre:
# Inicialmente é validado o status http (200), para então retornar o número gerado na "QUEUE" do jenkins.
# O retorno será usado na função getBuildNumber(QUEUE) para obtermos o número do JOB inicializado

function startBuild() {
  response=$(curl -i -s -m 5 --netrc -X GET "http://$Jenkins_host/job/$Job_name/build?token=$Job_token" --user "$User_api:$User_token")
  http_code=$(echo "$response" | grep HTTP | awk '{print $2}')

  if [[ $http_code == '201' ]]
  then
    number_queue=$(echo "$response" | grep Location | cut -d\/ -f6)
    echo $number_queue
    exit 0
  elif [[ ! -z $http_code && $http_code != '201' ]]
  then
    echo "Error - $http_code - check job data configuration";
    exit 1
  else
    echo "Error - time-out or invalid host - '$Jenkins_host'"
    exit 1
  fi
}

function getBuildNumber() {
    number_queue=$1
    status_queue=$(curl -i -s -m 5 --netrc -X GET "http://$Jenkins_host/queue/item/$number_queue/api/xml" --user "$User_api:$User_token")
    http_code=$(echo "$status_queue" | grep HTTP | awk '{print $2}')

    if [[ $http_code == '200' ]]
    then
      echo "$status_queue"
      exit 0
    elif [[ ! -z $http_code && $http_code != '201' ]]
    then
      echo "Error - $http_code - check queue number configuration";
      exit 1
    else
      echo "Error - time-out or invalid host - '$Jenkins_host'"
      exit 1
    fi
}

function start() {
  #echo "Requesting ..."
  #result=$(startBuild)

  if startBuild
  then
    echo "success"
  else
    exit "fails"
  fi
  #echo "Getting job ID ..."
  #getBuildNumber $result
}

case $1 in
  start) start;;
esac
