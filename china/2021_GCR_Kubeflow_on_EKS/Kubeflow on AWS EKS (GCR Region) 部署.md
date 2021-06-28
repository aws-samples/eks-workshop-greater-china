## Kubeflow on AWS EKS (GCR Region)

### 前置条件

* 安装命令行工具

```bash
#使用pip安装aws cli ,其他方式请阅读参考文档
pip install awscli
#配置权限
aws configure

#kubectl v1.20.0
#macbook
curl -o kubectl https://amazon-eks.s3.us-west-2.amazonaws.com/1.20.4/2021-04-12/bin/darwin/amd64/kubectl

#linux
curl -o kubectl https://amazon-eks.s3.us-west-2.amazonaws.com/1.20.4/2021-04-12/bin/linux/amd64/kubectl


#kfctl v1.2.0-0-gbc038f9
#macbook
curl -OL https://github.com/kubeflow/kfctl/releases/download/v1.2.0/kfctl_v1.2.0-0-gbc038f9_darwin.tar.gz

#linux 
curl -OL https://github.com/kubeflow/kfctl/releases/download/v1.2.0/kfctl_v1.2.0-0-gbc038f9_linux.tar.gz
 
tar -zxvf kfctl_v1.2.0-0-gbc038f9_darwin.tar.gz

#aws-iam-authenticator

#macbook
curl -o aws-iam-authenticator https://amazon-eks.s3.us-west-2.amazonaws.com/1.18.9/2020-11-02/bin/darwin/amd64/aws-iam-authenticator

#linux
curl -o aws-iam-authenticator https://amazon-eks.s3.us-west-2.amazonaws.com/1.18.9/2020-11-02/bin/linux/amd64/aws-iam-authenticator

#jq 
#macbook
brew install jq
#linux 
#CentOS, Amaon Linux
yum inistall jq
#ubuntu
apt-get install jq

```



### 1. Create AWS EKS Cluster

使用标准模板创建eks cluster,  集群名字 kubeflow-workshop,模版会创建一个CPU工作组eks-prod-cpu-ng-1(m5.2xlarge 3台), GPU工作组 eks-prod-gpu-ng-1(g4dn.xlarge 1台)

```bash
#步骤1 修改kubeflow-workshop-eks.yaml中的publicKeyName(必须)
#publicKeyName: <aws keypair name> 

#步骤2 创建集群(也可以通过其他方式创建EKS集群)
eksctl create cluster -f ./resource/kubeflow-workshop-eks.yaml

#步骤3 检查EKS节点状态是否就绪
kubectl get node 

```

### 2. 配置NWCD 镜像 mutating-webhook

具体参考https://github.com/nwcdlabs/container-mirror, 主要作用就是自动转换gcr.io到048912060910.dkr.ecr.cn-northwest-1.amazonaws.com.cn/gcr, kubeflow 1.2所需要的全部镜像已经推送到NWCD的镜像仓库

```bash
#步骤1 安装 mutating-webhook
kubectl apply -f resource/mutating-webhook.yaml

#步骤2 验证是否生效
kubectl run test --image=k8s.gcr.io/coredns:1.3.1
kubectl get pod test -o=jsonpath='{.spec.containers[0].image}'
#如果显示 048912060910.dkr.ecr.cn-northwest-1.amazonaws.com.cn/gcr/google_containers/coredns:1.3.1 表示mutating-webhook 工作正常
#删除测试pod
kubectl delete pod test


```

### 3. 安装kubeflow 1.2

请使用resource目录下的manifests-1.2.0.tar.gz

```bash
export CLUSTER_NAME=kubeflow-workshop
mkdir ${CLUSTER_NAME}
cd ${CLUSTER_NAME}

#步骤1 生成配置文件 kfctl_aws.v1.2.0.yaml 
sed -e "s/{FULL_PATH}/$(echo $PWD | sed 's_/_\\/_g')/g" kfctl_aws.v1.2.0.yaml.tpl > kfctl_aws.v1.2.0.yaml


#步骤2 部署kubeflow v1.2.0, 如果中间有问题请删除当前目录下面.cache目录
kfctl apply -V -f kfctl_aws.v1.2.0.yaml


#步骤3 验证kubeflow是否部署成功,如果pod都是runing就表示成功运行了
kubectl get all -n kubeflow


#步骤4 更新ALB ingress controller 需要的权限和配置
#4.1 创建Policy
export AWS_REGION=cn-northwest-1
export CLUSTER_NAME=kubeflow-workshop

aws iam create-policy --policy-name ALBIngressControllerIAMPolicy \
  --policy-document file://./resource/ingress-iam-policy.json --region 
  ${AWS_REGION}

POLICY_NAME=$(aws iam list-policies --query 'Policies[?PolicyName==`ALBIngressControllerIAMPolicy`].Arn' --output text --region ${AWS_REGION})

#4.2. 创建EKS OIDC provider
eksctl utils  associate-iam-oidc-provider  --cluster=${CLUSTER_NAME} --approve

#4.3 关联service account 
eksctl create iamserviceaccount \
       --cluster=${CLUSTER_NAME} \
       --namespace=kubeflow \
       --name=alb-ingress-controller \
       --attach-policy-arn=${POLICY_NAME} \
       --override-existing-serviceaccounts \
       --approve
       

#4.3 并重启ALB Ingress Controller
kubectl rollout restart deployment alb-ingress-controller -n kubeflow

#5. 获取kubeflow URL
kubectl get ingress -n istio-system



```



### 4. 配置多用户

```bash
# 静态用户文件 dex-config.yaml
# 密码需要使用https://passwordhashing.com/BCrypt 生成
# 这里的默认密码是abcd1234

# 修改后dex-config.yaml提交
cd resource
kubectl create configmap dex --from-file=config.yaml=dex-config.yaml -n auth --dry-run -oyaml | kubectl apply -f -

# 重启dex应用
kubectl rollout restart deployment dex -n auth


#创建完后使用admin@kubeflow.com/abcd1234, app1@kubeflow.com/abcd1234, 登陆会自动创建namespace
```

### 5. 配置用户配额

```bash
#修改app1.yaml
kubectl apply -f app1.yaml
```



### 6. 配置用户权限(可选)

* IAM 创建policy 限制s3访问

  ```bash
  export AWS_REGION=cn-northwest-1
  export CLUSTER_NAME=kubeflow-workshop
  
  aws iam create-policy --policy-name s3-kubeflow-on-eks-app1 \
    --policy-document file://./alb-ingress-controller/s3-kubeflow-on-eks-app1.json --region ${AWS_REGION}
    
  ```
  
* 使用eksctl管理service account

  ```bash
  
  #请重复为app1的service account 设置IAM role
  POLICY_NAME=$(aws iam list-policies --query 'Policies[?PolicyName==`s3-kubeflow-on-eks-app1`].Arn' --output text --region ${AWS_REGION})
  
  eksctl create iamserviceaccount \
         --cluster=${CLUSTER_NAME} \
         --namespace=app1 \
         --name=default-editor \
         --attach-policy-arn=${POLICY_NAME} \
         --override-existing-serviceaccounts \
         --approve
  ```

  


### 问题列表

* dex 配置ldap 

  参考文档:

  * openldap 使用https://docs.bitnami.com/tutorials/create-openldap-server-kubernetes/#step-1-create-and-install-the-openldap-server-on-your-cluster)
  * dex with ldap https://github.com/dexidp/dex/blob/master/examples/ldap/

  

  ```bash
  #添加secret密码
  kubectl create secret generic openldap --from-literal=adminpassword=adminpassword --from-literal=users=user01 --from-literal=passwords=password01
  
  #部署openldap
  kubectl apply -f openldap.yaml -n auth
  
  #
  kubectl exec -ti $(kubectl get pod -n auth | grep openldap | awk '{print $1}') -n auth -- bash 
  
  ldapdelete -x -H ldap://localhost:1389  -D "cn=admin,dc=example,dc=org" -w adminpassword  "cn=user01,ou=users,dc=example,dc=org"
  
  ldapadd -x -H ldap://localhost:1389 -D "cn=admin,dc=example,dc=org" -w adminpassword -f users.ldif
  
  
  ldapsearch  -x -H ldap://localhost:1389  -b dc=example,dc=org -D "cn=admin,dc=example,dc=org" -w adminpassword
  
  ldappasswd -x -H ldap://localhost:1389 -D "cn=admin,dc=example,dc=org" -w adminpassword  "cn=user01,ou=users,dc=example,dc=org"
  
  
  #分别设置user01-user04密码
  ldappasswd -x -H ldap://localhost:1389 -D "cn=admin,dc=example,dc=org" -w admin  "cn=user01,ou=users,dc=example,dc=org"
  user01@example.org/IhlXjrOo
  user02@example.org/5MZ4rMKr
  user03@example.org/oiCK1oWB
  user04@example.org/HlUqcbwC
  
  ```



  

