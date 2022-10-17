
# These steps assume you have tools like helm, kubectl etc all installed.

# Find the IP address for the network - replace this in all the helmvalues files (may be 172.17.0.2 or similar)

    If it's KinD:
    docker network create kind || true && docker run --rm --network kind alpine ip -o addr show eth0 | sed -nE 's/.* ([0-9.]{7,})\/.*/\1/p'

    If it's Microk8s:
    (see section at bottom)

# e.g. sample replace command - use the output from above in the second half of the sed command below
(Linux) find ./helmvalues -type f | xargs sed -i "s/172.17.0.2/{your_ip}/g"
(Mac) find ./helmvalues -type f -exec sed -i '' s/172.17.0.2/{your_ip}/g {} +


    # Create the cluster - KinD
    kind create cluster --wait=120s --config=helmvalues/kind-config.yaml

    # Create the cluster - Microk8s
    (see section at bottom)

# Optional Set up kubectx and kubens (or similar) - if you have these tools
kubectx kind-lagoon-local && kubens default

# Install/Update all necessary Helm repositories
microk8s helm3 plugin install https://github.com/aslafy-z/helm-git
microk8s helm3 repo add harbor https://helm.goharbor.io
microk8s helm3 repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
microk8s helm3 repo add stable https://charts.helm.sh/stable
microk8s helm3 repo add bitnami https://charts.bitnami.com/bitnami
microk8s helm3 repo add minio https://helm.min.io/
microk8s helm3 repo add amazeeio https://amazeeio.github.io/charts/
microk8s helm3 repo add lagoon https://uselagoon.github.io/lagoon-charts/
microk8s helm3 repo update

# Install the cluster prerequisites (currently version pinned)
microk8s helm upgrade --install --create-namespace --namespace ingress-nginx --wait --timeout 30m --version 4.2.1 ingress-nginx ingress-nginx/ingress-nginx -f ${PWD}/helmvalues/ingress-nginx.yaml
microk8s helm upgrade --install --create-namespace --namespace registry --wait --timeout 30m --version 1.9.3 registry harbor/harbor -f ${PWD}/helmvalues/registry.yaml
microk8s helm upgrade --install --create-namespace --namespace nfs-server-provisioner --wait --timeout 30m --version 1.1.3 nfs-server-provisioner stable/nfs-server-provisioner -f ${PWD}/helmvalues/nfs-server-provisioner.yaml
microk8s helm upgrade --install --create-namespace --namespace minio --wait --timeout 30m --version 11.8.1 minio bitnami/minio -f ${PWD}/helmvalues/minio.yaml

# Install the DBaaS databases as required
microk8s helm upgrade --install --create-namespace --namespace mariadb --wait --timeout 30m --version=11.1.7 mariadb bitnami/mariadb -f ${PWD}/helmvalues/dbaas.yaml
microk8s helm upgrade --install --create-namespace --namespace postgresql --wait --timeout 30m --version=11.7.1 postgresql bitnami/postgresql -f ${PWD}/helmvalues/dbaas.yaml
microk8s helm upgrade --install --create-namespace --namespace mongodb --wait --timeout 30m --version=11.2.0 mongodb bitnami/mongodb -f ${PWD}/helmvalues/dbaas.yaml

# Install the Lagoon components
microk8s helm3 upgrade --install --create-namespace --namespace lagoon --wait --timeout 30m lagoon-core lagoon/lagoon-core -f ${PWD}/helmvalues/lagoon-core.yaml
microk8s helm3 upgrade --install --create-namespace --namespace lagoon --wait --timeout 30m lagoon-build-deploy lagoon/lagoon-build-deploy -f ${PWD}/helmvalues/lagoon-build-deploy.yaml
microk8s helm3 upgrade --install --create-namespace --namespace lagoon --wait --timeout 30m lagoon-remote lagoon/lagoon-remote -f ${PWD}/helmvalues/lagoon-remote.yaml

# Need the correct token installed into the tests charts to allow it to talk to core
microk8s kubectl -n lagoon get secret -o json | jq -r '.items[] | select(.metadata.name | match("lagoon-build-deploy-token")) | .data.token | @base64d' | xargs -I ARGS yq -i eval '.token = "ARGS"' helmvalues/lagoon-test.yaml

# Install the testing components and run the tests (default is nginx tests) - if you change the tests, you need to run both helm commands
microk8s helm3 upgrade --install --create-namespace --namespace lagoon --wait --timeout 30m lagoon-test lagoon/lagoon-test -f ${PWD}/helmvalues/lagoon-test.yaml
microk8s helm3 test lagoon-test --namespace lagoon

# Use build-and-push from the root dir to wrap around make build and push the resulting image up to the harbor
./helmvalues/build-and-push.sh kubectl-build-deploy-dind

# Use these to get the admin passwords
docker run \
    -e JWTSECRET="$$(kubectl get secret -n lagoon lagoon-core-secrets -o jsonpath="{.data.JWTSECRET}" | base64 --decode)" \
    -e JWTAUDIENCE=api.dev \
    -e JWTUSER=localadmin \
    uselagoon/tests \
    python3 /ansible/tasks/api/admin_token.py
# Use these to create LoadBalancers for the api-db and ssh services - works on k3s, not sure about microk8s
kubectl patch service -n lagoon lagoon-core-api-db  -p '{"spec":{"type":"LoadBalancer"}}'
kubectl get service -n lagoon lagoon-core-api-db -o jsonpath='{.spec.ports[].nodePort}{"\n"}'
kubectl get secret -n lagoon lagoon-core-api-db -o jsonpath="{.data.API_DB_PASSWORD}" | base64 --decode
kubectl patch service -n lagoon lagoon-core-ssh  -p '{"spec":{"type":"LoadBalancer"}}'
kubectl get service -n lagoon lagoon-core-ssh -o jsonpath='{.spec.ports[].nodePort}{"\n"}'

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


# Install any additional tooling
microk8s helm3 upgrade --install --create-namespace --namespace gitea --wait --timeout 30m gitea gitea-charts/gitea -f ${PWD}/helmvalues/gitea.yaml

# To install a component from the local lagoon-charts (e.g lagoon-core)
microk8s helm3 upgrade --install --create-namespace --namespace lagoon --wait --timeout 30m lagoon-core ../lagoon-charts/charts/lagoon-core -f ${PWD}/helmvalues/lagoon-core.yaml

# Lagoon Logging

docker-compose -f local-dev/odfe-docker-compose.yml -p odfe up -d
#k8up

microk8s helm upgrade --install --create-namespace --namespace k8up --version 1.1.0 -f ${PWD}/helmvalues/k8up-values.yaml k8up appuio/k8up
microk8s kubectl apply -f https://github.com/vshn/k8up/releases/download/v1.1.0/k8up-crd.yaml

# microk8s

# Install microk8s and enable addons
sudo snap install microk8s --classic --channel=1.23/stable
microk8s enable dns helm3 metrics-server storage

# get the IP for the microk8s node
microk8s kubectl get nodes -o custom-columns=IP:.status.addresses

# Use this IP to add the config to the TOML file - instructions at https://microk8s.io/docs/registry-private
# Update and copy these sections from the bottom of microk8s-containerd-template.toml to your local configuration - note that indentation matters!
# [plugins."io.containerd.grpc.v1.cri".registry.mirrors ...
# [plugins."io.containerd.grpc.v1.cri".registry.configs ...
sudo microk8s stop && sudo microk8s start
(Linux) find  /var/snap/microk8s/current/args -type f | xargs sed -i "s/172.17.0.2/{your_ip}/g"

# Replace storageclass with bulk and standard storageclasses - you don't need the nfs-server-provisioner helm chart on microk8s
microk8s kubectl apply -f ${PWD}/helmvalues/microk8s-storageclass.yaml

multipass mount ./helmvalues microk8s-vm:/home/ubuntu/helmvalues


Rest of it should be pretty straightforward.
