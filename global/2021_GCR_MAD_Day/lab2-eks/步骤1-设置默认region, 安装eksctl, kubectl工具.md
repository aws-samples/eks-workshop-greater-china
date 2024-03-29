# 步骤2: 设置默认region, 安装eksctl, kubectl工具

我们将在步骤1创建的AWS Cloud9 环境里面安装eksctl,kubectl。进入Cloud9编辑器环境后，在终端中输入以下命令,进行安装。

```bash
#设置默认region
#export AWS_DEFAULT_REGION=us-east-1
#echo "export AWS_DEFAULT_REGION=${AWS_DEFAULT_REGION}" >> ~/.bashrc
export KUBECTL_VERSION=v1.25.0 #推荐使用v1.25.0或者1.26

#eksctl 版本 > v0.164.0
curl -L "https://github.com/weaveworks/eksctl/releases/download/v0.164.0/eksctl_$(uname -s)_amd64.tar.gz"    | tar xz -C .
sudo mv ./eksctl /usr/local/bin

#kubectl v1.25.0
#curl -LO --silent https://storage.googleapis.com/kubernetes-release/release/`curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt`/bin/linux/amd64/kubectl
curl -LO --silent https://storage.googleapis.com/kubernetes-release/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl
chmod 775 ./kubectl
sudo mv ./kubectl /usr/local/bin

#安装jq
sudo yum install -y jq

```

>检查工具的版本 eksctl (版本>=0.160.0), kubectl(version <=1.24)

```bash
eksctl version
kubectl version
```

> 下载所需要的配置文件到本地

```bash
curl -OL https://github.com/aws-samples/eks-workshop-greater-china/raw/master/global/2020_GCR_SZ_ContainerDay/resources.tgz
tar -zxf resources.tgz
```

