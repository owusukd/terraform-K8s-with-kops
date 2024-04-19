# terraform-K8s-with-kops

In this project, I used terraform to provision an instance for kops. 
I set up the kops instance for creating K8s cluster, which I used to spin a Kubernetes cluster on AWS.
After the creation of the cluster, I deployed a multi-tier Java docker application which make use of memcache, rabbitmq, nginx, and mysql database containers.

Java Source code by Imran Teli.

## Prerequisite 
- Create Route53 domain for the cluster
- Create S3 bucket to store your cluster state
- You must have AWS account, if not create one

## Generate ssh-key and upload to aws IAM user
```
ssh-keygen
```

## Install aws-cli
```
sudo apt update
sudo apt install awscli -y
aws configure
```

## Install kubectl and kops
### Installing kubectl 
```
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
```

Make it executable and move it to user local bin
```
chmod +x ./kubectl
sudo mv ./kubectl /usr/local/bin
kubectl version --output=yaml
```

### Install kops
```
curl -LO https://github.com/kubernetes/kops/releases/download/$(curl -s \
https://api.github.com/repos/kubernetes/kops/releases/latest | grep tag_name \
| cut -d '"' -f 4)/kops-linux-amd64
```

Make it executable and move it to user local bin kops
```
chmod +x kops-linux-amd64
sudo mv kops-linux-amd64 /usr/local/bin/kops
kops version
```

## Check if Route53 domain is resolved
```
nslookup -type=ns your_domain_name_here
```

## Create cluster configuration yaml file
Using the domain name as the cluster name
```
export CLOUD="aws"
export KOPS_STATE_STORE="s3://your_s3_bucket_name_here"
export ZONES="us-east-1a,us-east-1b,us-east-1c"
export NODE_COUNT="3"
export MASTER_COUNT="3"
export NODE_SIZE="t3.small"
export MASTER_SIZE="t3.small"
export NODE_VOL_SIZE="8"
export MASTER_VOL_SIZE="8"
export DOMAIN_NAME="your_domain_name_here"
export VOL_ZONE="us-east-1a"

kops create cluster $DOMAIN_NAME \
    --cloud $CLOUD \
    --zones $ZONES \
    --control-plane-zones $ZONES \
    --node-count $NODE_COUNT \
    --master-count $MASTER_COUNT \
    --node-size $NODE_SIZE \
    --master-size $MASTER_SIZE \
    --node-volume-size $NODE_VOL_SIZE \
    --master-volume-size $MASTER_VOL_SIZE \
    --dns-zone $DOMAIN_NAME
```
## Create K8s Cluster with kops
### Get the exported yaml file
```
kops get all $DOMAIN_NAME -o yaml > $DOMAIN_NAME.yaml
```
### Create cluster
```
kops create -f $DOMAIN_NAME.yaml
kops create secret --name $DOMAIN_NAME sshpublickey admin -i path_to_the_ssh_pub_key_you_created_here
```
### Update, Validate, set Rolling Update for the Cluster
```
kops update cluster $DOMAIN_NAME --yes --admin
kops validate cluster $DOMAIN_NAME --wait 10m
kops rolling-update cluster $DOMAIN_NAME --yes --cloudonly
```

## Update the cluster
To update the cluster with changes to the cluster configuration files run the following, replacing *$DOMAIN_NAME.yaml* with the updated one.
```
kops replace -f $DOMAIN_NAME.yaml
kops update cluster $DOMAIN_NAME --yes --admin
kops rolling-update cluster $DOMAIN_NAME --yes --cloudonly
```

## Creating EBS volume for our DB pod
- Create EBS volume for the DB pod and tag it with the same name as K8s cluster
- Note the 'volume ID' for the EBS volume created

```
aws ec2 create-volume \
    --availability-zone $VOL_ZONE \
    --size 3 \
    --volume-type gp2 \
    --tag-specifications "ResourceType=volume,Tags=[{Key=KubernetesCluster,Value=$DOMAIN_NAME}]" \
    > volumeInfo.txt

awk '/VolumeId/ {print}' volumeInfo.txt | awk -F: '{print $2}' | sed 's|[ ","]||g' > volumeID.txt
cat volumeID.txt
```

## Create node labels 
Get nodes and save node ID
```
kubectl get nodes > nodes.txt
awk '/node/ {print $1}' nodes.txt > node.txt 
```

Describe nodes to fine which is in VOL_ZONE and label them with same name as VOL_ZONE
Create a file label_node.sh with content below
```
cat <<EOF>> label_node.sh
#!/bin/bash
if [ -f ./node.txt ]; then
    for node_id in $(cat node.txt)
    do
        zone=`kubectl describe node $node_id | grep $VOL_ZONE | awk '/ProviderID/ {print $0}' | awk -F: '{print $3}'`
        if [ ! -z "$zone" ]
        then
            kubectl label nodes $node_id zone=$VOL_ZONE
            echo $node_id >> nodeInVOL_ZONE.txt
        else
            echo "$node_id not in $VOL_ZONE"
        fi
    done
else
    echo "File doesn't exist!"  
fi 
EOF
```
Run the script **label_node.sh**
```
chmod +x ./label_node.sh
sh ./label_node.sh

kubectl get nodes --show-labels
```

## Deploying pods
Clone repo with yaml files
```
git clone git@github.com:owusukd/vprofile-project.git 
cd vprofile-project && git checkout kod-kube-app
cd K8s
```

Apply secret
```
kubectl create -f vprofileapp-secret.yaml
kubectl get secret
kubectl describe secret 
```
Deploy the rest of configuration files
```
kubectl create -f .
kubectl get deploy
kubectl get pod
```

## Get load balancer endpoint and copy it
```
kubectl get svc vprofileapp-service
```

## Clean up
We are done with the project so let us clean up.
Delete the cluster
```
kops delete cluster $DOMAIN_NAME --yes
```
Delete the EBS volume
```
vol_id=`cat volumeID.txt`
aws delete-volume \
    --volume-id $vol_id
```
