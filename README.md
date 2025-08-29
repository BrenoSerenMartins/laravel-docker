# Laravel Docker Base

Este repositório fornece uma base de Docker para projetos Laravel. Ele inclui um conjunto de imagens e configurações para criar um ambiente de desenvolvimento completo e portátil para Laravel.

## Como usar

### 1. Iniciar o Ambiente
Para iniciar todos os serviços (Nginx, PHP, MySQL, etc.), execute:
```bash
docker-compose up -d
```

### 2. Criar um Novo Projeto
Use o script interativo para criar um novo projeto Laravel. O nome do projeto deve conter apenas letras minúsculas, números e hífens.
```bash
./scripts/create-new-project.sh <nome-do-projeto>
```
O script irá configurar tudo automaticamente, incluindo o banco de dados e o acesso local via `http://<nome-do-projeto>.local`.

### 3. Remover um Projeto
Para remover um projeto, use o script de remoção. Ele pedirá confirmação antes de apagar os arquivos, banco de dados e configuração.
```bash
./scripts/remove-project.sh <nome-do-projeto>
```

## Interagindo com os Projetos

### Executando comandos Artisan
Para executar comandos `artisan` em um projeto específico, use o `docker-compose run`:
```bash
docker-compose run --rm --workdir /var/www/<nome-do-projeto> php-fpm php artisan make:model NomeDoModel
```

### Executando o Composer
Para executar o `composer` em um projeto, o processo é similar:
```bash
docker-compose run --rm --workdir /var/www/<nome-do-projeto> php-fpm composer update
```

### Acesso ao Banco de Dados
Você pode se conectar ao banco de dados MySQL a partir de um cliente de banco de dados local (DBeaver, DataGrip, etc.) usando as seguintes credenciais:

- **Host**: `127.0.0.1`
- **Porta**: `3306`
- **Usuário**: `laravel`
- **Senha**: `laravel`
- **Database**: O nome do banco de dados é `laravel_<nome-do-projeto>` (com hífens do nome do projeto substituídos por underscores).

## Licença

Este repositório é licenciado sob a licença MIT. Veja o arquivo `LICENSE` para mais informações.

## Contribuição

Contribuições são bem-vindas! Se você tiver alguma sugestão ou correção, por favor, abra uma issue ou envie um pull request.