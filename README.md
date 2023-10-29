# GDS VBE API

Exemplo de configuração para subir o ambiente de desenvolvimento do GDS VBE API.

## Pré-requisitos

- [Docker](https://docs.docker.com/install/)
- [Docker Compose](https://docs.docker.com/compose/install/)

## Como executar

1. Clone o repositório
2. Crie um arquivo `.env` na pasta app com as variáveis de ambiente necessárias para o app de ETL. Um exemplo pode ser encontrado no arquivo `.env.example`.
3. Crie um arquivo `.env` na pasta db com as variáveis de ambiente necessárias para o banco de dados. Um exemplo pode ser encontrado no arquivo `.env.example`.
4. Execute o comando `docker-compose up -d` para iniciar o deploy do banco de dados e aplicação juntas.
5. Execute o comando `docker-compose -f docker-compose-app-only.yml up -d` para subir apenas a aplicação. Neste caso, verifique as configurações de rede do arquivo para que seja possível a aplicação se conectar ao banco de dados que já exista.

O arquivo app/.env deve conter as seguintes variáveis:

| Variável                  | Descrição                                      | Exemplo         |
| ------------------------- | ---------------------------------------------- | --------------- |
| INTEGRACAO_DB_HOST        | Host do banco de dados da integração           | integracaodb    |
| INTEGRACAO_DB_PORT        | Porta do banco de dados da integração          | 5432            |
| INTEGRACAO_DB_USERNAME    | Usuário do banco de dados da integração        | example         |
| INTEGRACAO_DB_PASSWORD    | Senha do banco de dados da integração          | admin           |
| INTEGRACAO_DB_SCHEMA_NAME | Nome do schema do banco de dados da integração | integracao      |
| ODOO_URL                  | URL do Odoo                                    | https://example |
| ODOO_DB                   | Nome do banco de dados do Odoo                 | test            |
| ODOO_USER                 | Usuário do Odoo                                | example         |
| ODOO_APIKEY               | Chave de API do Odoo                           | supersecretkey  |
| LOGZIO_TOKEN              | Token de autenticação do Logz.io               | tokenenviologs  |

O arquivo db/.env deve conter as seguintes variáveis:

| Variável            | Descrição                 | Exemplo |
| ------------------- | ------------------------- | ------- |
| POSTGRES_PASSWORD   | Senha do usuário postgres | admin   |
| POSTGRES_SVUSER     | Usuário do banco de dados | admin   |
| POSTGRES_SVPASSWORD | Senha do banco de dados   | admin   |

3. Execute o comando `docker-compose up -d` para iniciar o deploy.

## Como parar

Para parar o deploy, execute o comando `docker-compose down`.

## Sobre o projeto

Detalhes sobre o projeto podem ser encontrados no repositório do app (https://github.com/GleytonLima/gds-ephem-integracao)

O deploy é feito utilizando o Docker Compose. O arquivo `docker-compose.yml` possui a configuração dos serviços necessários para o deploy.

Veja que o arquivo docker-compose.yml possui uma seção `networks` com a configuração de uma rede. Essa rede é utilizada para que os serviços possam se comunicar entre si. O nome da rede utilizado é proxy. Caso você já possua uma rede com esse nome, altere o nome da rede no arquivo `docker-compose.yml` para um nome que não esteja sendo utilizado.
