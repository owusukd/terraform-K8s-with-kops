# terraform-K8s-with-kops

In this project, I used terraform to provision an instance for kops. 
I set up the kops instance for creating K8s cluster, which I used to spin a Kubernetes cluster on AWS.
After the creation of the cluster, I deployed a multi-tier Java docker application which make use of memcache, rabbitmq, nginx, and mysql database containers.

Java Source code by Imran Teli.

## Prerequisite 
Create Route53 domain for the cluster
Create S3 bucket to store your cluster state

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


