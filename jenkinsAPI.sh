#!/bin/bash
# -----------------------------------------------------------------------------
#
# jenkinsAPI.sh - Realiza a inicialização e obtém status remotamente de um job cadastrado no Jenkins
#
# -----------------------------------------------------------------------------
# * Requisitos:
# - Credencial de acesso ao jenkins (Usuário e Token/Senha)
# - Job configurado com token para execução remota
# - Opcional: Job configurado para não permitir concorrência de execução
#
# * Funções:
# - startBuild() - Realiza o start do job e retorna o número do build gerado
#
# * Config de valores para execução do script:
#
# Exemplo:
# Jenkins_url="meujenkins.com.br:port"
# Job_name="ave_ridicula"
# Job_token=""
# User_api="ave"
# User_token=""

Jenkins_host=""
Job_name=""
Job_token=""
User_api=""
User_token=""

# startBuild() - Função para realizar o start remoto do job e obter o número gerado
# Sobre:
# Após o request de start, é validado o status http (201), para então obter o número gerado na "QUEUE" do jenkins.
# Com base no número da "QUEUE", é realizado um novo request HTTP (200) para obter o "NUMBER" do job gerado.
# OBS: Para este segundo request, temos de aguardar +5 segundos para que o Jenkins possa criar o NUMBER para o job, ou retornar se há outro job em execução

function startBuild() {
  echo "Requesting ..."
  response=$(curl -i -s -m 5 --netrc -X GET "http://$Jenkins_host/job/$Job_name/build?token=$Job_token" --user "$User_api:$User_token")
  http_code=$(echo "$response" | grep HTTP | awk '{print $2}')

  if [[ $http_code == '201' ]]
  then
    echo "Getting job status ..."
    number_queue=$(echo "$response" | grep Location | cut -d\/ -f6)
    status_queue=$(sleep 8;curl -i -s -m 5 --netrc -X GET "http://$Jenkins_host/queue/item/$number_queue/api/json?pretty=true" --user "$User_api:$User_token")
    http_code=$(echo "$status_queue" | grep HTTP | awk '{print $2}')

    if [[ $http_code == '200' ]]
    then
        if [[ $status_queue == *"\"blocked\" : true"* ]]
        then
          echo "Error starting ..."
          echo "$status_queue" |  grep '"why"' | cut -d\" -f4
          exit 1
        else
          echo "Created number job:"
          echo "$status_queue" |  grep '"number"' | awk '{print $3}' | sed 's/,//g'
        fi

    elif [[ ! -z $http_code && $http_code != '200' ]]
    then
      echo "Error - $http_code - check queue number configuration";
      exit 1
    else
      echo "Error - time-out or invalid host - '$Jenkins_host'"
      exit 1
    fi

  elif [[ ! -z $http_code && $http_code != '201' ]]
  then
    echo "Error - $http_code - check job data configuration";
    exit 1
  else
    echo "Error - time-out or invalid host - '$Jenkins_host'"
    exit 1
  fi
}

case $1 in
  start) startBuild;;
esac
