# Laravel Docker Base

Este repositório fornece uma base de Docker para projetos Laravel. Ele inclui um conjunto de imagens e configurações para criar um ambiente de desenvolvimento completo para Laravel.

## Scripts

Este repositório inclui dois scripts úteis para gerenciar projetos Laravel:

* `create-project.sh`: cria um novo projeto Laravel no diretório `var/www/nome-do-projeto`.
* `remove-project.sh`: remove um projeto Laravel existente no diretório `var/www/nome-do-projeto`.

## Como usar

1. Clone este repositório para o seu diretório de trabalho.
2. Execute o comando `docker-compose up -d` para iniciar o ambiente de desenvolvimento.
3. Use o script `create-project.sh` para criar um novo projeto Laravel.
4. Use o script `remove-project.sh` para remover um projeto Laravel existente.

## Configuração

Este repositório inclui as seguintes configurações:

* `docker-compose.yml`: define as imagens e configurações para o ambiente de desenvolvimento.
* `nginx.conf`: configura o servidor Nginx para servir os projetos Laravel.
* `php.ini`: configura o PHP para os projetos Laravel.

## Diretórios

Este repositório inclui os seguintes diretórios:

* `var/www`: diretório onde os projetos Laravel serão criados.
* `scripts`: diretório que contém os scripts `create-project.sh` e `remove-project.sh`.

## Licensa

Este repositório é licenciado sob a licença MIT. Veja o arquivo `LICENSE` para mais informações.

## Contribuição

Contribuições são bem-vindas! Se você tiver alguma sugestão ou correção, por favor, abra uma issue ou envie um pull request.
