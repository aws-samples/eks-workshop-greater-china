## Kubeflow on AWS EKS (GCR Region)

### 前置条件

* 安装命令行工具(笔者使用的是mac,请将下面)

```bash
#安装aws cli ,我才用的是pip安装,其他方式请阅读参考文档
pip install awscli
#配置权限
aws configure

#kubectl v1.18.9
#macbook
curl -o kubectl https://amazon-eks.s3.us-west-2.amazonaws.com/1.18.9/2020-11-02/bin/darwin/amd64/kubectl

#linux
curl -o kubectl https://amazon-eks.s3.us-west-2.amazonaws.com/1.18.9/2020-11-02/bin/linux/amd64/kubectl


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

```bash
#使用标准模板创建eks cluster,  集群名字 VOLVO-KUBEFLOW-EKS
#模版会创建一个CPU工作组eks-prod-cpu-ng-1, GPU工作组 eks-prod-gpu-ng-1

#步骤1 修改kubeflow-cluster-config.yaml中的publicKeyName
#publicKeyName: <aws keypair name> 

#步骤2 创建集群(也可以通过其他方式创建EKS集群)
eksctl create cluster -f kubeflow-cluster-config.yaml

#步骤3 检查EKS节点状态是否就绪
kubectl get node 

```

### 2. 配置NWCD 镜像 mutating-webhook

```bash
#具体参考https://github.com/nwcdlabs/container-mirror
#主要作用就是自动转换gcr.io到048912060910.dkr.ecr.cn-northwest-1.amazonaws.com.cn/gcr

#步骤1 安装 mutating-webhook
kubectl apply -f mutating-webhook

#验证是否生效
kubectl run --generator=run-pod/v1 test --image=k8s.gcr.io/coredns:1.3.1
kubectl get pod test -o=jsonpath='{.spec.containers[0].image}'
#如果显示 048912060910.dkr.ecr.cn-northwest-1.amazonaws.com.cn/gcr/google_containers/coredns:1.3.1 表示mutating-webhook 工作正常
#删除测试pod
kubectl delete pod test


```

### 3. 安装kubeflow 1.2

manifests-1.2.0.tar.gz所有gcr.io,quay.io会自动步骤2的mutating-webhook修改使用NWCD的新镜像地址,另外manifests里面docker.io/xxx的image 已经修改为direct.to/xxx, 例如docker.io/busybox:latest 会修改为direct.to/busybox:latest 

```bash
export CLUSTER_NAME=VOLVO-KUBEFLOW-EKS
mkdir ${CLUSTER_NAME}
cd ${CLUSTER_NAME}

#步骤1 修改kfctl_aws.v1.2.0.yaml 参数
#将kfctl_aws.v1.2.0.yaml,manifests-1.2.0.tar.gz 复制到该目录
#修改kfctl_aws.v1.2.0.yaml以下内容
#uri: https://github.com/kubeflow/manifests/archive/v1.2.0.tar.gz
#url: file:/<绝对路径>/manifests-1.2.0.tar.gz

#步骤2 部署kubeflow
kfctl apply -V -f kfctl_aws.v1.2.0.yaml

#验证kubeflow是否部署成功,如果pod都是runing就表示成功运行了
#kubectl get all -n kubeflow

#验证ingerss是否生效,如果DNS没有显示的话,需要修复ALB ingress controller 后有说明
kubectl get ingress -n istio-system

```



### 4. 配置多用户

```bash
# 静态用户文件 dex-config.yaml
# 密码需要使用https://passwordhashing.com/BCrypt 生成

# 修改后dex-config.yaml提交
kubectl create configmap dex --from-file=config.yaml=dex-config-oldp.yaml -n auth --dry-run -oyaml | kubectl apply -f -

# 重启dex应用
kubectl rollout restart deployment dex -n auth

# 如果要使用openldap, dex-config-ldap.yaml 请注意需要实现配置好openldap服务
# 修改好
kubectl create configmap dex --from-file=config.yaml=dex-config-ldap.yaml -n auth --dry-run -oyaml | kubectl apply -f -

#创建完后使用app1@volvo.com/abcd1234, app2@volvo.com/abcd1234, 登陆会自动创建namespace
```

### 5. 配置用户配额

```bash
#修改app1.yaml
kubectl apply -f app1.yaml
```



### 6. 配置用户权限

* IAM 创建policy 限制s3访问

  ```bash
  export AWS_REGION=cn-northwest-1
  export CLUSTER_NAME=<eksctl config里面集群的名字>
  
  aws iam create-policy --policy-name s3-kubeflow-on-eks-app1 \
    --policy-document file://./alb-ingress-controller/s3-kubeflow-on-eks-app1.json --region ${AWS_REGION}
    
    
  aws iam create-policy --policy-name s3-kubeflow-on-eks-app2 \
    --policy-document file://./alb-ingress-controller/s3-kubeflow-on-eks-app2.json --region ${AWS_REGION}
    
  ```
  
* 使用eksctl管理service account

  ```bash
  
  #请重复为app1,app2 service account 设置IAM role
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

* ingress ALB没有创建

  ```bash
  
  1. 检查ALB使用的service account 按照以下步骤添加IAM Role
  
  export AWS_REGION=cn-northwest-1
  export CLUSTER_NAME=<eksctl config里面集群的名字>
  
  aws iam create-policy --policy-name ALBIngressControllerIAMPolicy \
    --policy-document file://./alb-ingress-controller/ingress-iam-policy.json --region 
    ${AWS_REGION}
  
  # 记录返回的Plociy ARN
  POLICY_NAME=$(aws iam list-policies --query 'Policies[?PolicyName==`ALBIngressControllerIAMPolicy`].Arn' --output text --region ${AWS_REGION})
  
  
  
  #创建OIDC provider
  eksctl utils  associate-iam-oidc-provider  --cluster=${CLUSTER_NAME} --approve
  
  #关联service account
  eksctl create iamserviceaccount \
         --cluster=${CLUSTER_NAME} \
         --namespace=kubeflow \
         --name=alb-ingress-controller \
         --attach-policy-arn=${POLICY_NAME} \
         --override-existing-serviceaccounts \
         --approve
         
   
  ```

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



  


