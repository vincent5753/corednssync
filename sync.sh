#!/bin/bash

# Check if parameter is empty
# svcname
if [ -z "$svcname" ]
then
    echo "[ERROR][INIT] svcname not found, exiting..."
    exit
else
    echo "[INFO][INIT] Got svcname: $svcname"
fi
# svcnamespace
if [ -z "$svcnamespace" ]
then
    echo "[ERROR][INIT] svcnamespace not found, exiting..."
    exit
else
    echo "[INFO][INIT] Got svcnamespace: $svcnamespace"
fi
echo "[INFO][INIT] svcname: $svcname   svcnamespace: $svcnamespace"

# Get SA TOKEN
TOKEN=$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)

# Set API Request Interval
if [ -z "$interval" ]
then
    echo "[INFO][INIT] Interval variable not found, setting to default interval."
    interval=10
else
    echo "[INFO][INIT] Interval: $interval seconds"
fi

# Define D4 YAML Template
cat <<EOF > YAML.Part1
apiVersion: v1
kind: ConfigMap
metadata:
  name: coredns
  namespace: kube-system
data:
  Corefile: |
    .:53 {
        errors
        health {
           lameduck 5s
        }
        ready
EOF

cat <<EOF > YAML.Part3
        kubernetes cluster.local in-addr.arpa ip6.arpa {
           pods insecure
           fallthrough in-addr.arpa ip6.arpa
           ttl 5
        }
        prometheus :9153
        forward . /etc/resolv.conf
        cache 30
        loop
        reload
        loadbalance
    }
EOF

GetINGCount (){
  curl -s --insecure -H "Authorization: Bearer $TOKEN" https://kubernetes/apis/extensions/v1beta1/namespaces/default/ingresses | jq -c '.items | length'
}

Gen_YAML_JSON (){
  for i in $(seq 1 $INGCount)
  do
    current=$(($i - 1 ))
    # Get IngName
    IngName=$(curl -s --insecure -H "Authorization: Bearer $TOKEN" https://kubernetes/apis/extensions/v1beta1/namespaces/default/ingresses | jq -r -c ".items["$current"].metadata.name")
    # Get IngHost
    IngHost=$(curl -s --insecure -H "Authorization: Bearer $TOKEN" https://kubernetes/apis/extensions/v1beta1/namespaces/default/ingresses | jq -c ".items["$current"].spec.rules[0].host" | sed 's/"//g')
    echo "[INFO][STATUS] IngName:$IngName   IngHost:$IngHost"
    echo "        rewrite name $IngHost $svcname.$svcnamespace.svc.cluster.local" >> YAML.Part2
  done
  cat YAML.Part1 YAML.Part2 YAML.Part3 > Apply.yaml

  echo ""
  echo "<<<<< YAML FILE>>>>>"
  cat Apply.yaml
  echo ""
  echo "<<<<< JSON FILE>>>>>"
  yq -o=json Apply.yaml > Apply.json
  cat Apply.json

  rm YAML.Part2
}

Update_CM(){
curl -X PATCH https://kubernetes:443/api/v1/namespaces/kube-system/configmaps/coredns  -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/strategic-merge-patch+json" --data-binary @Apply.json --cacert /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
}

while true
do
  echo "[INFO][TIME] $(date '+%y/%m/%d %X')"

  INGCount=$(GetINGCount)

  if [ "$INGCount" = "0" ]
  then
    echo "[INFO][STATUS] No Ingress found!"
  else
    echo "[INFO][STATUS] Found $INGCount Ingress Services!"
    Gen_YAML_JSON
    Update_CM
    echo ""
    echo "[INFO][STATUS] ConfigMap Updated!"
  fi

  sleep $interval
done
