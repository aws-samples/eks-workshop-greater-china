# 步骤14 在 EKS 集群上部署 Istio 服务网格

服务网格用来描述组成应用程序的微服务网络以及它们之间的交互。随着服务网格的规模和复杂性不断的增长，它将会变得越来越难以理解和管理。它的需求包括服务发现、负载均衡、故障恢复、度量和监控等。服务网格通常还有更复杂的运维需求，比如 A/B 测试、金丝雀发布、速率限制、访问控制和端到端认证。
Istio 是一个完全开源的服务网格，作为透明的一层接入到现有的分布式应用程序里。它也是一个平台，拥有可以集成任何日志、遥测和策略系统的 API 接口。 Istio 允许您连接、保护、控制和观察服务。
在本节中，我们将学习使用 Istio 来构建服务网格，控制服务之间的流量和 API 调用过程。
[官方文档](https://istio.io/)

> 本节目的
1. 使用 Istio 在 Kubernetes 集群中实施服务网格，实现服务之间的流量管理


14.1 部署 Istio

> 下载 istioctl
```bash
# 下载 istioctl，本 Workshop 使用 1.5.1
# https://github.com/istio/istio/releases/
mkdir istio && cd istio
echo 'export ISTIO_VERSION="1.5.1"' >> ~/.bash_profile
source ~/.bash_profile

# 下载并安装 istioctl -option 1
curl -L https://istio.io/downloadIstio | sh -
sudo cp -v bin/istioctl /usr/local/bin/

# 下载并安装 istioctl -option 2
# 也可以下载对应的安装包解压安装，此处以 osx 为例 https://github.com/istio/istio/releases/
wget https://github.com/istio/istio/releases/download/1.5.1/istioctl-1.5.1-osx.tar.gz | tar xzvf
chmod +x ./istioctl && mv istioctl ~/bin/

# 验证
istioctl version --remote=false
```


> 部署 istio
```bash
# 部署 istio
# 使用 --set profile=demo 部署所有模块
istioctl manifest apply --set profile=demo
- Applying manifest for component Base...
✔ Finished applying manifest for component Base.
- Applying manifest for component Pilot...
✔ Finished applying manifest for component Pilot.
  Waiting for resources to become ready...
  Waiting for resources to become ready...
  Waiting for resources to become ready...
- Applying manifest for component IngressGateways...
- Applying manifest for component EgressGateways...
- Applying manifest for component AddonComponents...
✔ Finished applying manifest for component EgressGateways.
✔ Finished applying manifest for component IngressGateways.
✔ Finished applying manifest for component AddonComponents.

✔ Installation complete

# 验证，等待 istio pod 全部处于 READY 状态
kubectl -n istio-system get svc
kubectl -n istio-system get pods
grafana-556b649566-2gb5d                1/1     Running   0          59m
istio-egressgateway-65949b978b-vbmg4    1/1     Running   0          59m
istio-ingressgateway-7c76987989-2g9vn   1/1     Running   0          59m
istio-tracing-7cf5f46848-s5pcb          1/1     Running   0          59m
istiod-5bb7dddbd8-n84hc                 1/1     Running   0          59m
kiali-6d54b8ccbc-v8zgb                  1/1     Running   0          59m
prometheus-b47d8c58c-bvmr5              2/2     Running   0          59m
```

14.2 部署 Bookinfo 示例应用
>14.2.1 创建示例应用

```bash
# 创建 bookinfo 命名空间
kubectl create namespace bookinfo

# 启用 Istio sidecar 自动注入
kubectl label namespace bookinfo istio-injection=enabled
kubectl get ns bookinfo --show-labels
NAME       STATUS   AGE    LABELS
bookinfo   Active   4h8m   istio-injection=enabled

# 删除 image mirror webhook 并重新部署，以便自动映射 sidecar image 为中国区镜像
kubectl delete -f https://raw.githubusercontent.com/nwcdlabs/container-mirror/master/webhook/mutating-webhook.yaml
kubectl apply -f https://raw.githubusercontent.com/nwcdlabs/container-mirror/master/webhook/mutating-webhook.yaml

# 部署 bookinfo 示例应用
cd istio/bookinfo
kubectl apply -f bookinfo.yaml -n bookinfo
# 等待所有 pod 正常运行
NAME                              READY   STATUS    RESTARTS   AGE
details-v1-74f858558f-mc9gn       2/2     Running   0          3h43m
productpage-v1-76589d9fdc-vm6fl   2/2     Running   0          3h43m
ratings-v1-7855f5bcb9-nvfr9       2/2     Running   0          3h43m
reviews-v1-64bc5454b9-9dsdt       2/2     Running   0          3h43m
reviews-v2-76c64d4bdf-5bqfg       2/2     Running   0          3h43m
reviews-v3-5545c7c78f-5c456       2/2     Running   0          3h42m

# 为 bookinfo 部署 gateway
kubectl apply -f bookinfo-gateway.yaml -n bookinfo
# 验证访问 bookinfo 页面
GATEWAY_URL=$(kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.status.loadBalancer.ingress[0].hostname}') && echo "http://${GATEWAY_URL}/productpage"
http://ac998a6336e9643bbaac93de0e0fcde2-1154939131.cn-north-1.elb.amazonaws.com.cn/productpage
```

> 14.2.2 配置流量管理策略

1. 为 bookinfo 中的所有服务创建默认 destination rules
 ```bash
# 创建 default destination rules
kubectl apply -f destination-rule-all.yaml -n bookinfo

# 查看 destination rules
kubectl get destinationrules -n bookinfo
NAME          HOST          AGE
details       details       3h3m
productpage   productpage   3h3m
ratings       ratings       3h3m
reviews       reviews       3h3m

# 刷新 bookinfo 页面，可以看到随机显示三个版本的 Book Reviews：无星、黑色星形评价、红色星形评价

 ```
 
2. 创建 Virtual Service，将所有流量指向 reviews:v1
 
 ```bash
 # 创建 Virtual Service
 kubectl apply -f virtual-service-all-v1.yaml -n bookinfo
 
 # 刷新 bookinfo 页面，可以看到当前只显示一个版本的 Book Reviews：无星

 ```

3. 修改 Virtual Service，将用户 jason 的流量指向 reviews:v2，其他用户仍然指向 reviews:v1
```bash
 # 修改 Virtual Service
kubectl apply -f virtual-service-reviews-test-v2.yaml -n bookinfo

# 刷新 bookinfo 页面，点击 Sign in 并以 jason 登录可以显示 reviews:v2（黑色星形评价），登出之后或者以其他用户登录仍然显示 reviews:v1（无星）

```

4. 修改 Virtual Service，为用户 jason 的流量注入 7s 的延迟
```bash
 # 修改 Virtual Service
kubectl apply -f virtual-service-ratings-test-delay.yaml -n bookinfo

# 刷新 bookinfo 页面，点击 Sign in 并以 jason 登录可以看到获取 review 超时，登出之后或者以其他用户登录仍然显示 reviews:v1（无星）
# productpage 和 reviews 服务间的超时总时间为 6s（3s + 1次重试）

```

5. 修改 Virtual Service，对用户 jason 的流量做 HTTP abort
```bash
 # 修改 Virtual Service
kubectl apply -f virtual-service-ratings-test-abort.yaml -n bookinfo

# 刷新 bookinfo 页面，点击 Sign in 并以 jason 登录可以看到页面立即显示 Ratings service is currently unavailable，登出之后或者以其他用户登录仍然显示 reviews:v1（无星）

```

6. 修改 Virtual Service，实现流量灰度迁移
```bash
# 修改 Virtual Service，将所有流量指向 reviews:v1
kubectl apply -f virtual-service-all-v1.yaml -n bookinfo
# 刷新 bookinfo 页面，可以看到当前只显示一个版本的 Book Reviews：无星

# 修改 Virtual Service，将 50% 流量指向 reviews:v3
kubectl apply -f virtual-service-reviews-50-v3.yaml -n bookinfo
# 刷新 bookinfo 页面，可以看到有一半的概率显示 reviews:v1（无星） 和 reviews:v3（红色星形评价）

# 修改 Virtual Service，将所有流量指向 reviews:v3
kubectl apply -f virtual-service-reviews-v3.yaml -n bookinfo
# 刷新 bookinfo 页面，可以看到当前只显示一个版本的 Book Reviews：reviews:v3（红色星形评价）

```

> 14.2.3 cleanup
```bash
# Namespace 及所有相关资源
kubectl delete namespace bookinfo

# istioctl 删除所有 rbac 权限、istio-system namespace 及相关资源
istioctl manifest generate --set profile=demo | kubectl delete -f -
cd istio

# 删除安装时下载的 istio 目录，清除 ~/.bash_profile
rm -rf istio-${ISTIO_VERSION}
sed -i '/ISTIO_VERSION/d' ~/.bash_profile
unset ISTIO_VERSION

```
