# 步骤4 配置ALB Ingress Controller

4. 1使用ALB Ingress Controller

> 4.2.1 创建ALB Ingress Controller所需要的IAM policy , EKS OIDC provider, service account

```bash
#创建odic provider
eksctl utils associate-iam-oidc-provider --region=${AWS_DEFAULT_REGION} --cluster=${CLUSTER_NAME}  --approve

```

> 4.2.1.2 创建所需要的IAM policy
> 
>https://raw.githubusercontent.com/kubernetes-sigs/aws-alb-ingress-controller/v1.1.8/docs/examples/iam-policy.json
```bash
aws iam create-policy --policy-name ALBIngressControllerIAMPolicy \
  --policy-document file://./alb-ingress-controller/iam-policy.json 

# 记录返回的Plociy ARN
POLICY_NAME=$(aws iam list-policies --query 'Policies[?PolicyName==`ALBIngressControllerIAMPolicy`].Arn' --output text )

```

>4.2.1.3 请使用上述返回的policy ARN创建service account

```bash

eksctl create iamserviceaccount \
       --cluster=${CLUSTER_NAME} \
       --namespace=kube-system \
       --name=alb-ingress-controller \
       --attach-policy-arn=${POLICY_NAME} \
       --override-existing-serviceaccounts \
       --approve

参考输出
[ℹ]  eksctl version 0.24.0-rc.0
[ℹ]  using region us-west-2
[ℹ]  1 iamserviceaccount (kube-system/alb-ingress-controller) was included (based on the include/exclude rules)
[!]  metadata of serviceaccounts that exist in Kubernetes will be updated, as --override-existing-serviceaccounts was set
[ℹ]  1 task: { 2 sequential sub-tasks: { create IAM role for serviceaccount "kube-system/alb-ingress-controller", create serviceaccount "kube-system/alb-ingress-controller" } }
[ℹ]  building iamserviceaccount stack "eksctl-ekslab-addon-iamserviceaccount-kube-system-alb-ingress-controller"
[ℹ]  deploying stack "eksctl-ekslab-addon-iamserviceaccount-kube-system-alb-ingress-controller"
[ℹ]  created serviceaccount "kube-system/alb-ingress-controller"
```



4.3 部署 ALB Ingress Controller

 相关文件已经resource/alb-ingress-controller目录下，并且修改好，下面步骤为你全新Step-by-Step操作

 >4.3.1 创建 ALB Ingress Controller 所需要的RBAC

 ```bash
 kubectl apply -f rbac-role.yaml
 
 ```

>4.2.2 创建 ALB Ingress Controller 配置文件

 修改alb-ingress-controller.yaml 以下配置，参考示例 resource/alb-ingress-controller/alb-ingress-controller.yaml
(eksctl 自动创建的 vpc 默认为 eksctl-<集群名字>-cluster/VPC)

  ```bash
 #查找EKS集群使用的vpc
 aws ec2 describe-vpcs --filters "Name=tag:Name,Values=eksctl-${CLUSTER_NAME}-cluster/VPC" --query "Vpcs[0].VpcId" --out text
 
  
  #修改alb-ingress-controller.yaml以下内容
  - --cluster-name=<步骤2 创建的集群名字>
  - --aws-vpc-id=<eksctl 创建的vpc-id>  
  
  #中国区 1.1.7 waf,wafv2修复方式
  #如果你使用alb-ingress-controller 1.1.8 需要禁用waf,wafv2
  - --feature-gates=waf=false,wafv2=false

             
 #使用修改好的yaml文件部署ALB Ingress Controller
 kubectl apply -f alb-ingress-controller.yaml

 
 #确认ALB Ingress Controller是否工作
 kubectl logs -n kube-system $(kubectl get po -n kube-system | egrep -o alb-ingress[a-zA-Z0-9-]+)

 #参考输出
-------------------------------------------------------------------------------
AWS ALB Ingress controller
  Release:    v1.1.8
  Build:      git-ec387ad1
  Repository: https://github.com/kubernetes-sigs/aws-alb-ingress-controller.git
-------------------------------------------------------------------------------
  ```


 4.4 使用ALB Ingress   
>4.4.1 为nginx service创建ingress

```bash
cd resource/alb-ingress-controller
kubectl apply -f nginx-alb-ingress.yaml
```

>4.4.2 验证

```bash
ALB=$(kubectl get ingress -o json | jq -r '.items[0].status.loadBalancer.ingress[].hostname')
curl -v $ALB

# 如果遇到问题，请查看日志
kubectl logs -n kube-system $(kubectl get po -n kube-system | egrep -o alb-ingress[a-zA-Z0-9-]+)
```

> 4.4.3 清理
```bash
kubectl delete -f nginx-alb-ingress.yaml
```

4.5 使用ALB Ingress，部署2048 game 

```bash

kubectl create namespace 2048-game
kubectl apply -f 2048/

#获取访问地址，在浏览器中访问2048游戏
kubectl get all -n 2048-game

#清除资源
kubectl delete -f 2048/
kubectl delete namespace 2048-game
```

