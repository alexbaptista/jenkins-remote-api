jenkins-remote-api
========================================

## Sobre

* Exemplo de script para execução e status de um JOB via Jenkins API

### Requisitos

* bash (unix shell)
* curl
* Credencial de acesso ao jenkins (Usuário e Token/Senha) - https://www.cloudbees.com/blog/api-token-jenkins-rest-api
* Job configurado com token para execução remota - https://wiki.jenkins-ci.org/display/JENKINS/Build+Token+Root+Plugin
* Opcional: Job configurado para não permitir concorrência de execução (Opção: Do not allow concurrent builds)

### Funções

* ```startBuild()``` - Função para realizar o start remoto do job e obter o número gerado.
* ```statusBuild(<NUMERO_DO_JOB>)``` - Função para realizar a consulta do status de um job.
* ```cancelBuild(<NUMERO_DO_JOB>)``` - Função para realizar o cancelamento de um job em andamento

### Changelog

* v1.0 - Versão inicial.

### Observações

* Realizar o start do job, e obter o número do job gerado pelo request, por meio da QUEUE do Jenkins:
https://issues.jenkins-ci.org/browse/JENKINS-12827
* Realizar o start dos jobs sem delay:
https://issues.jenkins-ci.org/browse/JENKINS-356
* Para usar a função de cancelar, foi implementado o método POST atendendo os critérios do CSRF por default habilitado no Jenkins:
https://wiki.jenkins-ci.org/display/JENKINS/CSRF+Protection
https://wiki.jenkins-ci.org/display/JENKINS/Remote+access+API#RemoteaccessAPI-CSRFProtection
