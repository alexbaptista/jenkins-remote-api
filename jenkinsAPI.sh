#!/bin/bash
# -----------------------------------------------------------------------------
#
# jenkinsAPI.sh - Realiza a inicialização e obtém status remotamente de um job cadastrado no Jenkins
#
# -----------------------------------------------------------------------------
# * Requisitos:
#
# - bash (unix shell)
# - curl
# - Credencial de acesso ao jenkins (Usuário e Token/Senha) - https://www.cloudbees.com/blog/api-token-jenkins-rest-api
# - Job configurado com token para execução remota - https://wiki.jenkins-ci.org/display/JENKINS/Build+Token+Root+Plugin
# - Opcional: Job configurado para não permitir concorrência de execução (Opção: Do not allow concurrent builds)
#
# * Funções:
#
# - startBuild(<PARAMETRO> ou nulo) - Função para realizar o start remoto do job (parametrizado ou não) e obter o status.
# - statusBuild(<NUMERO_DO_JOB>) - Função para realizar a consulta do status de um job.
# - cancelBuild(<NUMERO_DO_JOB>) - Função para realizar o cancelamento de um job em andamento
#
# * Changelog:
#
# - v1.0 - Versão inicial.
# - v1.1 - Adicionado contexto de ajuda help()
# - v1.2 - Suporte á JOB parametrizado (somente 1 variável)
# - v1.3 - Adicionado método de log das requisições curl
# - v1.4 - Adicionado método de consulta após o inicio do job, a função start apenas concluiu com um status de job
#
# * Observações:
#
# - Realizar o start do job, e obter o número do job gerado pelo request, por meio da QUEUE do Jenkins
#   https://issues.jenkins-ci.org/browse/JENKINS-12827
# - Realizar o start dos jobs sem delay
#   https://issues.jenkins-ci.org/browse/JENKINS-356
# - Para usar a função de cancelar, foi implementado o método POST atendendo os critérios do CSRF por default habilitado no Jenkins
#   https://wiki.jenkins-ci.org/display/JENKINS/CSRF+Protection
#   https://wiki.jenkins-ci.org/display/JENKINS/Remote+access+API#RemoteaccessAPI-CSRFProtection

# * Config de valores para execução do script:
#
# - Jenkins_url="meujenkins.com.br:port"
# - Job_name="ave_ridicula"
# - Job_token="fr@ng0"
# - User_api="ave"
# - User_token="@ver1d1cul@"

Jenkins_host="cpro37908.publiccloud.com.br"
Job_name="Java_Pipe"
Job_token="636f0a114d4258f230e0ef76dd3eb727"
User_api="devops"
User_token="Q!W@E#zaxscd"

# Opcional - Defina o nome da variável do JOB caso seja parametrizado
Job_parameter_name="TAG"

# startBuild(<PARAMETRO> ou nulo) - Função para realizar o start remoto do job (parametrizado ou não) e obter o número gerado.
# Obs: Atende para jobs parametrizados, somente 1 valor como variável (chave=valor)
# Sobre:
# Após o request de start, é validado o status http (201), para então obter o número gerado na "QUEUE" do jenkins.
# Com base no número da "QUEUE", é realizado um novo request HTTP (200) para obter o "NUMBER" do job gerado.
# Após isso é realizado a consulta para obter o status do JOB

function startBuild() {
  parameter=$1

  if [[ ! -z $parameter ]]
  then
    response=$(curl -i -s -m 5 --netrc -X GET "http://$Jenkins_host/job/$Job_name/buildWithParameters?token=$Job_token&$Job_parameter_name=$parameter&delay=0" --user "$User_api:$User_token")
  else
    response=$(curl -i -s -m 5 --netrc -X GET "http://$Jenkins_host/job/$Job_name/build?token=$Job_token&delay=0" --user "$User_api:$User_token")
  fi

  saveLog 'START' "$response"

  http_code=$(echo "$response" | grep HTTP | awk '{print $2}')

  if [[ $http_code == '201' ]]
  then
    number_queue=$(echo "$response" | grep Location | cut -d\/ -f6)
    status_queue=$(sleep 3;curl -i -s -m 5 --netrc -X GET "http://$Jenkins_host/queue/item/$number_queue/api/json?pretty=true" --user "$User_api:$User_token")

    saveLog 'START-QUEUE' "$status_queue"

    http_code=$(echo "$status_queue" | grep HTTP | awk '{print $2}')

    if [[ $http_code == '200' ]]
    then
      if [[ $status_queue == *"\"blocked\" : true"* ]]
      then
        echo "$status_queue" |  grep '"why"' | cut -d\" -f4
        exit 1
      else
        number_created=$(echo "$status_queue" |  grep '"number"' | awk '{print $3}' | sed 's/,//g')

        while true;
        do
          status_number=$(sleep 5;statusBuild $number_created)
          if [[ "$status_number" != 'BUILDING' ]]
          then
              echo "$status_number"
              exit 0
          fi
        done

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

# statusBuild(<NUMERO_DO_JOB>) - Função para realizar a consulta do status de um job.
# Sobre:
# Recebe como parâmetro o número do JOB, inicialmente valida se é um número válido,
# posteriormente segue com o request, valida o http code (200),
# depois valida se o job está em execução ou se já terminou, retornando um dos status:
# SUCCESS, ABORTED, FAILURE, UNSTABLE ou BUILDING

function statusBuild() {
  integer='^[0-9]+$'
  number_job=$1

  if [[ $number_job =~ $integer ]]
  then
    response=$(curl -i -s -m 5 --netrc -X GET "http://$Jenkins_host/job/$Job_name/$number_job/api/json?pretty=true" --user "$User_api:$User_token")
    http_code=$(echo "$response" | grep HTTP | awk '{print $2}')

    saveLog 'STATUS' "$response"

    if [[ $http_code == '200' ]]
    then
      if [[ $response == *"\"building\" : true"* ]]
      then
        echo "BUILDING"
      else
        echo "$response" | grep '"result"' | cut -d\" -f4
      fi

    elif [[ ! -z $http_code && $http_code != '200' ]]
    then
      echo "Error - $http_code - check job number configuration";
      exit 1
    else
      echo "Error - time-out or invalid host - '$Jenkins_host'"
      exit 1
    fi
  else
    echo "Error - Not valid job number value"
    exit 1
  fi
}

# cancelBuild(<NUMERO_DO_JOB>) - Função para realizar o cancelamento de um job em andamento
# Sobre:
# Recebe como parâmetro o número do JOB, inicialmente valida se é um número válido,
# posteriormente segue com o request, valida o http code (302).

function cancelBuild() {
  integer='^[0-9]+$'
  number_job=$1

  if [[ $number_job =~ $integer ]]
  then
    jenkins_crumb=$(curl -s -X GET "http://$Jenkins_host/crumbIssuer/api/xml?xpath=concat(//crumbRequestField,%22:%22,//crumb)" --user "$User_api:$User_token")
    response=$(curl -i -s -m 5 --netrc -H "$jenkins_crumb" -X POST "http://$Jenkins_host/job/$Job_name/$number_job/stop?token=$Job_token&delay=0" --user "$User_api:$User_token")

    saveLog 'CANCEL' "$response"

    http_code=$(echo "$response" | grep HTTP | awk '{print $2}')

    if [[ $http_code == '302' ]]
    then
      echo "STOPPED"
    elif [[ ! -z $http_code && $http_code != '200' ]]
    then
      echo "Error - $http_code - check job number configuration";
      exit 1
    else
      echo "Error - time-out or invalid host - '$Jenkins_host'"
      exit 1
    fi
  else
    echo "Error - Not valid job number value"
    exit 1
  fi
}

function saveLog() {
  type=$1
  log=$2
  yymmdd=$(date +%Y-%m-%d)
  mkdir -p logs
  echo "[$type] - $(date) ==========================================" >> logs/api_$yymmdd.log
  echo $log >> logs/api_$yymmdd.log
  echo "" >> logs/api_$yymmdd.log
}

function help() {
  cat<<-EOM

  NOME
      jenkinsAPI.sh

  RESUMO
      Realiza a inicialização e obtém status remotamente de um job cadastrado no Jenkins

  DESCRIÇÃO
      jenkinsAPI.sh start <PARAMETRO> ou nulo - Realiza o start remoto do job (parametrizado ou não) e retorna o status.
      jenkinsAPI.sh status <NUMERO_DO_JOB> - Consulta do status de um job.
      jenkinsAPI.sh cancel <NUMERO_DO_JOB> - Cancelamento de um job em andamento

EOM
}

function version() {
  echo "v1.4"
}

case $1 in
  start) startBuild $2;;
  status) statusBuild $2;;
  cancel) cancelBuild $2;;
  --version) version;;
  *) help;;
esac
