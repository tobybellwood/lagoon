#!/bin/bash
set -x
set -eo pipefail
set -o noglob

OPENSHIFT_REGISTRY=docker-registry.default.svc:5000
OPENSHIFT_PROJECT=$(cat /var/run/secrets/kubernetes.io/serviceaccount/namespace)
REGISTRY_REPOSITORY=$OPENSHIFT_PROJECT

if [ ! -z "$LAGOON_PROJECT_VARIABLES" ]; then
  INTERNAL_REGISTRY_URL=$(jq --argjson data "$LAGOON_PROJECT_VARIABLES" -n -r '$data | .[] | select(.scope == "internal_container_registry") | select(.name == "INTERNAL_REGISTRY_URL") | .value' | sed -e 's#^http://##' | sed -e 's#^https://##')
  INTERNAL_REGISTRY_USERNAME=$(jq --argjson data "$LAGOON_PROJECT_VARIABLES" -n -r '$data | .[] | select(.scope == "internal_container_registry") | select(.name == "INTERNAL_REGISTRY_USERNAME") | .value')
  INTERNAL_REGISTRY_PASSWORD=$(jq --argjson data "$LAGOON_PROJECT_VARIABLES" -n -r '$data | .[] | select(.scope == "internal_container_registry") | select(.name == "INTERNAL_REGISTRY_PASSWORD") | .value')
fi

if [ "$CI" == "true" ]; then
  CI_OVERRIDE_IMAGE_REPO=${OPENSHIFT_REGISTRY}/lagoon
else
  CI_OVERRIDE_IMAGE_REPO=""
fi

if [ "$TYPE" == "pullrequest" ]; then
  /oc-build-deploy/scripts/git-checkout-pull-merge.sh "$SOURCE_REPOSITORY" "$PR_HEAD_SHA" "$PR_BASE_SHA"
else
  /oc-build-deploy/scripts/git-checkout-pull.sh "$SOURCE_REPOSITORY" "$GIT_REF"
fi

if [[ -n "$SUBFOLDER" ]]; then
  cd $SUBFOLDER
fi

if [ ! -f .lagoon.yml ]; then
  echo "no .lagoon.yml file found"; exit 1;
fi

INJECT_GIT_SHA=$(cat .lagoon.yml | shyaml get-value environment_variables.git_sha false)
if [ "$INJECT_GIT_SHA" == "true" ]
then
  LAGOON_GIT_SHA=`git rev-parse HEAD`
else
  LAGOON_GIT_SHA="0000000000000000000000000000000000000000"
fi

set +x
DOCKER_REGISTRY_TOKEN=$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)

docker login -u=jenkins -p="${DOCKER_REGISTRY_TOKEN}" ${OPENSHIFT_REGISTRY}

INTERNAL_REGISTRY_LOGGED_IN="false"
if [ ! -z ${INTERNAL_REGISTRY_URL} ] && [ ! -z ${INTERNAL_REGISTRY_USERNAME} ] && [ ! -z ${INTERNAL_REGISTRY_PASSWORD} ] ; then
  if echo "docker login -u '${INTERNAL_REGISTRY_USERNAME}' -p '${INTERNAL_REGISTRY_PASSWORD}' ${INTERNAL_REGISTRY_URL}" | /bin/bash; then
    INTERNAL_REGISTRY_LOGGED_IN="true"
  fi
fi

DEPLOYER_TOKEN=$(cat /var/run/secrets/lagoon/deployer/token)

oc login --insecure-skip-tls-verify --token="${DEPLOYER_TOKEN}" https://kubernetes.default.svc
set -x

oc project --insecure-skip-tls-verify $OPENSHIFT_PROJECT

ADDITIONAL_YAMLS=($(cat .lagoon.yml | shyaml keys additional-yaml || echo ""))

for ADDITIONAL_YAML in "${ADDITIONAL_YAMLS[@]}"
do
  ADDITIONAL_YAML_PATH=$(cat .lagoon.yml | shyaml get-value additional-yaml.$ADDITIONAL_YAML.path false)
  if [ $ADDITIONAL_YAML_PATH == "false" ]; then
    echo "No 'path' defined for additional yaml $ADDITIONAL_YAML"; exit 1;
  fi

  if [ ! -f $ADDITIONAL_YAML_PATH ]; then
    echo "$ADDITIONAL_YAML_PATH for additional yaml $ADDITIONAL_YAML not found"; exit 1;
  fi

  ADDITIONAL_YAML_COMMAND=$(cat .lagoon.yml | shyaml get-value additional-yaml.$ADDITIONAL_YAML.command apply)
  ADDITIONAL_YAML_IGNORE_ERROR=$(set -o pipefail; cat .lagoon.yml | shyaml get-value additional-yaml.$ADDITIONAL_YAML.ignore_error false | tr '[:upper:]' '[:lower:]')
  . /oc-build-deploy/scripts/exec-additional-yaml.sh
done

.  /oc-build-deploy/build-deploy-docker-compose.sh
