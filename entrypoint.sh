#!/bin/sh
set -e

# Prepare vars and default values

INPUT_DEBUG="${INPUT_DEBUG:-false}"

if [[ $INPUT_DEBUG == 'true' ]]; then
  echo "!!! DEBUG MODE ENABLED !!!"
fi

if [[ -z "$INPUT_BRANCH" ]]; then
  INPUT_BRANCH=$GITHUB_HEAD_REF
fi

ESCAPED_BRANCH=$(echo "$INPUT_BRANCH" | sed -e 's/[^a-z0-9-]/-/g' | tr -s '-')

# Remove the trailing "-" character
if [[ $ESCAPED_BRANCH == *- ]]; then
    ESCAPED_BRANCH="${ESCAPED_BRANCH%-}"
fi

if [[ -z "$INPUT_PREFIX_WITH_PR_NUMBER" ]]; then
  INPUT_PREFIX_WITH_PR_NUMBER='true'
fi

if [[ $INPUT_PREFIX_WITH_PR_NUMBER == 'true' ]]; then
  PR_NUMBER=$(echo "$GITHUB_REF_NAME" | grep -oE '[0-9]+')
  ESCAPED_BRANCH=$(echo "$PR_NUMBER-$ESCAPED_BRANCH")
fi

if [[ -z "$INPUT_HOST" ]]; then
  # Compute review-app host
  if [[ -z "$INPUT_ROOT_DOMAIN" ]]; then
    INPUT_HOST=$(echo "$ESCAPED_BRANCH")

    if [[ -n "$INPUT_FQDN_PREFIX" ]]; then
      INPUT_HOST=$(echo "$INPUT_FQDN_PREFIX$INPUT_HOST")
    fi

    # Limit to 64 chars max
    INPUT_HOST="${INPUT_HOST:0:64}"

    # Remove the trailing "-" character
    if [[ $INPUT_HOST == *- ]]; then
        INPUT_HOST="${INPUT_HOST%-}"
    fi
  else
    INPUT_HOST=$(echo "$ESCAPED_BRANCH.$INPUT_ROOT_DOMAIN")

    if [[ -n "$INPUT_FQDN_PREFIX" ]]; then
      INPUT_HOST=$(echo "$INPUT_FQDN_PREFIX$INPUT_HOST")
    fi

    # Limit to 64 chars max
    if [ ${#INPUT_HOST} -gt 64 ]; then
      INPUT_HOST=$(echo "${ESCAPED_BRANCH:0:$((${#ESCAPED_BRANCH} - $((${#INPUT_HOST} - 64))))}.$INPUT_ROOT_DOMAIN")
    fi

    # Remove dash in middle of the host
    if [[ $INPUT_HOST == *-.$INPUT_ROOT_DOMAIN ]]; then
        INPUT_HOST=$(echo $INPUT_HOST | sed "s/-\.$INPUT_ROOT_DOMAIN/\.$INPUT_ROOT_DOMAIN/")
    fi
  fi
fi

if [[ -n "$GITHUB_ACTIONS" && "$GITHUB_ACTIONS" == "true" ]]; then
  echo "host=$INPUT_HOST" >> $GITHUB_OUTPUT
fi

if [[ -z "$INPUT_REPOSITORY" ]]; then
  INPUT_REPOSITORY=$GITHUB_REPOSITORY
fi

if [[ -z "$INPUT_DATABASE_NAME" ]]; then
  # Compute database name
  INPUT_DATABASE_NAME=$(echo "$ESCAPED_BRANCH" | sed -e 's/[^a-z0-9_]/_/g' | tr -s '_')
fi

if [[ -n "$INPUT_DATABASE_NAME_PREFIX" ]]; then
  INPUT_DATABASE_NAME=$(echo "$INPUT_DATABASE_NAME_PREFIX$INPUT_DATABASE_NAME")
fi

# Limit to 63 chars max
INPUT_DATABASE_NAME="${INPUT_DATABASE_NAME:0:63}"

if [[ -n "$GITHUB_ACTIONS" && "$GITHUB_ACTIONS" == "true" ]]; then
  echo "database_name=$INPUT_DATABASE_NAME" >> $GITHUB_OUTPUT
fi

AUTH_HEADER="Authorization: Bearer $INPUT_API_TOKEN"

if [[ -z "$INPUT_TYPE" ]]; then
  INPUT_TYPE='php'
fi

if [[ -z "$INPUT_WEB_DIRECTORY" ]]; then
  INPUT_WEB_DIRECTORY='public'
fi

if [[ -z "$INPUT_ISOLATED" ]]; then
  INPUT_ISOLATED='false'
fi

if [[ -z "$INPUT_PHP_VERSION" ]]; then
  INPUT_PHP_VERSION='php83'
fi

if [[ -z "$INPUT_CREATE_DATABASE" ]]; then
  INPUT_CREATE_DATABASE='false'
fi

if [[ -z "$INPUT_DATABASE_USER" ]]; then
  INPUT_DATABASE_USER='vito'
fi

if [[ -z "$INPUT_CONFIGURE_REPOSITORY" ]]; then
  INPUT_CONFIGURE_REPOSITORY='true'
fi

if [[ -z "$INPUT_REPOSITORY_PROVIDER" ]]; then
  INPUT_REPOSITORY_PROVIDER='github'
fi

if [[ -z "$INPUT_COMPOSER" ]]; then
  INPUT_COMPOSER='false'
fi

if [[ -z "$INPUT_LETSENCRYPT_CERTIFICATE" ]]; then
  INPUT_LETSENCRYPT_CERTIFICATE='true'
fi

if [[ -z "$INPUT_CERTIFICATE_SETUP_TIMEOUT" ]]; then
  INPUT_CERTIFICATE_SETUP_TIMEOUT='120'
fi

if [[ -z "$INPUT_ENV_STUB_PATH" ]]; then
  INPUT_ENV_STUB_PATH='.github/workflows/.env.stub'
fi

if [[ -z "$INPUT_DEPLOY_SCRIPT_STUB_PATH" ]]; then
  INPUT_DEPLOY_SCRIPT_STUB_PATH='.github/workflows/deploy-script.stub'
fi

if [[ -z "$INPUT_DEPLOYMENT_TIMEOUT" ]]; then
  INPUT_DEPLOYMENT_TIMEOUT='120'
fi

if [[ -z "$INPUT_DEPLOYMENT_AUTO_SOURCE" ]]; then
  INPUT_DEPLOYMENT_AUTO_SOURCE='true'
fi

if [[ -z "$INPUT_CREATE_WORKER" ]]; then
  INPUT_CREATE_WORKER='false'
fi

if [[ -z "$INPUT_WORKER_CONNECTION" ]]; then
  INPUT_WORKER_CONNECTION='redis'
fi

if [[ -z "$INPUT_WORKER_TIMEOUT" ]]; then
  INPUT_WORKER_TIMEOUT='90'
fi

if [[ -z "$INPUT_WORKER_SLEEP" ]]; then
  INPUT_WORKER_SLEEP='60'
fi

if [[ -z "$INPUT_WORKER_PROCESSES" ]]; then
  INPUT_WORKER_PROCESSES='1'
fi

if [[ -z "$INPUT_WORKER_STOPWAITSECS" ]]; then
  INPUT_WORKER_STOPWAITSECS='600'
fi

if [[ -z "$INPUT_WORKER_PHP_VERSION" ]]; then
  INPUT_WORKER_PHP_VERSION=$INPUT_PHP_VERSION
fi

if [[ -z "$INPUT_SITE_SETUP_TIMEOUT" ]]; then
  INPUT_SITE_SETUP_TIMEOUT='600'
fi

if [[ -z "$INPUT_WORKER_DAEMON" ]]; then
  INPUT_WORKER_DAEMON='true'
fi

if [[ -z "$INPUT_WORKER_FORCE" ]]; then
  INPUT_WORKER_FORCE='false'
fi

echo ""
echo "* Check that stubs files exists"

if [ ! -e "/github/workspace/$INPUT_ENV_STUB_PATH" ]; then
  echo ".env stub file not found at /github/workspace/$INPUT_ENV_STUB_PATH"
  exit 1
fi

if [ ! -e "/github/workspace/$INPUT_DEPLOY_SCRIPT_STUB_PATH" ]; then
  echo "Deploy script stub file not found at /github/workspace/$INPUT_DEPLOY_SCRIPT_STUB_PATH"
  exit 1
fi

echo ".env and deploy script stub files found"

echo ""
echo '* Get VitoDeploy server sites'
API_URL="$INPUT_API_BASE_URL/projects/$INPUT_PROJECT_ID/servers/$INPUT_SERVER_ID/sites"

if [[ $INPUT_DEBUG == 'true' ]]; then
  echo "[DEBUG] CURL GET on $API_URL"
  echo ""
fi

JSON_RESPONSE=$(
  curl -s -H "$AUTH_HEADER" \
    -H "Accept: application/json" \
    "$API_URL"
)
echo "$JSON_RESPONSE" > sites.json

if [[ $INPUT_DEBUG == 'true' ]]; then
  echo "[DEBUG] response JSON:"
  echo $JSON_RESPONSE
  echo ""
fi

# Check if review-app site exists
SITE_DATA=$(jq -r '.data[] | select(.domain == "'"$INPUT_HOST"'") // empty' sites.json)
if [[ ! -z "$SITE_DATA" ]]; then
  echo "$SITE_DATA" > site.json
  SITE_ID=$(jq -r '.id' site.json)
  SITE_PATH=$(echo "$SITE_DATA" | jq -r '.path')

  if [[ -n "$GITHUB_ACTIONS" && "$GITHUB_ACTIONS" == "true" ]]; then
    echo "site_id=$SITE_ID" >> $GITHUB_OUTPUT
  fi

  echo "A site (ID $SITE_ID) domain match the host"
  RA_FOUND='true'
else
  echo "Site $INPUT_HOST not found"
  RA_FOUND='false'
fi

if [[ $RA_FOUND == 'false' ]]; then
  echo ""
  echo "* Create review-app site"

  API_URL="$INPUT_API_BASE_URL/projects/$INPUT_PROJECT_ID/servers/$INPUT_SERVER_ID/sites"

  JSON_PAYLOAD='{
    "domain": "'"$INPUT_HOST"'",
    "type": "'"$INPUT_TYPE"'",
    "web_directory": "'"$INPUT_WEB_DIRECTORY"'",
    "source_control": '"$INPUT_SOURCE_CONTROL"',
    "repository": "'"$INPUT_REPOSITORY"'",
    "branch": "'"$INPUT_BRANCH"'",
    "composer": '"$INPUT_COMPOSER"',
    "php_version": "'"$INPUT_PHP_VERSION"'"
  }'

  if [[ $INPUT_DEBUG == 'true' ]]; then
    echo "[DEBUG] CURL POST on $API_URL with payload :"
    echo $JSON_PAYLOAD
    echo ""
  fi

  HTTP_STATUS=$(
    curl -s -o response.json -w "%{http_code}" \
      -X POST \
      -H "$AUTH_HEADER" \
      -H "Accept: application/json" \
      -H "Content-Type: application/json" \
      -d "$JSON_PAYLOAD" \
      "$API_URL"
  )

  JSON_RESPONSE=$(cat response.json)

  if [[ $INPUT_DEBUG == 'true' ]]; then
    echo "[DEBUG] response JSON:"
    echo $JSON_RESPONSE
    echo ""
  fi

  if [[ $HTTP_STATUS -eq 201 ]]; then
    SITE_ID=$(jq -r '.id' response.json)
    SITE_PATH=$(jq -r '.path' response.json)

    if [[ -n "$GITHUB_ACTIONS" && "$GITHUB_ACTIONS" == "true" ]]; then
      echo "site_id=$SITE_ID" >> $GITHUB_OUTPUT
    fi

    echo "New site (ID $SITE_ID) is being created"
  else
    echo "Failed to create new site. HTTP status code: $HTTP_STATUS"
    echo "JSON Response:"
    echo "$JSON_RESPONSE"
    exit 1
  fi

  echo ""
  echo "* Wait for website to be fully created"

  SITE_DATA=$(cat response.json)
  SITE_ID=$(echo "$SITE_DATA" | jq -r '.id')
  SITE_PATH=$(echo "$SITE_DATA" | jq -r '.path')

  API_URL="$INPUT_API_BASE_URL/projects/$INPUT_PROJECT_ID/servers/$INPUT_SERVER_ID/sites/$SITE_ID"

  start_time=$(date +%s)
  elapsed_time=0
  status=""

  while [[ "$status" != "ready" && "$elapsed_time" -lt $INPUT_SITE_SETUP_TIMEOUT ]]; do
    if [[ $INPUT_DEBUG == 'true' ]]; then
      echo "[DEBUG] CURL GET on $API_URL "
      echo ""
    fi

    HTTP_STATUS=$(
      curl -s -o response.json -w "%{http_code}" \
      -X GET \
      -H "$AUTH_HEADER" \
      -H "Accept: application/json" \
      -H "Content-Type: application/json" \
      "$API_URL"
    )

    JSON_RESPONSE=$(cat response.json)

    if [[ $INPUT_DEBUG == 'true' ]]; then
      echo "[DEBUG] response JSON:"
      echo $JSON_RESPONSE
      echo ""
    fi

    if [[ "$HTTP_STATUS" != "200" ]]; then
      echo "Response code is not 200 but $HTTP_STATUS"
      echo "API Response:"
      echo "$JSON_RESPONSE"
      exit 1
    fi

    status=$(echo "$JSON_RESPONSE" | jq -r '."status"')

    if [[ "$status" != "ready" ]]; then
      echo "Status is not \"ready\" (but \""$status"\"), retrying in 5 seconds..."
      sleep 5
    fi

    current_time=$(date +%s)
    elapsed_time=$((current_time - start_time))
  done

  if [[ "$status" != "ready" ]]; then
    echo "Timeout reached, exiting retry loop."
    exit 1
  else
    SITE_PATH=$(echo "$SITE_DATA" | jq -r '.path')
    echo "Site installed successfully"
  fi
fi

# TODO: SSL, how? Not supported in the API

if [[ $INPUT_CREATE_DATABASE == 'true' ]]; then
  if [[ $INPUT_CREATE_DATABASE_USER == 'true' ]]; then
    echo ""
    echo '* Get server database users'
    API_URL="$INPUT_API_BASE_URL/projects/$INPUT_PROJECT_ID/servers/$INPUT_SERVER_ID/database-users"

    if [[ $INPUT_DEBUG == 'true' ]]; then
      echo "[DEBUG] CURL GET on $API_URL"
      echo ""
    fi

    JSON_RESPONSE=$(
      curl -s -H "$AUTH_HEADER" \
        -H "Accept: application/json" \
        "$API_URL"
    )
    echo "$JSON_RESPONSE" > database-users.json

    if [[ $INPUT_DEBUG == 'true' ]]; then
      echo "[DEBUG] response JSON:"
      echo $JSON_RESPONSE
      echo ""
    fi

    DATABASE_USER_DATA=$(jq -r '.data[] | select(.username == "'"$INPUT_DATABASE_USER"'") // empty' database-users.json)
    if [[ ! -z "$DATABASE_USER_DATA" ]]; then
      echo "$DATABASE_USER_DATA" > database-user.json
      INPUT_DATABASE_USER_ID=$(jq -r '.id' database-user.json)
      DATABASE_USER_DATABASES=$(jq -r '.databases' database-user.json)

      if [[ -n "$GITHUB_ACTIONS" && "$GITHUB_ACTIONS" == "true" ]]; then
        echo "database_user_id=$INPUT_DATABASE_USER_ID" >> $GITHUB_OUTPUT
      fi

      echo "A database user (ID $INPUT_DATABASE_USER_ID) name match"
      DATABASE_USER_FOUND='true'
    else
      echo "Database user $INPUT_DATABASE_USER not found"
      DATABASE_USER_FOUND='false'
    fi

    if [[ $DATABASE_USER_FOUND == 'false' ]]; then
      echo ""
      echo "* Create review-app database user"

      API_URL="$INPUT_API_BASE_URL/projects/$INPUT_PROJECT_ID/servers/$INPUT_SERVER_ID/database-users"

      JSON_PAYLOAD='{
        "username": "'"$INPUT_DATABASE_USER"'",
        "password": "'"$INPUT_DATABASE_PASSWORD"'",
        "host": "%"
      }'

      if [[ $INPUT_DEBUG == 'true' ]]; then
        echo "[DEBUG] CURL POST on $API_URL with payload :"
        echo $JSON_PAYLOAD
        echo ""
      fi

      HTTP_STATUS=$(
        curl -s -o response.json -w "%{http_code}" \
          -X POST \
          -H "$AUTH_HEADER" \
          -H "Accept: application/json" \
          -H "Content-Type: application/json" \
          -d "$JSON_PAYLOAD" \
          "$API_URL"
      )

      JSON_RESPONSE=$(cat response.json)

      if [[ $INPUT_DEBUG == 'true' ]]; then
        echo "[DEBUG] response JSON:"
        echo $JSON_RESPONSE
        echo ""
      fi

      if [[ $HTTP_STATUS -eq 200 ]]; then
        DATABASE_USER_ID=$(jq -r '.id' response.json)

        if [[ -n "$GITHUB_ACTIONS" && "$GITHUB_ACTIONS" == "true" ]]; then
          echo "database_user_id=$INPUT_DATABASE_USER_ID" >> $GITHUB_OUTPUT
        fi

        echo "New database user (ID $INPUT_DATABASE_USER_ID) created successfully"
      else
        echo "Failed to create new database user. HTTP status code: $HTTP_STATUS"
        echo "JSON Response:"
        echo "$JSON_RESPONSE"
        exit 1
      fi
    fi
  else
    echo ""
    echo "* Find database user"

    API_URL="$INPUT_API_BASE_URL/projects/$INPUT_PROJECT_ID/servers/$INPUT_SERVER_ID/database-users/$INPUT_DATABASE_USER_ID"

    if [[ $INPUT_DEBUG == 'true' ]]; then
      echo "[DEBUG] CURL GET on $API_URL "
      echo ""
    fi

    HTTP_STATUS=$(
      curl -s -o response.json -w "%{http_code}" \
      -X GET \
      -H "$AUTH_HEADER" \
      -H "Accept: application/json" \
      -H "Content-Type: application/json" \
      "$API_URL"
    )

    JSON_RESPONSE=$(cat response.json)

    if [[ $INPUT_DEBUG == 'true' ]]; then
      echo "[DEBUG] response JSON:"
      echo $JSON_RESPONSE
      echo ""
    fi

    if [[ "$HTTP_STATUS" != "200" ]]; then
      echo "Response code is not 200 but $HTTP_STATUS"
      echo "API Response:"
      echo "$JSON_RESPONSE"
      exit 1
    fi

    echo "$JSON_RESPONSE" > database-user.json
    DATABASE_USER_DATABASES=$(jq -r '.databases' database-user.json)
  fi

  echo ""
  echo '* Get server databases'
  API_URL="$INPUT_API_BASE_URL/projects/$INPUT_PROJECT_ID/servers/$INPUT_SERVER_ID/databases"

  if [[ $INPUT_DEBUG == 'true' ]]; then
    echo "[DEBUG] CURL GET on $API_URL"
    echo ""
  fi

  JSON_RESPONSE=$(
    curl -s -H "$AUTH_HEADER" \
      -H "Accept: application/json" \
      "$API_URL"
  )
  echo "$JSON_RESPONSE" > databases.json

  if [[ $INPUT_DEBUG == 'true' ]]; then
    echo "[DEBUG] response JSON:"
    echo $JSON_RESPONSE
    echo ""
  fi

  DATABASE_DATA=$(jq -r '.data[] | select(.name == "'"$INPUT_DATABASE_NAME"'") // empty' databases.json)
  if [[ ! -z "$DATABASE_DATA" ]]; then
    echo "$DATABASE_DATA" > database.json
    DATABASE_ID=$(jq -r '.id' database.json)

    if [[ -n "$GITHUB_ACTIONS" && "$GITHUB_ACTIONS" == "true" ]]; then
      echo "database_id=$DATABASE_ID" >> $GITHUB_OUTPUT
    fi

    echo "A database (ID $DATABASE_ID) name match"
    DATABASE_FOUND='true'
  else
    echo "Database $INPUT_DATABASE_NAME not found"
    DATABASE_FOUND='false'
  fi

  if [[ $DATABASE_FOUND == 'false' ]]; then
    echo ""
    echo "* Create review-app database"

    API_URL="$INPUT_API_BASE_URL/projects/$INPUT_PROJECT_ID/servers/$INPUT_SERVER_ID/databases"

    JSON_PAYLOAD='{
      "name": "'"$INPUT_DATABASE_NAME"'",
      "charset": "'"$INPUT_DATABASE_CHARSET"'",
      "collation": "'"$INPUT_DATABASE_COLLATION"'"
    }'

    if [[ $INPUT_DEBUG == 'true' ]]; then
      echo "[DEBUG] CURL POST on $API_URL with payload :"
      echo $JSON_PAYLOAD
      echo ""
    fi

    HTTP_STATUS=$(
      curl -s -o response.json -w "%{http_code}" \
        -X POST \
        -H "$AUTH_HEADER" \
        -H "Accept: application/json" \
        -H "Content-Type: application/json" \
        -d "$JSON_PAYLOAD" \
        "$API_URL"
    )

    JSON_RESPONSE=$(cat response.json)

    if [[ $INPUT_DEBUG == 'true' ]]; then
      echo "[DEBUG] response JSON:"
      echo $JSON_RESPONSE
      echo ""
    fi

    if [[ $HTTP_STATUS -eq 201 ]]; then
      DATABASE_ID=$(jq -r '.id' response.json)

      if [[ -n "$GITHUB_ACTIONS" && "$GITHUB_ACTIONS" == "true" ]]; then
        echo "database_id=$DATABASE_ID" >> $GITHUB_OUTPUT
      fi

      echo "New database (ID $DATABASE_ID) is begin created"
    else
      echo "Failed to create new database. HTTP status code: $HTTP_STATUS"
      echo "JSON Response:"
      echo "$JSON_RESPONSE"
      exit 1
    fi

    echo ""
    echo "* Wait for database to be fully created"

    DATABASE_DATA=$(cat response.json)
    DATABASE_ID=$(echo "$DATABASE_DATA" | jq -r '.id')

    API_URL="$INPUT_API_BASE_URL/projects/$INPUT_PROJECT_ID/servers/$INPUT_SERVER_ID/databases/$DATABASE_ID"

    start_time=$(date +%s)
    elapsed_time=0
    status=""

    while [[ "$status" != "ready" && "$elapsed_time" -lt $INPUT_DATABASE_SETUP_TIMEOUT ]]; do
      if [[ $INPUT_DEBUG == 'true' ]]; then
        echo "[DEBUG] CURL GET on $API_URL "
        echo ""
      fi

      HTTP_STATUS=$(
        curl -s -o response.json -w "%{http_code}" \
        -X GET \
        -H "$AUTH_HEADER" \
        -H "Accept: application/json" \
        -H "Content-Type: application/json" \
        "$API_URL"
      )

      JSON_RESPONSE=$(cat response.json)

      if [[ $INPUT_DEBUG == 'true' ]]; then
        echo "[DEBUG] response JSON:"
        echo $JSON_RESPONSE
        echo ""
      fi

      if [[ "$HTTP_STATUS" != "200" ]]; then
        echo "Response code is not 200 but $HTTP_STATUS"
        echo "API Response:"
        echo "$JSON_RESPONSE"
        exit 1
      fi

      status=$(echo "$JSON_RESPONSE" | jq -r '."status"')

      if [[ "$status" != "ready" ]]; then
        echo "Status is not \"ready\" (but \""$status"\"), retrying in 5 seconds..."
        sleep 5
      fi

      current_time=$(date +%s)
      elapsed_time=$((current_time - start_time))
    done

    if [[ "$status" != "ready" ]]; then
      echo "Timeout reached, exiting retry loop."
      exit 1
    else
      echo "Database installed successfully"
    fi
  fi

  echo ""
  echo "* Check if database is not already linked to database user"

  linked=$(jq --arg val "$INPUT_DATABASE_NAME" '.databases | index($val) != null' database-user.json)

  if [[ "$linked" = "true" ]]; then
    echo "Already linked, nothing to do."
  else
    echo "Not linked."

    echo ""
    echo "* Link database user"

    API_URL="$INPUT_API_BASE_URL/projects/$INPUT_PROJECT_ID/servers/$INPUT_SERVER_ID/database-users/$INPUT_DATABASE_USER_ID/link"

    JSON_PAYLOAD='{
      "databases": '"$(jq -r '.databases + [ "'$INPUT_DATABASE_NAME'" ]' database-user.json)"'
    }'

    if [[ $INPUT_DEBUG == 'true' ]]; then
      echo "[DEBUG] CURL POST on $API_URL with payload :"
      echo $JSON_PAYLOAD
      echo ""
    fi

    HTTP_STATUS=$(
      curl -s -o response.json -w "%{http_code}" \
        -X POST \
        -H "$AUTH_HEADER" \
        -H "Accept: application/json" \
        -H "Content-Type: application/json" \
        -d "$JSON_PAYLOAD" \
        "$API_URL"
    )

    JSON_RESPONSE=$(cat response.json)

    if [[ $INPUT_DEBUG == 'true' ]]; then
      echo "[DEBUG] response JSON:"
      echo $JSON_RESPONSE
      echo ""
    fi

    if [[ $HTTP_STATUS -eq 200 ]]; then
      DATABASE_ID=$(jq -r '.id' response.json)

      if [[ -n "$GITHUB_ACTIONS" && "$GITHUB_ACTIONS" == "true" ]]; then
        echo "database_id=$DATABASE_ID" >> $GITHUB_OUTPUT
      fi

      echo "Database (ID $DATABASE_ID) linked with user (ID $INPUT_DATABASE_USER_ID) successfully"
    else
      echo "Failed to link database (ID $DATABASE_ID) linked with user (ID $INPUT_DATABASE_USER_ID). HTTP status code: $HTTP_STATUS"
      echo "JSON Response:"
      echo "$JSON_RESPONSE"
      exit 1
    fi
  fi
fi

echo ""
echo "* Setup .env file"

cp /github/workspace/$INPUT_ENV_STUB_PATH .env

if [[ $INPUT_DEBUG == 'true' ]]; then
  echo "[DEBUG] Stub .env file content:"
  cat .env
  echo ""
fi

sed -i -e "s#STUB_HOST#$INPUT_HOST#" .env
sed -i -e "s#STUB_DATABASE_NAME#$INPUT_DATABASE_NAME#" .env
sed -i -e "s#STUB_DATABASE_USER#$INPUT_DATABASE_USER#" .env
sed -i -e "s#STUB_DATABASE_PASSWORD#$INPUT_DATABASE_PASSWORD#" .env

ENV_CONTENT=$(cat .env)

if [[ $INPUT_DEBUG == 'true' ]]; then
  echo "[DEBUG] Generated .env file content:"
  echo $ENV_CONTENT
  echo ""
fi

ESCAPED_ENV_CONTENT=$(echo "$ENV_CONTENT" | jq -Rsa .)

if [[ $INPUT_DEBUG == 'true' ]]; then
  echo "[DEBUG] Escaped .env file content:"
  echo $ESCAPED_ENV_CONTENT
  echo ""
fi

API_URL="$INPUT_API_BASE_URL/projects/$INPUT_PROJECT_ID/servers/$INPUT_SERVER_ID/sites/$SITE_ID/env"

JSON_PAYLOAD='{
  "env": '"$ESCAPED_ENV_CONTENT"',
  "path": "'"$SITE_PATH/.env"'"
}'

if [[ $INPUT_DEBUG == 'true' ]]; then
  echo "[DEBUG] CURL PUT on $API_URL with payload :"
  echo $JSON_PAYLOAD
  echo ""
fi

HTTP_STATUS=$(
  curl -s -o response.json -w "%{http_code}" \
    -X PUT \
    -H "$AUTH_HEADER" \
    -H "Accept: application/json" \
    -H "Content-Type: application/json" \
    -d "$JSON_PAYLOAD" \
    "$API_URL"
)

JSON_RESPONSE=$(cat response.json)

if [[ $INPUT_DEBUG == 'true' ]]; then
  echo "[DEBUG] response JSON:"
  echo $JSON_RESPONSE
  echo ""
fi

if [[ $HTTP_STATUS -eq 200 ]]; then
  echo ".env file updated successfully"
else
  echo "Failed to update .env file. HTTP status code: $HTTP_STATUS"
  echo "JSON Response:"
  echo "$JSON_RESPONSE"
  exit 1
fi

echo ""
echo "* Setup deploy script"

cp /github/workspace/$INPUT_DEPLOY_SCRIPT_STUB_PATH deploy-script

sed -i -e "s#STUB_HOST#$INPUT_HOST#" deploy-script

DEPLOY_SCRIPT_CONTENT=$(cat deploy-script)
ESCAPED_DEPLOY_SCRIPT_CONTENT=$(echo "$DEPLOY_SCRIPT_CONTENT" | jq -Rsa .)

API_URL="$INPUT_API_BASE_URL/projects/$INPUT_PROJECT_ID/servers/$INPUT_SERVER_ID/sites/$SITE_ID/deployment-script"

JSON_PAYLOAD='{
  "script": '"$ESCAPED_DEPLOY_SCRIPT_CONTENT"'
}'

if [[ $INPUT_DEBUG == 'true' ]]; then
  echo "[DEBUG] CURL POST on $API_URL with payload :"
  echo $JSON_PAYLOAD
  echo ""
fi

HTTP_STATUS=$(
  curl -s -o response.json -w "%{http_code}" \
    -X PUT \
    -H "$AUTH_HEADER" \
    -H "Accept: application/json" \
    -H "Content-Type: application/json" \
    -d "$JSON_PAYLOAD" \
    "$API_URL"
)

JSON_RESPONSE=$(cat response.json)

if [[ $INPUT_DEBUG == 'true' ]]; then
  echo "[DEBUG] response JSON:"
  echo $JSON_RESPONSE
  echo ""
fi

if [[ $HTTP_STATUS -eq 204 ]]; then
  echo "Deployment script updated successfully"
else
  echo "Failed to update deployment script. HTTP status code: $HTTP_STATUS"
  echo "JSON Response:"
  echo "$JSON_RESPONSE"
  exit 1
fi

echo ""
echo "* Launch deployment"

API_URL="$INPUT_API_BASE_URL/projects/$INPUT_PROJECT_ID/servers/$INPUT_SERVER_ID/sites/$SITE_ID/deployments"

HTTP_STATUS=$(
  curl -s -o response.json -w "%{http_code}" \
    -X POST \
    -H "$AUTH_HEADER" \
    -H "Accept: application/json" \
    -H "Content-Type: application/json" \
    "$API_URL"
)

if [[ $INPUT_DEBUG == 'true' ]]; then
  echo "[DEBUG] CURL POST on $API_URL with payload :"
  echo $JSON_PAYLOAD
  echo ""
fi

JSON_RESPONSE=$(cat response.json)

if [[ $INPUT_DEBUG == 'true' ]]; then
  echo "[DEBUG] response JSON:"
  echo $JSON_RESPONSE
  echo ""
fi

if [[ $HTTP_STATUS -eq 201 ]]; then
  echo "Deployment launched successfully"
else
  echo "Failed to launch deployment. HTTP status code: $HTTP_STATUS"
  echo "JSON Response:"
  echo "$JSON_RESPONSE"
  exit 1
fi

echo ""
echo "* Wait for deployment to be fully done"

DEPLOYMENT_DATA=$(cat response.json)
DEPLOYMENT_ID=$(echo "$DEPLOYMENT_DATA" | jq -r '.id')

API_URL="$INPUT_API_BASE_URL/projects/$INPUT_PROJECT_ID/servers/$INPUT_SERVER_ID/sites/$SITE_ID/deployments/$DEPLOYMENT_ID"

start_time=$(date +%s)
elapsed_time=0
status=""

while [[ "$status" != "finished" && "$elapsed_time" -lt $INPUT_DEPLOYMENT_TIMEOUT ]]; do
  if [[ $INPUT_DEBUG == 'true' ]]; then
    echo "[DEBUG] CURL GET on $API_URL "
    echo ""
  fi

  HTTP_STATUS=$(
    curl -s -o response.json -w "%{http_code}" \
    -X GET \
    -H "$AUTH_HEADER" \
    -H "Accept: application/json" \
    -H "Content-Type: application/json" \
    "$API_URL"
  )

  JSON_RESPONSE=$(cat response.json)

  if [[ $INPUT_DEBUG == 'true' ]]; then
    echo "[DEBUG] response JSON:"
    echo $JSON_RESPONSE
    echo ""
  fi

  if [[ "$HTTP_STATUS" != "200" ]]; then
    echo "Response code is not 200 but $HTTP_STATUS"
    echo "API Response:"
    echo "$JSON_RESPONSE"
    exit 1
  fi

  status=$(echo "$JSON_RESPONSE" | jq -r '."status"')

  if [[ "$status" != "finished" ]]; then
    echo "Status is not \"finished\" (but \""$status"\"), retrying in 5 seconds..."
    sleep 5
  fi

  current_time=$(date +%s)
  elapsed_time=$((current_time - start_time))
done

if [[ "$status" != "finished" ]]; then
  echo "Timeout reached, exiting retry loop."
  exit 1
else
  echo "Deployment finished successfully"
fi

# TODO: Workers
