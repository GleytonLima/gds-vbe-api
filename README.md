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

| Variável                  | Descrição                                      | Exemplo                                |
| ------------------------- | ---------------------------------------------- | -------------------------------------- |
| INTEGRACAO_DB_HOST        | Host do banco de dados da integração           | integracaodb                           |
| INTEGRACAO_DB_PORT        | Porta do banco de dados da integração          | 5432                                   |
| INTEGRACAO_DB_USERNAME    | Usuário do banco de dados da integração        | example                                |
| INTEGRACAO_DB_PASSWORD    | Senha do banco de dados da integração          | admin                                  |
| INTEGRACAO_DB_SCHEMA_NAME | Nome do schema do banco de dados da integração | integracao                             |
| ODOO_URL                  | URL do Odoo                                    | https://example                        |
| ODOO_DB                   | Nome do banco de dados do Odoo                 | test                                   |
| ODOO_USER                 | Usuário do Odoo                                | example                                |
| ODOO_APIKEY               | Chave de API do Odoo                           | supersecretkey                         |
| LOGZIO_TOKEN              | Token de autenticação do Logz.io               | tokenenviologs                         |
| JVM_OPTIONS               | Opções de inicialização da JVM                 | -Xmx512m -Dspring.profiles.active=prod |

O arquivo db/.env deve conter as seguintes variáveis:

| Variável            | Descrição                 | Exemplo |
| ------------------- | ------------------------- | ------- |
| POSTGRES_PASSWORD   | Senha do usuário postgres | admin   |
| POSTGRES_SVUSER     | Usuário do banco de dados | admin   |
| POSTGRES_SVPASSWORD | Senha do banco de dados   | admin   |

3. Execute o comando `docker-compose up -d` para iniciar o deploy.

## Instância de Cabo Verde (ePHEM API v2)

Cada integrador atende um ePHEM. Para Cabo Verde há uma segunda instância, `integracaoapp-cv`,
em [docker-compose.cv.yml](docker-compose.cv.yml). Ela usa a mesma imagem e muda só o `env_file`
(`app/.env.cv`) e o database (`integracao_cv`, no mesmo Postgres).

O serviço fica em arquivo separado para que servidores sem `app/.env.cv` continuem funcionando.
O deploy do integrador (GitHub Actions) reinicia `integracaoapp-cv` sempre que ele aparece em
`docker-compose config --services`.

Para ativar num servidor (uma vez), aponte o DNS e rode o script, que cobre os passos 2 a 5 abaixo.
Ele pede as keys sem mostrá-las na tela e pode ser rodado de novo:

```sh
git pull --ff-only
bash scripts/ativar-instancia-cv.sh homolog   # ou: prod
```

Os passos que o script executa:

1. Aponte o DNS de `cv.vbeapi.online` para o servidor. Em produção use `cv.prod.vbeapi.online`.
2. Crie o database. O `db/initdb.sh` só roda quando o volume é novo:
   ```sh
   docker-compose exec integracaodb psql -U postgres -c 'CREATE DATABASE "integracao_cv";'
   ```
3. Crie `app/.env.cv` a partir de [app/.env.cv.exemplo](app/.env.cv.exemplo). O
   `EPHEM_V2_EXTERNAL_ID_PREFIX` precisa ser diferente entre instâncias que publicam no mesmo ePHEM
   (homologação `GDS-HOMOL-`, produção `GDS-`).
4. Crie um `.env` na raiz deste repositório. O `docker-compose` lê esse arquivo sozinho:
   ```sh
   COMPOSE_FILE=docker-compose.yml:docker-compose.cv.yml
   # só em produção:
   INTEGRACAO_CV_HOST=cv.prod.vbeapi.online
   ```
5. Suba e acompanhe:
   ```sh
   docker-compose pull integracaoapp-cv
   docker-compose up -d integracaoapp-cv
   docker-compose logs -f integracaoapp-cv   # esperar "Started Gds2ephemApplication"
   ```

As variáveis de `app/.env.cv`, além das da tabela acima, são estas:

| Variável                    | Descrição                                                   | Exemplo                     |
| --------------------------- | ----------------------------------------------------------- | --------------------------- |
| ODOO_LANG                   | Idioma do context no XML-RPC (precisa estar ativo no Odoo)  | pt_PT                       |
| EPHEM_V2_ENABLED            | Cria os signals pela API REST v2                            | true                        |
| EPHEM_V2_BASE_URL           | URL base da API v2                                          | https://cv.pheoc.com/api/v2 |
| EPHEM_V2_API_KEY            | API key de um usuário com a role `ephem_signals_api_writer` |                             |
| EPHEM_V2_EXTERNAL_ID_PREFIX | Prefixo do external_id (único por instância)                | GDS-                        |
| NOTIFYEVENTS_CHANNEL_URL    | Canal de alertas (use um próprio da instância)              |                             |

Para voltar só a instância CV a uma versão anterior (a imagem também é publicada com o SHA do commit):

```sh
INTEGRACAO_CV_IMAGE_TAG=<sha> docker-compose up -d integracaoapp-cv
```

O próximo deploy volta a usar `latest`.

Depois de subir a instância, ainda falta configurar o integrador (`configuracao_sistema` e template)
e o contexto no GDS. Esses passos estão em
[docs/deploy-instancia-cv.md](https://github.com/GleytonLima/gds-ephem-integracao/blob/main/docs/deploy-instancia-cv.md)
no repositório do integrador.

## Como parar

Para parar o deploy, execute o comando `docker-compose down`.

## Sobre o projeto

Detalhes sobre o projeto podem ser encontrados no repositório do app (https://github.com/GleytonLima/gds-ephem-integracao)

O deploy é feito utilizando o Docker Compose. O arquivo `docker-compose.yml` possui a configuração dos serviços necessários para o deploy.

Veja que o arquivo docker-compose.yml possui uma seção `networks` com a configuração de uma rede. Essa rede é utilizada para que os serviços possam se comunicar entre si. O nome da rede utilizado é proxy. Caso você já possua uma rede com esse nome, altere o nome da rede no arquivo `docker-compose.yml` para um nome que não esteja sendo utilizado.
