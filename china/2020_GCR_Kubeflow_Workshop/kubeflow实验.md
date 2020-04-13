# kubeflow-1.0-on-aws

在AWS上构建kubeflow1.01。基本上只是遵循[这里](https://www.kubeflow.org/docs/aws/deploy/)，但是在docker容器上执行命令。

# 准备Docker映像容器

[请](https://github.com/asahi0301/eks-toolkit)参考[此处](https://github.com/asahi0301/eks-toolkit)并从docker容器开始。还必须设置凭据

# 关于地区

因为kubeflow的示例代码在俄勒冈州区域中，所以在这里也选择了俄勒冈州区域（us-west-2），但是我认为如果可以使用EKS，它将在任何地方都可以使用

# 设定参数

执行以下命令来设置环境变量。

```
export AWS_REGION=us-west-2
export AWS_DEFAULT_REGION=${AWS_REGION}
export AWS_CLUSTER_NAME=kubeflow
export BASE_DIR=/src

export KF_NAME=${AWS_CLUSTER_NAME}
export KF_DIR=${BASE_DIR}/${KF_NAME}
export CONFIG_FILE=${KF_DIR}/kfctl_aws.yaml
```

# 使用eksctl创建EKS集群

通过执行以下操作创建EKS集群：大约需要15分钟，因此请耐心等待。

```
eksctl create cluster --name = $ {AWS_CLUSTER_NAME} --nodes = 6 --managed --alb-ingress-access --region = $ {AWS_REGION}
```

如果由于任何原因失败，请进入AWS管理屏幕，查看CloudFromation堆栈并找出原因。常见原因包括EIP或VPC的最大数量或不正确的凭据（权限不足）。解决问题之后，执行以下命令，然后

```
eksctl delete cluster kubeflow
```

然后，**删除失败的CloudFromation堆栈，**然后重新执行eksctl create cluster ~~命令。

# 安装kubeflow（简单版）

使用cognito设置身份验证，使用IAM Pod角色等，但此处完全不使用它们并执行以下命令来安装kubeflow

```
＃安装kfctl 
wget https://github.com/kubeflow/kfctl/releases/download/v1.0.1/kfctl_v1.0.1-0-gf3edb9b_linux.tar.gz
tar zxvf kfctl_v1.0.1-0-gf3edb9b_linux.tar.gz
mv kfctl /usr/local/bin/
＃ aws配置文件上的kubeflow（congnito版本和非congnito版本，此处不使用cognito版本（不进行身份验证））
export CONFIG_URI="https://raw.githubusercontent.com/kubeflow/manifests/v1.0-branch/kfdef/kfctl_aws.v1.0.1.yaml"
export KF_NAME=${AWS_CLUSTER_NAME}

mkdir -p ${BASE_DIR}
export KF_DIR=${BASE_DIR}/${KF_NAME}

mkdir -p ${KF_DIR}
cd ${KF_DIR}

在aws配置文件 
wget -O kfctl_aws.yaml $CONFIG_URI
export CONFIG_FILE=${KF_DIR}/kfctl_aws.yaml

NodeInstanceRole=`aws iam list-roles \
    | jq -r ".Roles[] \
    | select(.RoleName \
    | startswith(\"eksctl-$AWS_CLUSTER_NAME\") and contains(\"NodeInstanceRole\")) \
    .RoleName"`

sed -i'.bak' -e 's/kubeflow-aws/'"$AWS_CLUSTER_NAME"'/' ${CONFIG_FILE}
sed -i -e 's/eksctl-kubeflow-nodegroup-ng-a2-NodeInstanceRole-xxxxxxx/'"$NodeInstanceRole"'/' ${CONFIG_FILE}
sed -i -e 's/us-west-2/'"$AWS_REGION"'/' ${CONFIG_FILE}


＃部署kubeflow（需要几分钟的时间才能完成）
cd  $ {KF_DIR} 
kfctl apply -V -f $ {CONFIG_FILE}
```

# 确认书

## 资源清单

所有资源是否正常工作？如果没有，请稍后再检查。

```
kubectl -n kubeflow get all
```

如果一段时间后仍不正常，请通过查看日志进行故障排除

# 检查入口

ELB的DNS名称显示在“地址”部分中，因此请记下

```
kubectl get ingress -n istio-system
NAME            HOSTS   ADDRESS                                                                  PORTS   AGE
istio-ingress   *       xxxxxx-istiosystem-istio-2af2-xxxxx.us-west-2.elb.amazonaws.com   80      5m46s
```

# 访问Kubeflow用户界面

只要输入您从网络浏览器写下的ELB的DNS名称，您就可以连接到Kubeflow UI并开始播放。

# 注意事项

默认值为无身份验证，HTTP和IP限制。我认为不需要任何重要信息，因此我认为HTTP很好。让我们保持它。

# 删掉

使用以下命令将其删除

```
cd  $ {KF_DIR} 
kfctl delete -f $ {CONFIG_FILE} 
eksctl delete cluster kubeflow
```

如果eksclt delete失败，请手动删除CloudFormation堆栈。将策略手动添加到IAM角色或更改安全组甚至可能失败，因此您可能需要手动还原或删除它。如果您忘记删除它，则需要付费，因此您可能需要在AWS管理控制台中确认删除，以防万一。

# 故障排除

## 入口不显示ELB DNS名称

具体来说，ADDRESS部分不会显示如下。查看AWS控制台，创建了ALB本身，但未创建目标组。

```
kubectl get ingress -n istio-system 
名称主机地址端口年龄
istio-ingress    *                   80      
```

### 怎么办

删除/应用与ALB相关的Yaml部分。

```
cd  $ {KF_DIR} / kustomize / istio- 
inress kubectl kustomize 。 | kubectl delete -f- 
kubectl kustomize 。 | kubectl apply -f-
```

现在您可以看到ALB DNS名称