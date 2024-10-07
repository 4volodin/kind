#!/bin/bash

scope=openid
client_id=
client_secret=
username=
password=
oidc_url=https://keycloak/realms/truedev/protocol/openid-connect/token
realm_url=https://keycloak/realms/truedev

### Generate Authentication token

json_data=`curl -k -d "grant_type=password" -d "scope=${scope}" -d "client_id=${client_id}" -d "client_secret=${client_secret}" -d "username=${username}" -d "password=${password}" ${oidc_url}`

id_token=`echo $json_data | jq '.id_token' | tr -d '"'`
refresh_token=`echo $json_data | jq '.refresh_token' | tr -d '"'`
access_token=`echo $json_data | jq '.access_token' | tr -d '"'`

### Print tokens

echo "ID_TOKEN=$id_token"; echo
echo "REFRESH_TOKEN=$refresh_token"; echo
echo "ACCESS_TOKEN=$access_token"; echo

### Introspect the id token

token=`curl -k --user "${client_id}:${client_secret}" -d "token=${id_token}" ${oidc_url}/introspect`
token_details=`echo $token | jq .`
echo $token_details

### Update kubectl config

kubectl config set-credentials ${username} \
    "--auth-provider=oidc" \
    "--auth-provider-arg=idp-issuer-url=${realm_url}" \
    "--auth-provider-arg=client-id=${client_id}" \
    "--auth-provider-arg=client-secret=${client_secret}" \
    "--auth-provider-arg=refresh-token=${refresh_token}" \
    "--auth-provider-arg=id-token=${id_token}"

### Create new context

kubectl config set-context ${username} --cluster=kubernetes --user=${username}

### Validate access with new context

kubectl --context=${username} get pods
