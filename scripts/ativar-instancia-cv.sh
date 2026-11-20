#!/bin/bash
# Ativa a instancia do integrador para o ePHEM de Cabo Verde neste servidor.
# Rode na pasta do repositorio (gds-vbe-api/):  bash scripts/ativar-instancia-cv.sh homolog|prod
#
# - cria o database integracao_cv (se nao existir)
# - cria app/.env.cv a partir de app/.env.cv.exemplo, reaproveitando o acesso ao banco do app/.env
#   e pedindo as keys sem mostra-las na tela
# - liga o docker-compose.cv.yml pelo COMPOSE_FILE do .env da raiz
# - sobe integracaoapp-cv e espera a aplicacao iniciar
# Pode ser rodado de novo: o que ja existe e mantido.
set -euo pipefail

AMBIENTE="${1:-}"
case "$AMBIENTE" in
  homolog) PREFIXO="GDS-HOMOL-"; HOST_CV="vbeapi.online"; EPHEM_URL_PADRAO="https://cv.pheoc.com"; EPHEM_DB_PADRAO="cv" ;;
  prod)    PREFIXO="GDS-";       HOST_CV="prod.vbeapi.online"; EPHEM_URL_PADRAO=""; EPHEM_DB_PADRAO="" ;;
  *) echo "uso: bash scripts/ativar-instancia-cv.sh homolog|prod" >&2; exit 1 ;;
esac

cd "$(dirname "$0")/.."
[ -f docker-compose.cv.yml ] || { echo "docker-compose.cv.yml nao encontrado: rode git pull antes" >&2; exit 1; }
[ -f app/.env ] || { echo "app/.env nao encontrado: este script reaproveita o acesso ao banco dele" >&2; exit 1; }

valor() { grep -E "^$1=" "$2" | head -1 | cut -d= -f2- | tr -d '\r'; }
perguntar() {  # perguntar VAR "texto" [padrao]
  local resposta
  read -r -p "$2${3:+ [$3]}: " resposta
  printf -v "$1" '%s' "${resposta:-${3:-}}"
}
perguntar_segredo() {
  local resposta
  read -r -s -p "$2: " resposta; echo
  [ -n "$resposta" ] || { echo "$2 e obrigatorio" >&2; exit 1; }
  printf -v "$1" '%s' "$resposta"
}

echo "== 0/4 nginx-proxy (precisa de VIRTUAL_PATH, versao 1.1+)"
PROXY_IMAGEM=$(docker ps --format '{{.Image}}' | grep -iE 'nginx-proxy' | head -1 || true)
echo "imagem do proxy: ${PROXY_IMAGEM:-nao encontrada}"
case "$PROXY_IMAGEM" in
  jwilder/*|*:0.*|*:1.0*) echo "este nginx-proxy provavelmente nao suporta VIRTUAL_PATH; atualize-o ou use um subdominio" >&2; exit 1 ;;
esac

echo "== 1/4 database integracao_cv"
if docker-compose exec -T integracaodb psql -U postgres -tAc "select 1 from pg_database where datname='integracao_cv'" | grep -q 1; then
  echo "ja existe"
else
  docker-compose exec -T integracaodb psql -U postgres -c 'CREATE DATABASE "integracao_cv";'
fi

echo "== 2/4 app/.env.cv"
if [ -f app/.env.cv ]; then
  echo "ja existe; mantido (apague-o para gerar de novo)"
else
  perguntar EPHEM_URL "URL do ePHEM de Cabo Verde" "$EPHEM_URL_PADRAO"
  perguntar EPHEM_DB "Database do Odoo" "$EPHEM_DB_PADRAO"
  perguntar ODOO_USER "Login do usuario da integracao no ePHEM (XML-RPC)"
  perguntar_segredo ODOO_APIKEY "API key desse usuario para o XML-RPC"
  perguntar_segredo EPHEM_V2_API_KEY "API key da API v2 (role ephem_signals_api_writer)"
  perguntar NOTIFY "URL do canal Notify.events (enter = mesmo do app/.env)" "$(valor NOTIFYEVENTS_CHANNEL_URL app/.env)"
  umask 077
  {
    echo "INTEGRACAO_DB_HOST=$(valor INTEGRACAO_DB_HOST app/.env)"
    echo "INTEGRACAO_DB_PORT=$(valor INTEGRACAO_DB_PORT app/.env)"
    echo "INTEGRACAO_DB_SCHEMA_NAME=integracao_cv"
    echo "INTEGRACAO_DB_USERNAME=$(valor INTEGRACAO_DB_USERNAME app/.env)"
    echo "INTEGRACAO_DB_PASSWORD=$(valor INTEGRACAO_DB_PASSWORD app/.env)"
    echo "ODOO_URL=$EPHEM_URL"
    echo "ODOO_DB=$EPHEM_DB"
    echo "ODOO_USER=$ODOO_USER"
    echo "ODOO_APIKEY=$ODOO_APIKEY"
    echo "ODOO_LANG=pt_PT"
    echo "EPHEM_V2_ENABLED=true"
    echo "EPHEM_V2_BASE_URL=${EPHEM_URL%/}/api/v2"
    echo "EPHEM_V2_API_KEY=$EPHEM_V2_API_KEY"
    echo "EPHEM_V2_EXTERNAL_ID_PREFIX=$PREFIXO"
    echo "LOGZIO_TOKEN=$(valor LOGZIO_TOKEN app/.env)"
    echo "JVM_OPTIONS=-Xmx384m"
    echo "NOTIFYEVENTS_CHANNEL_URL=$NOTIFY"
  } > app/.env.cv
  echo "criado (permissao 600)"
fi

echo "== 3/4 COMPOSE_FILE no .env"
touch .env
if ! grep -q '^COMPOSE_FILE=' .env; then
  echo "COMPOSE_FILE=docker-compose.yml:docker-compose.cv.yml" >> .env
fi
if [ "$AMBIENTE" = prod ] && ! grep -q '^INTEGRACAO_CV_HOST=' .env; then
  echo "INTEGRACAO_CV_HOST=$HOST_CV" >> .env
fi
docker-compose config --services | grep -qx integracaoapp-cv || { echo "integracaoapp-cv nao aparece no compose; confira o .env" >&2; exit 1; }
echo "ok"

echo "== 4/4 subindo integracaoapp-cv"
docker-compose pull integracaoapp-cv
docker-compose up -d integracaoapp-cv
for _ in $(seq 1 60); do
  if docker-compose logs --tail=200 integracaoapp-cv 2>&1 | grep -q 'Started Gds2ephemApplication'; then
    URL_CV="https://$HOST_CV/cv/api-integracao/v1/v2/api-docs"
    echo "integrador CV no ar; conferindo $URL_CV"
    for _ in $(seq 1 10); do
      CODIGO=$(curl -s -o /dev/null -w '%{http_code}' "$URL_CV" || true)
      [ "$CODIGO" = 200 ] && break
      sleep 3
    done
    echo "HTTP $CODIGO (esperado 200). No GDS, use a URL https://$HOST_CV/cv"
    UNB=$(curl -s -o /dev/null -w '%{http_code}' "https://$HOST_CV/api-integracao/v1/v2/api-docs" || true)
    echo "integrador UnB em https://$HOST_CV/api-integracao/v1: HTTP $UNB"
    free -m 2>/dev/null | head -2 || true
    exit 0
  fi
  if docker-compose logs --tail=200 integracaoapp-cv 2>&1 | grep -q 'APPLICATION FAILED TO START'; then
    docker-compose logs --tail=60 integracaoapp-cv
    exit 1
  fi
  sleep 3
done
echo "a aplicacao nao terminou de subir em 3 minutos; veja: docker-compose logs -f integracaoapp-cv" >&2
exit 1
