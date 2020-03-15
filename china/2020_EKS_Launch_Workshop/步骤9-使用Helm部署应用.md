# 步骤9 使用Helm部署应用
Helm帮助您管理Kubernetes应用程序。在原来Kubernetes项目中都是基于yaml文件来进行部署发布微服务化应用的，会分成很多个组件来部署，每个组件可能对应一个deployment.yaml,一个service.yaml,一个Ingress.yaml等文件，还可能存在各种依赖关系。Helm旨在解决

（1）基于yaml配置的集中存放 
（2）基于项目的打包 
（3）组件间的依赖
（4）部署过程中的前置和后置任务
（5）更新、回滚和测试部署

Helm由以下几个组件组成：
1. Helm Charts: 一个 Helm 包，包含了运行一个应用所需要的镜像、依赖和资源定义等，还可能包含Kubernetes集群中的服务定义
2. Helm Release: 运行中的一个Chart实例。在同一个Kubernetes集群上，一个 Chart 可以安装很多次。每次安装都会创建一个新的 release
3. Helm Repository：用于发布和存储 Chart 的仓库。
4. Helm Config：创建发布对象的chart的配置信息

常见的文件结构：
```bash
wordpress/
  Chart.yaml          # A YAML file containing information about the chart
  LICENSE             # OPTIONAL: A plain text file containing the license for the chart
  README.md           # OPTIONAL: A human-readable README file
  requirements.yaml   # OPTIONAL: A YAML file listing dependencies for the chart
  values.yaml         # The default configuration values for this chart
  charts/             # A directory containing any charts upon which this chart depends.
  templates/          # A directory of templates that, when combined with values,
                      # will generate valid Kubernetes manifest files.
  templates/NOTES.txt # OPTIONAL: A plain text file containing short usage notes
```

[官方文档](https://helm.sh/docs/)

> 本节目的
1. 安装配置Helm
2. 使用Helm部署样例微服务

9.1 Install Helm 

```bash
# 通用
curl -sSL https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | bash
# MacOS
brew install helm
# 验证安装
helm version --short

# 设置 stable repository
## 删除默认的源
helm repo remove stable
## 增加新的国内镜像源, 你可以选择其他偏好的国内镜像
helm repo add stable https://burdenbear.github.io/kube-charts-mirror/
helm search repo wordpress

# 配置 Bash completion
# linux
helm completion bash >> ~/.bash_completion
. /etc/profile.d/bash_completion.sh
. ~/.bash_completion
source <(helm completion bash)
# Mac
brew install bash-completion
brew tap homebrew/completions
# Edit ~/.bash_profile or ~/.bashrc
source <(kubectl completion bash)
source <(helm completion bash)
if [ -f $(brew --prefix)/etc/bash_completion ]; then 
. $(brew --prefix)/etc/bash_completion
fi
```

9.2 使用Helm部署 nginx
```bash
helm repo update
helm search repo nginx
# add nginx standalone web server
helm repo add bitnami https://charts.bitnami.com/bitnami
helm search repo bitnami/nginx
# install
helm install gcr-eks-webserver bitnami/nginx

# verify the helm chart deployed, nginx deployment available and pod on running
helm list
kubectl describe deployment gcr-eks-webserver
kubectl get pods -l app.kubernetes.io/name=nginx

# Get the NGINX URL:
#Watch the status with
kubectl get svc -n default -w gcr-eks-webserver-nginx
SERVICE_IP=$(kubectl get svc --namespace default gcr-eks-webserver-nginx --template "{{ range (index .status.loadBalancer.ingress 0) }}{{.}}{{ end }}")
echo "NGINX URL: http://${SERVICE_IP}/"
curl ${SERVICE_IP}

# cleanup
helm list
helm uninstall gcr-eks-webserver
kubectl get pods -l app.kubernetes.io/name=nginx
kubectl get svc -n default -o wide gcr-eks-webserver-nginx
```

9.3 使用Helm部署样例微服务

学习如何用Helm部署[步骤4](步骤4-部署微服务以及配置ALBIngressController)的微服务 
```bash
cd ~/temp
# create a chart
helm create eks-helm-demo
ls eks-helm-demo/
Chart.yaml	charts		templates	values.yaml

# create our own file
rm -rf eks-helm-demo/templates/
rm eks-helm-demo/Chart.yaml
rm eks-helm-demo/values.yaml
cat <<EoF > eks-helm-demo/Chart.yaml
apiVersion: v2
name: eks-helm-demo
description: A Helm chart for EKS Workshop Microservices application
version: 0.1.0
appVersion: 1.0
EoF

#create subfolders for each template type
mkdir -p eks-helm-demo/templates/deployment
mkdir -p eks-helm-demo/templates/service

# Copy and rename frontend manifests
cp ecsdemo-frontend/kubernetes/deployment.yaml eks-helm-demo/templates/deployment/frontend.yaml
cp ecsdemo-frontend/kubernetes/service.yaml eks-helm-demo/templates/service/frontend.yaml

# Copy and rename crystal manifests
cp ecsdemo-crystal/kubernetes/deployment.yaml eks-helm-demo/templates/deployment/crystal.yaml
cp ecsdemo-crystal/kubernetes/service.yaml eks-helm-demo/templates/service/crystal.yaml

# Copy and rename nodejs manifests
cp ecsdemo-nodejs/kubernetes/deployment.yaml eks-helm-demo/templates/deployment/nodejs.yaml
cp ecsdemo-nodejs/kubernetes/service.yaml eks-helm-demo/templates/service/nodejs.yaml

# Replace hard-coded values with template directives
spec:
  replicas: 1
#replace with the following:
replicas: {{ .Values.replicas }}

spec.template.spec.containers.image
#replace with 
frontend.yaml	- image: {{ .Values.frontend.image }}:{{ .Values.version }}
crystal.yaml	- image: {{ .Values.crystal.image }}:{{ .Values.version }}
nodejs.yaml	- image: {{ .Values.nodejs.image }}:{{ .Values.version }}

eks-helm-demo/templates/deployment/frontend.yaml
eks-helm-demo/templates/deployment/crystal.yaml
eks-helm-demo/templates/deployment/nodejs.yaml

cat <<EoF > eks-helm-demo/values.yaml
# Default values for eksdemo.
# This is a YAML-formatted file.
# Declare variables to be passed into your templates.

# Release-wide Values
replicas: 3
version: 'latest'

# Service Specific Values
nodejs:
  image: brentley/ecsdemo-nodejs
crystal:
  image: brentley/ecsdemo-crystal
frontend:
  image: brentley/ecsdemo-frontend
EoF

# Deployment chart
## dry-run
helm install --debug --dry-run workshop eks-helm-demo
## install chart
helm install workshop eks-helm-demo
NAME: workshop
LAST DEPLOYED: Tue Mar 10 15:04:18 2020
NAMESPACE: default
STATUS: deployed
REVISION: 1
TEST SUITE: None

# Verify
helm list
NAME               READY   UP-TO-DATE   AVAILABLE   AGE     CONTAINERS         IMAGES                             SELECTOR
ecsdemo-crystal    3/3     3            3           11m     ecsdemo-crystal    brentley/ecsdemo-crystal:latest    app=ecsdemo-crystal
ecsdemo-frontend   3/3     3            3           11m     ecsdemo-frontend   brentley/ecsdemo-frontend:latest   app=ecsdemo-frontend
ecsdemo-nodejs     3/3     3            3           11m     ecsdemo-nodejs     brentley/ecsdemo-nodejs:latest     app=ecsdemo-nodejs

kubectl get pods -l app=ecsdemo-crystal
kubectl get pods -l app=ecsdemo-nodejs
kubectl get pods -l app=ecsdemo-frontend
kubectl get svc ecsdemo-frontend -o jsonpath="{.status.loadBalancer.ingress[*].hostname}"; echo

```

9.4 ROLLING Upgrade / Back
```bash
# Update the demo application chart with a breaking change
# Edit values.yaml and modify the image name under nodejs.image to brentley/ecsdemo-nodejs-non-existing. 
# This image does not exist, so this will break our deployment.

# rolling upgrade
helm upgrade workshop eks-helm-demo
Release "workshop" has been upgraded. Happy Helming!
NAME: workshop
LAST DEPLOYED: Tue Mar 10 15:22:20 2020
NAMESPACE: default
STATUS: deployed
REVISION: 2
TEST SUITE: None

# Check the rolling upgrade
# ecsdemo-nodejs should shown ImagePullBackOff error
kubectl get pods -l app=ecsdemo-nodejs
NAME                              READY   STATUS         RESTARTS   AGE
ecsdemo-nodejs-6fdf964f5f-27569   1/1     Running        0          18m
ecsdemo-nodejs-6fdf964f5f-ngw54   1/1     Running        0          18m
ecsdemo-nodejs-6fdf964f5f-rr9m6   1/1     Running        0          18m
ecsdemo-nodejs-7c6575b56c-brfpv   0/1     ErrImagePull   0          5s

# rolling back
# Run helm status workshop to verify the LAST DEPLOYED timestamp.
helm status workshop
helm history workshop
REVISION	UPDATED                 	STATUS    	CHART              	APP VERSION	DESCRIPTION
1       	Tue Mar 10 15:04:18 2020	superseded	eks-helm-demo-0.1.0	1          	Install complete
2       	Tue Mar 10 15:22:20 2020	deployed  	eks-helm-demo-0.1.0	1          	Upgrade complete

# rollback to the 1st revision
helm rollback workshop 1
Rollback was a success! Happy Helming!
# Check status
kubectl get pods -l app=ecsdemo-nodejs
NAME                              READY   STATUS    RESTARTS   AGE
ecsdemo-nodejs-6fdf964f5f-27569   1/1     Running   0          20m
ecsdemo-nodejs-6fdf964f5f-ngw54   1/1     Running   0          20m
ecsdemo-nodejs-6fdf964f5f-rr9m6   1/1     Running   0          20m

# Clean up
helm uninstall workshop
kubectl get pods -l app=ecsdemo-nodejs
kubectl get pods -l app=ecsdemo-crystal
kubectl get pods -l app=ecsdemo-frontend
kubectl get svc ecsdemo-frontend -o wide
```
