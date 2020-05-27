# 步骤15 灵活使用 eksctl 与 CDK 个性化创建 EKS 集群

### 演示环境使用 Cloud9，Mac 类似请参考官方文档

#### 创建 cloud9 EC2 堡垒机
1. 创建 EC2选 Marketplace 中的 Cloud9
2. 在浏览器中输入 http://实例公有IP:8181 ，并在弹出的窗口中输入 用户名： aws 密码： 实例ID（即上一个步骤中获取到的实例ID）
3. 给 EC2 附加拥有 `AdministratorAccess` Policy 的 IAM 角色
4. `aws sts get-caller-identity` 检查角色是否工作正常
5. `ssh-keygen -t rsa` 生成登录工作节点用的密钥对

* 使用 mac 的用户，请自己在环境中配置好 aws config 与 credential，并测试工作是否正常

#### 环境变量

```
export AWS_DEFAULT_REGION=cn-northwest-1
```

* 使用宁夏区域，需要使用其它区域的请执行修改环境变量

#### aws cli install
1. 检查版本 aws --version
2. Amazn Linux 2删除旧版本 aws-cli `sudo yum remove aws-cli`
3. 安装 CLI `python -m pip install awscli`
4. 为了 CDK 实验建议使用 python3，没有的话 python2也可以
5. 或升级 CLI `pip3 install --upgrade --user awscli`
6. 导出环境目录 `export PATH=$HOME/.local/bin:$PATH`

* 没有 pip 的可以使用 bundle 方式安装
```
curl "https://s3.amazonaws.com/aws-cli/awscli-bundle.zip" -o "awscli-bundle.zip"
unzip awscli-bundle.zip
sudo ./awscli-bundle/install -i /usr/local/aws -b /usr/local/bin/aws
```

### kubectl install
* Linux 安装: `sudo curl -o kubectl https://amazon-eks.s3.us-west-2.amazonaws.com/1.15.10/2020-02-22/bin/linux/amd64/kubectl`
* Mac 安装: `curl -o kubectl https://amazon-eks.s3.us-west-2.amazonaws.com/1.15.10/2020-02-22/bin/darwin/amd64/kubectl`
* 官方的 kubectl 也可以
```
sudo mv ./kubectl /usr/bin/kubectl && chmod 755 /usr/bin/kubectl`
source <(kubectl completion bash)
```

#### eksctl & aws-iam-authenticator install

* Linux 安装 eksctl
```
curl --silent --location "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp
sudo mv /tmp/eksctl /usr/bin
source <(eksctl completion bash)
```
* Mac 安装 eksctl
```
brew tap weaveworks/tap
brew install weaveworks/tap/eksctl
```

* `eksctl version` 检查版本 >= 0.15.0 否则不支持中国区

* Linux 安装 aws-iam-authenticator
```
sudo curl -o aws-iam-authenticator https://amazon-eks.s3.us-west-2.amazonaws.com/1.15.10/2020-02-22/bin/linux/amd64/aws-iam-authenticator && mv aws-iam-authenticator /usr/bin/aws-iam-authenticator && chmod a+x /usr/bin/aws-iam-authenticator
```
* Mac OS 的 homebrew 会作为依赖包自动安装 aws-iam-authenticator
#### cdk install

* 安装 node.js 12
```
curl -sL https://rpm.nodesource.com/setup_12.x | sudo -E bash -
sudo yum install -y nodejs
```
* Mac 安装 node.js
`brew install node`
1. 通过 npm 安装 cdk `npm i -g aws-cdk`
2. `cdk --version` 检查版本 >= 1.28.0

#### helm install

* Mac 安装: `brew install helm`
* Linux 安装
```
curl https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 > get_helm.sh
chmod 700 get_helm.sh
./get_helm.sh
```

### eksctl 创建集群

#### 基础一键创建

`eksctl create cluster --name=eksctl-quick-start --node-type t3.large --managed`

#### 通过 YAML 创建
* 该环境可以用于其它实验，使用1.15版本，创建 vpc 192.168.0.0/16网段覆盖3个可用区，同时拥有3个t3.large工作节点，并且附加有常用的 Policy

```
apiVersion: eksctl.io/v1alpha5
kind: ClusterConfig
metadata:
  name: eksctl-cluster-1
  region: cn-northwest-1
  version: "1.15"
vpc:
  cidr: "192.168.0.0/16"
  nat:
    gateway: HighlyAvailable

managedNodeGroups:
  - name: managed-ng-1
    instanceType: t3.large
    minSize: 1
    desiredCapacity: 3
    maxSize: 5
    availabilityZones: ["cn-northwest-1a", "cn-northwest-1b", "cn-northwest-1c"]
    ssh:
      allow: true
      publicKeyName: " your-pem-cn-northwest-1"
    iam:
      attachPolicyARNs: 
        - "arn:aws-cn:iam::aws:policy/AdministratorAccess"
        - "arn:aws-cn:iam::aws:policy/AmazonEKS_CNI_Policy"
        - "arn:aws-cn:iam::aws:policy/AmazonEKSWorkerNodePolicy"
        - "arn:aws-cn:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
      withAddonPolicies:
        imageBuilder: true
        autoScaler: true
```

#### 记录CloudFormation的 Stack name 和创建用的Role name

```
STACK_NAME=$(eksctl get nodegroup --cluster ${CLUSTER_NAME} -o json | jq -r '.[].StackName')
echo $STACK_NAME
ROLE_NAME=$(aws cloudformation describe-stack-resources --stack-name $STACK_NAME | jq -r '.StackResources[] | select(.ResourceType=="AWS::IAM::Role") | .PhysicalResourceId')
echo $ROLE_NAME
export ROLE_NAME=${ROLE_NAME}
export STACK_NAME=${STACK_NAME}
```

### 常用命令
1. 重置 kubeconfig `eksctl utils write-kubeconfig --cluster <clusterName>`
2. 工作节点组升级 `eksctl upgrade nodegroup --cluster <clusterName>`
3. 指定集群名称，reqion，工作节点数量和类型等信息 `eksctl create cluster --name=<clusterName> --region=cn-north-1 --nodes=2 --node-type=m5.large`
4. 使用 config-file 指定所有配置信息 `eksctl create nodegroup --config-file=config.yaml`
5. 更新 master 或对应的 nodegroup `eksctl upgrade cluster –name=<clusterName>`
6. 扩展集群 `eksctl scale nodegroup --cluster=<clusterName> --nodes=<desiredCount> --name=<nodegroupName>`
7. 了解更多命令用法 `eksctl --help`


### CDK install

#### 初始化环境（Python3.7，如使用 TypeScript 等语言请参考官方文档，步骤类似） 
* Linux 安装 Python3: `sudo yum install python3`
* Mac 安装 Python3: `brew install python3`
* 准备好一个熟悉的 IDE，VS Code 补全效果比较好
1. 初始化环境 `cdk init cdk-eks --language python`
2. 生成 virutalenv `python3 -m venv .env`
3. 进入 virtualenv `source .env/bin/activate`
4. 安装 requirements `pip install -r requirements.txt`
5. 安装 ckd 的 eks 库 `pip install aws-cdk.aws-eks`
6. 修改 app 模版代码
7. `cdk synth` 合成模版
8. `cdk bootstrap` 预制 cdk toolkit
9. `cdk deploy` 部署 stack
10. `cdk diff` 查看修改后cloudformation的差异
11. `cdk destory` 销毁 stack

#### 基础 quickstart 代码

```
        eks.Cluster(self, "cdk-eks-cluster-quickstart",
            default_capacity_instance=ec2.InstanceType("t3.large")
        )
```
#### 代码模版
* 编辑工程根目录中 app.py

```
#!/usr/bin/env python3
from aws_cdk import core
from cdk_app.cdk_app_stack import CdkAppStack

app = core.App()
CdkAppStack(app, "cdk-app", env = {'region': 'cn-northwest-1'}, eks_cluster_name = 'cdk-eks-cluster-1')
# 创建 Stack
app.synth()
# 合成 CloudFormation 模版
```

* 编辑工程中 cdk-eks 目录中的 *_stack.py

```
from aws_cdk import (
    core,
    aws_ec2 as ec2,
    aws_eks as eks,
    aws_iam as iam
)

class CdkAppStack(core.Stack):

    def __init__(self, scope: core.Construct, id: str, eks_cluster_name, **kwargs) -> None:
        super().__init__(scope, id, **kwargs)
        
        eks_vpc = ec2.Vpc(self, 'cdk-eks-vpc-1',
            cidr = "192.168.0.0/16",
            enable_dns_hostnames = True,
            enable_dns_support = True,
            nat_gateways = 2,
            subnet_configuration = [
                ec2.SubnetConfiguration(
                    name = "Public",
                    cidr_mask = 20,
                    subnet_type = ec2.SubnetType.PUBLIC
                ),
                ec2.SubnetConfiguration(
                    name = "Private",
                    cidr_mask = 20,
                    subnet_type = ec2.SubnetType.PRIVATE
                )]
        )
        # 创建工作节点 VPC
        vpc_tag = "kubernetes.io/cluster/" + eks_cluster_name
        core.Tag.add(eks_vpc, vpc_tag, "shared")
        for i in eks_vpc.select_subnets(subnet_type = ec2.SubnetType.PUBLIC).subnets:
            core.Tag.add(i, vpc_tag, "shared")
            core.Tag.add(i, "kubernetes.io/role/elb", "1")
        for i in eks_vpc.select_subnets(subnet_type = ec2.SubnetType.PRIVATE).subnets:
            core.Tag.add(i, vpc_tag, "shared")
            core.Tag.add(i, "kubernetes.io/role/internal-elb", "1")
        # 给 vpc subnet 打 tag，从而满足 kubernetes 的要求（如果使用 eksctl 会自动打 tag）
            
        cluster_admin = iam.Role(self, "AdminRole",
            assumed_by = iam.AccountRootPrincipal()
        )
        # 配置给创建的集群配 IRSA  

        cluster = eks.Cluster(self, "cdk-eks-cluster-1",
            cluster_name = eks_cluster_name,
            vpc = eks_vpc,
            vpc_subnets = [ec2.SubnetSelection(
                one_per_az = True,
                subnet_type = ec2.SubnetType.PUBLIC
            )],
            masters_role = cluster_admin,
            default_capacity = 0,
            default_capacity_instance = ec2.InstanceType("t3.large")
        )
        # 创建 eks 集群
        
        asg = cluster.add_capacity("manged-ng-1",
            min_capacity = 1,
            max_capacity = 5,
            desired_capacity = 3,
            instance_type = ec2.InstanceType("t3.large"),
            key_name = "your-pem-cn-northwest-1"
        )
        # 添加工作节点，key_name 修改成希望使用的 SSH PEM 私钥
        asg.role.add_managed_policy(
            policy = iam.ManagedPolicy.from_aws_managed_policy_name("AdministratorAccess")
        )
        # 为托管的工作节点附加管理员 IAM 角色
        
        # The code that defines your stack goes here
```

* 通过 Helm Chart 方式安装 nginx-ingress，可以在创建完 eks 集群后，附加在上一段代码后面运行，作为后续操作安装。

```
        cluster.add_chart("NginxIngress",
            chart="nginx-ingress",
            repository="https://helm.nginx.com/stable",
            namespace="kube-system"
        )
```



 