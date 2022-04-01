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

if [ -z "$NODE_IP" ]
then
    echo "[ERROR][INIT] NODE_IP not found, exiting..."
    exit
else
    echo "[INFO][INIT] Got NODE_IP: $NODE_IP"
fi

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

# Chk if is on Master Node or not
GetNodeCount (){
  curl -s --insecure -H "Authorization: Bearer $TOKEN" https://kubernetes/api/v1/nodes | jq -c '.items | length'
}

NodeCount=$(GetNodeCount)
echo "[INIT][INFO] Find $NodeCount Nodes!"

for i in $(seq 1 $NodeCount)
do
  current=$(($i - 1 ))
  # Get NodeName
  NodeName=$(curl -s --insecure -H "Authorization: Bearer $TOKEN" https://kubernetes/api/v1/nodes | jq -r -c ".items["$current"].metadata.name")
  # Check if current node is Master
  if [ "$NodeName" = "$MY_NODE_NAME" ]
  then
    result=$(curl -s --insecure -H "Authorization: Bearer $TOKEN" https://kubernetes/api/v1/nodes | jq -c ".items["$current"].metadata.labels.\"node-role.kubernetes.io/master\"")
    if [ "$result" != "null" ]
    then
      echo "[INIT][INFO] Running on Master Node!"
      echo "[INIT][INFO] NodeName: $NodeName"
      IsMaster=1
    else
      echo "[INIT][INFO] Running on Worker Node."
      echo "[INIT][INFO] NodeName: $NodeName"
      IsMaster=0
    fi
  else
    :
  fi
done

# Define D4 YAML Template
cat <<EOL > YAML.Part1
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
EOL

cat <<EOL > YAML.Part3
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
EOL

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

Update_Hosts(){
  cat /sync/hosts | grep -v "Domain Add by DS" > /sync/hosts.1
  rm /sync/hosts.2
  for i in $(seq 1 $INGCount)
  do
    current=$(($i - 1 ))
    # Get IngName
    IngName=$(curl -s --insecure -H "Authorization: Bearer $TOKEN" https://kubernetes/apis/extensions/v1beta1/namespaces/default/ingresses | jq -r -c ".items["$current"].metadata.name")
    # Get IngHost
    IngHost=$(curl -s --insecure -H "Authorization: Bearer $TOKEN" https://kubernetes/apis/extensions/v1beta1/namespaces/default/ingresses | jq -c ".items["$current"].spec.rules[0].host" | sed 's/"//g')
    echo "[INFO][STATUS] IngName:$IngName   IngHost:$IngHost"
    echo "$NODE_IP    $IngHost    #Domain Add by DS" >> /sync/hosts.2
  done
  cat /sync/hosts.1 /sync/hosts.2 > /sync/hosts
}

GetNodeCount (){
  curl -s --insecure -H "Authorization: Bearer $TOKEN" https://kubernetes/api/v1/nodes | jq -c '.items | length'
}

NodeCount=$(GetNodeCount)
echo $NodeCount

for i in $(seq 1 $NodeCount)
do
  current=$(($i - 1 ))
  # Get IngName
  NodeName=$(curl -s --insecure -H "Authorization: Bearer $TOKEN" https://kubernetes/api/v1/nodes | jq -r -c ".items["$current"].metadata.name")
  # Is Master
  curl -s --insecure -H "Authorization: Bearer $TOKEN" https://kubernetes/api/v1/nodes | jq -c ".items["$current"].metadata.labels.\"kubernetes.io/hostname\"" | sed 's/"//g'
  echo "[INFO][STATUS] NodeName:$NodeName"
  if [ "$NodeName" = "$MY_NODE_NAME" ]
  then
    # chk if is master or not
    result=$(curl -s --insecure -H "Authorization: Bearer $TOKEN" https://kubernetes/api/v1/nodes | jq -c ".items[0].metadata.labels.\"node-role.kubernetes.io/master\"")
    if [ "$result" != "null" ]
    then
      #echo "I'm Master Node."
      IsMaster=1
    else
      #echo "I'm Worker Node."
      IsMaster=0
    fi
  else
    echo "Strings are not equal."
  fi
done

while true
do
  echo "[INFO][TIME] $(date '+%y/%m/%d %X')"

  INGCount=$(GetINGCount)

  if [ "$INGCount" = "0" ]
  then
    echo "[INFO][STATUS] No Ingress found!"
  else
    echo "[INFO][STATUS] Found $INGCount Ingress Services!"

    if [ "$IsMaster" = "1" ]
    then
      echo "[INFO][STATUS] Running on Master Node, update both ComfigMap and hosts."
      Gen_YAML_JSON
      Update_CM
      echo ""
      echo "[INFO][STATUS] ConfigMap Updated!"
      Update_Hosts
      echo ""
      echo "[INFO][STATUS] Hosts Updated!"
    else
      echo "[INFO][STATUS] Running on Worker Node, update hosts only."
      Update_Hosts
      echo ""
      echo "[INFO][STATUS] Hosts Updated!"

    fi
  fi
  sleep $interval
done
