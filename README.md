kind create cluster --name devbox --config kind-config.yml

kubectl oidc-login setup \
  --oidc-issuer-url=ISSUER_URL \
  --oidc-client-id=devbox-kind \
  --oidc-client-secret=YOUR_CLIENT_SECRET


## Ingress

```
helm install ingress-nginx ingress-nginx/ingress-nginx --version=4.11.2 --namespace ingress-nginx --create-namespace --values ingress-nginx-values.yaml

```

## Certs

```
helm install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --version v1.14.0 \
  --set installCRDs=true
```

```
kubectl create secret tls mkcert-ca-key-pair \
--key "$(mkcert -CAROOT)"/rootCA-key.pem \
--cert "$(mkcert -CAROOT)"/rootCA.pem -n cert-manager
```

```
kubectl apply -f - <<EOF
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: mkcert-issuer
  namespace: cert-manager
spec:
  ca:
    secretName: mkcert-ca-key-pair
EOF
```

## Istio

helm repo add istio https://istio-release.storage.googleapis.com/charts
helm repo update

kubectl create namespace istio-system

helm install istio-base istio/base -n istio-system --set defaultRevision=default
helm install istiod istio/istiod -n istio-system --wait
helm ls -n istio-system


---

## App

cd app
docker build -t sample-app:1.0 .
kind load docker-image sample-app:1.0 --name devbox
k apply -f k8s

kubectl label namespace default istio-injection=enabled --overwrite
kubectl get namespace -L istio-injection

kubectl delete <pod name>

---

## Monitoring

helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

```
kubectl apply -f - <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: monitoring
  labels:
    istio-injection: enabled
EOF
```

helm install loki grafana/loki-stack -n monitoring -f loki-config.yml

kubectl get secret loki-grafana -n monitoring -o jsonpath={.data.admin-user} | base64 -d; echo
kubectl get secret loki-grafana -n monitoring -o jsonpath={.data.admin-password} | base64 -d; echo

4 Golden Signals
RED
nodeexporter 1860
kubestatemetrics2 21742


## Postgres

kubectl get storageclasses

helm repo add cnpg https://cloudnative-pg.github.io/charts

```
kubectl apply -f - <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: pg
  labels:
    istio-injection: enabled
EOF
```
helm install cnpg cnpg/cloudnative-pg -n pg

kubectl apply -f db-user-config.yml
kubectl apply -f db-config.yml

## Gitlab runners

kubectl create namespace gitlab
helm install --namespace gitlab gitlab-runner gitlab/gitlab-runner \
  --set rbac.create=true \
  --set runners.privileged=true \
  --set gitlabUrl=https://gitlab.com/ \
  --set runnerRegistrationToken=<token from project settings/CI/CD/Runners>

## Vault
helm repo add hashicorp https://helm.releases.hashicorp.com
kubectl create namespace vault
helm install vault hashicorp/vault -f vault-config.yml -n vault

kubectl exec -it vault-0 -n vault -- sh
vault status
vault operator init -n 1 -t 1

kubectl exec -it vault-1 -n vault -- sh
vault operator raft join http://vault-active:8200
vault operator unseal <unseal key from earlier command>
exit

kubectl exec -it vault-2 -n vault -- sh
vault operator raft join http://vault-active:8200
vault operator unseal <unseal key from earlier command>
exit

postgresql://postgres:super-secret@db-cluster-rw.pg:5432/postgres

vault secrets enable -path=database database
vault write database/config/my-secure-db \
    plugin_name=postgresql-database-plugin \
    allowed_roles="myrole" \
    connection_url="postgresql://{{username}}:{{password}}@db-cluster-rw.pg:5432/postgres?sslmode=disable" \
    username="postgres" \
    password="super-secret"

vault write database/roles/myrole \
    db_name="my-secure-db" \
    creation_statements="CREATE ROLE \"{{name}}\" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}'; \
        GRANT SELECT ON ALL TABLES IN SCHEMA public TO \"{{name}}\";" \
    default_ttl="1h" \
    max_ttl="24h"

пробуем получить креды
vault read database/creds/myrole
пробуем под ними авторизоваться
psql -d postgres -W -U v-root-db1-role-RocdQtHY9MIESxcLjrj3-1661411587
смотрим юзеров
\du

## External Secret Operator
helm repo add external-secrets https://charts.external-secrets.io
kubectl create namespace eso
helm install external-secrets external-secrets/external-secrets -n eso
## Kafka

kubectl create namespace kafka
kubectl apply -f kafka-deployment.yml
kubectl get pods -n kafka

kubectl logs kafka-0 -n kafka | grep STARTED
kubectl logs kafka-1 -n kafka | grep STARTED
kubectl logs kafka-2 -n kafka | grep STARTED

kubectl exec -it kafka-0 -n kafka -- bash
kafka-topics.sh --create --topic my-topic --bootstrap-server kafka-svc:9092
kafka-topics.sh --list --topic my-topic --bootstrap-server kafka-svc:9092

kubectl exec -it kafka-1 -n kafka -- bash
kafka-console-producer.sh  --bootstrap-server kafka-svc:9092 --topic my-topic
in parallel
kubectl exec -it kafka-2 -n kafka -- bash
kafka-console-consumer.sh --bootstrap-server kafka-svc:9092 --topic my-topic
