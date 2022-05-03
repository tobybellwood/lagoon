
# These steps assume you have tools like helm, kubectl etc all installed.

# Find the IP address for the network - replace this in all the helmvalues files (may be 172.17.0.2 or similar)

    If it's KinD:
    docker network create kind || true && docker run --rm --network kind alpine ip -o addr show eth0 | sed -nE 's/.* ([0-9.]{7,})\/.*/\1/p'

    If it's Microk8s:
    (see section at bottom)

# e.g. sample replace command - use the output from above in the second half of the sed command below
find ./helmvalues -type f | xargs sed -i "s/172.17.0.2/{your_ip}}/g"

    # Create the cluster - KinD
    kind create cluster --wait=120s --config=helmvalues/kind-config.yaml

    # Create the cluster - Microk8s
    (see section at bottom)

# Optional Set up kubectx and kubens (or similar) - if you have these tools
kubectx kind-lagoon-local && kubens default

# Install/Update all necessary Helm repositories
helm plugin install https://github.com/aslafy-z/helm-git
helm repo add harbor https://helm.goharbor.io
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo add stable https://charts.helm.sh/stable
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo add minio https://helm.min.io/
helm repo add amazeeio https://amazeeio.github.io/charts/
helm repo add lagoon https://uselagoon.github.io/lagoon-charts/
helm repo update

# Install the cluster prerequisites (currently version pinned)
microk8s helm3 upgrade --install --create-namespace --namespace ingress-nginx --wait --timeout 30m --version 3.40.0 ingress-nginx ingress-nginx/ingress-nginx -f helmvalues/ingress-nginx.yaml
microk8s helm3 upgrade --install --create-namespace --namespace registry --wait --timeout 30m --version 1.5.6 registry harbor/harbor -f helmvalues/registry.yaml
microk8s helm3 upgrade --install --create-namespace --namespace nfs-server-provisioner --wait --timeout 30m --version 1.1.3 nfs-server-provisioner stable/nfs-server-provisioner -f helmvalues/nfs-server-provisioner.yaml
microk8s helm3 upgrade --install --create-namespace --namespace minio --wait --timeout 30m --version 8.1.11 minio bitnami/minio -f helmvalues/minio.yaml

# Install the DBaaS databases as required
microk8s helm3 upgrade --install --create-namespace --namespace mariadb --wait --timeout 30m --version=10.1.1 mariadb bitnami/mariadb -f helmvalues/local.yaml
microk8s helm3 upgrade --install --create-namespace --namespace postgresql --wait --timeout 30m --version=10.13.14 postgresql bitnami/postgresql -f helmvalues/local.yaml
microk8s helm3 upgrade --install --create-namespace --namespace mongodb --wait --timeout 30m --version=10.30.6 mongodb bitnami/mongodb -f helmvalues/local.yaml

# Install the Lagoon components
microk8s helm3 upgrade --install --create-namespace --namespace lagoon --wait --timeout 30m lagoon-core lagoon/lagoon-core -f helmvalues/lagoon-core.yaml -f helmvalues/local.yaml
microk8s helm3 upgrade --install --create-namespace --namespace lagoon --wait --timeout 30m lagoon-build-deploy lagoon/lagoon-build-deploy -f helmvalues/lagoon-build-deploy.yaml -f helmvalues/local.yaml
microk8s helm3 upgrade --install --create-namespace --namespace lagoon --wait --timeout 30m lagoon-remote lagoon/lagoon-remote -f helmvalues/lagoon-remote.yaml -f helmvalues/local.yaml

# Install any additional tooling
microk8s helm3 upgrade --install --create-namespace --namespace gitea --wait --timeout 30m gitea gitea-charts/gitea -f helmvalues/gitea.yaml

# To install a component from the local lagoon-charts (e.g lagoon-core)
microk8s helm3 upgrade --install --create-namespace --namespace lagoon --wait --timeout 30m lagoon-core ../lagoon-charts/charts/lagoon-core -f helmvalues/lagoon-core.yaml -f helmvalues/local.yaml

# Need a token installed into the tests charts to allow it to talk to core
microk8s kubectl -n lagoon get secret -o json | jq -r '.items[] | select(.metadata.name | match("lagoon-build-deploy-token")) | .data.token | @base64d' | xargs -I ARGS yq -i eval '.token = "ARGS"' helmvalues/local.yaml

# Install the testing components and run the tests (default is nginx tests) - if you change the tests, you need to run both helm commands
microk8s helm3 upgrade --install --create-namespace --namespace lagoon --wait --timeout 30m lagoon-test lagoon/lagoon-test -f helmvalues/lagoon-test.yaml -f helmvalues/local.yaml
microk8s helm3 test lagoon-test --namespace lagoon

# Install the ExternalName services to access the odfe docker-compose cluster
microk8s kubectl apply -f ./helmvalues/opensearch-externalname.yaml

# Use these to get the admin passwords
docker run \
    -e JWTSECRET="$$(kubectl get secret -n lagoon lagoon-core-secrets -o jsonpath="{.data.JWTSECRET}" | base64 --decode)" \
    -e JWTAUDIENCE=api.dev \
    -e JWTUSER=localadmin \
    uselagoon/tests \
    python3 /ansible/tasks/api/admin_token.py
echo $(microk8s kubectl get secret -n lagoon lagoon-core-keycloak -o jsonpath="{.data.KEYCLOAK_ADMIN_PASSWORD}" | base64 --decode)
echo $(microk8s kubectl get secret -n lagoon lagoon-core-keycloak -o jsonpath="{.data.KEYCLOAK_LAGOON_ADMIN_PASSWORD}" | base64 --decode)

# Use these to delete CRDs from namespaces if they're holding up deletions
kubectl get LagoonTasks -A | awk '{printf "kubectl -n %s patch LagoonTasks %s -p \047{\"metadata\":{\"finalizers\":null}}\047 --type=merge\n", $1, $2}' | bash
kubectl get LagoonBuilds -A | awk '{printf "kubectl -n %s patch LagoonBuilds %s -p \047{\"metadata\":{\"finalizers\":null}}\047 --type=merge\n", $1, $2}' | bash
kubectl get HostMigrations -A | awk '{printf "kubectl -n %s patch HostMigrations %s -p \047{\"metadata\":{\"finalizers\":null}}\047 --type=merge\n", $1, $2}' | bash
kubectl get MariaDBConsumer -A | awk '{printf "kubectl -n %s patch MariaDBConsumer %s -p \047{\"metadata\":{\"finalizers\":null}}\047 --type=merge\n", $1, $2}' | bash
kubectl get MariaDBProvider -A | awk '{printf "kubectl -n %s patch MariaDBProvider %s -p \047{\"metadata\":{\"finalizers\":null}}\047 --type=merge\n", $1, $2}' | bash
kubectl get MongoDBConsumer -A | awk '{printf "kubectl -n %s patch MongoDBConsumer %s -p \047{\"metadata\":{\"finalizers\":null}}\047 --type=merge\n", $1, $2}' | bash
kubectl get MongoDBProvider -A | awk '{printf "kubectl -n %s patch MongoDBProvider %s -p \047{\"metadata\":{\"finalizers\":null}}\047 --type=merge\n", $1, $2}' | bash
kubectl get PostgreSQLConsumer -A | awk '{printf "kubectl -n %s patch PostgreSQLConsumer %s -p \047{\"metadata\":{\"finalizers\":null}}\047 --type=merge\n", $1, $2}' | bash
kubectl get PostgreSQLProvider -A | awk '{printf "kubectl -n %s patch PostgreSQLProvider %s -p \047{\"metadata\":{\"finalizers\":null}}\047 --type=merge\n", $1, $2}' | bash

# Use build-and-push from the root dir to wrap around make build and push the resulting image up to the harbor
./helmvalues/build-and-push.sh kubectl-build-deploy-dind

# Lagoon Logging
docker-compose -f local-dev/odfe-docker-compose.yml -p odfe up -d
microk8s helm3 upgrade --install --create-namespace --namespace lagoon-logs-concentrator --wait --timeout 15m lagoon-logs-concentrator lagoon/lagoon-logs-concentrator --values ./local-dev/lagoon-logs-concentrator.values.yaml
microk8s helm3 upgrade --install --create-namespace --namespace lagoon-logging --wait --timeout 15m lagoon-logging lagoon/lagoon-logging --values ./local-dev/lagoon-logging.values.yaml

# microk8s

# Install microk8s and enable addons
sudo snap install microk8s --classic --channel=1.20/stable
microk8s enable dns helm3 metrics-server storage

# get the IP for the microk8s node
microk8s kubectl get nodes -o custom-columns=IP:.status.addresses

# Use this IP to add the config to the TOML file - instructions at https://microk8s.io/docs/registry-private
# Update and copy these sections from the bottom of microk8s-containerd-template.toml to your local configuration - note that indentation matters!
# [plugins."io.containerd.grpc.v1.cri".registry.mirrors ...
# [plugins."io.containerd.grpc.v1.cri".registry.configs ...
sudo microk8s stop && sudo microk8s start

# Replace storageclass with bulk and standard storageclasses - you don't need the nfs-server-provisioner helm chart on microk8s
microk8s kubectl apply -f helmvalues/microk8s-storageclass.yaml

Rest of it should be pretty straightforward.