## 15.1 前提要求

为集群中的OnDmand工作节点添加标签

```
kubectl label nodes --all 'lifecycle=OnDemand'
```
## 15.2 创建Spot工作节点组

* 添加lifecycle:Ec2Spot标签
* 添加PreferNoSchedule的Taints，使Pod尽量不要调度到Spot工作节点

```
cat << EoF > ./eks-workshop-ng-spot.yaml
apiVersion: eksctl.io/v1alpha5
kind: ClusterConfig
metadata:
  name: eksworkshop 
  region: cn-northwest-1
nodeGroups:
  - name: ng-spot
    labels:
      lifecycle: Ec2Spot
    taints:
      spotInstance: true:PreferNoSchedule
    minSize: 2
    maxSize: 5
    instancesDistribution: # At least two instance types should be specified
      instanceTypes:
        - m5.large
        - c5.large
      onDemandBaseCapacity: 0
      onDemandPercentageAboveBaseCapacity: 0 # all the instances will be spot instances
      spotInstancePools: 2
EoF

eksctl create nodegroup -f ./eks-workshop-ng-spot.yaml
```
确认新的Spot工作节点已经添加进来

```
kubectl get nodes --sort-by=.metadata.creationTimestamp
```
参考输出

```
NAME                                                STATUS   ROLES    AGE     VERSION
ip-192-168-30-112.cn-northwest-1.compute.internal   Ready    <none>   10h     v1.15.10-eks-bac369
ip-192-168-85-96.cn-northwest-1.compute.internal    Ready    <none>   9h      v1.15.10-eks-bac369
ip-192-168-59-122.cn-northwest-1.compute.internal   Ready    <none>   3m21s   v1.15.10-eks-bac369
ip-192-168-65-34.cn-northwest-1.compute.internal    Ready    <none>   3m15s   v1.15.10-eks-bac369
```
通过lifecycle=Ec2Spot节点标签，筛选Spot工作节点

```
kubectl get nodes --label-columns=lifecycle --selector=lifecycle=Ec2Spot
```
参考输出

```
NAME                                                STATUS   ROLES    AGE     VERSION               LIFECYCLE
ip-192-168-59-122.cn-northwest-1.compute.internal   Ready    <none>   4m43s   v1.15.10-eks-bac369   Ec2Spot
ip-192-168-65-34.cn-northwest-1.compute.internal    Ready    <none>   4m37s   v1.15.10-eks-bac369   Ec2Spot
```
通过lifecycle=OnDemand节点标签，筛选OnDemand工作节点

```
kubectl get nodes --label-columns=lifecycle --selector=lifecycle=OnDemand
```
参考输出

```
NAME                                                STATUS   ROLES    AGE   VERSION               LIFECYCLE
ip-192-168-30-112.cn-northwest-1.compute.internal   Ready    <none>   10h   v1.15.10-eks-bac369   OnDemand
ip-192-168-85-96.cn-northwest-1.compute.internal    Ready    <none>   9h    v1.15.10-eks-bac369   OnDemand
```
使用kubectl describe node查看节点上的Taints

```
kubectl describe node ip-192-168-59-122.cn-northwest-1.compute.internal
```
参考输出

```
Name:               ip-192-168-59-122.cn-northwest-1.compute.internal
Roles:              <none>
Annotations:        csi.volume.kubernetes.io/nodeid: {"ebs.csi.aws.com":"i-00ce3ece0420db5c3"}
                    node.alpha.kubernetes.io/ttl: 0
                    volumes.kubernetes.io/controller-managed-attach-detach: true
CreationTimestamp:  Tue, 07 Apr 2020 13:40:00 +0000
Taints:             spotInstance=true:PreferNoSchedule
```
## 15.3 部署AWS Node Termination Handler

使用Helm部署AWS Node Termination Handler

```
helm repo add eks https://aws.github.io/eks-charts

helm upgrade --install aws-node-termination-handler \
             --namespace kube-system \
             --set nodeSelector.lifecycle=Ec2Spot \
              eks/aws-node-termination-handler
```
查看已部署的aws-node-termination-handler daemonset

```
kubectl --namespace=kube-system get daemonsets
```
参考输出

```
NAME                           DESIRED   CURRENT   READY   UP-TO-DATE   AVAILABLE   NODE SELECTOR                 AGE
aws-node                       4         4         4       4            4           <none>                        26d
aws-node-termination-handler   2         2         2       2            2           lifecycle=Ec2Spot             18s
calico-node                    4         4         4       4            4           beta.kubernetes.io/os=linux   25d
ebs-csi-node                   4         4         4       4            4           beta.kubernetes.io/os=linux   26d
efs-csi-node                   4         4         4       4            4           beta.kubernetes.io/os=linux   25d
kube-proxy                     4         4         4       4            4           <none>                        26d
```
## 15.4 在Spot工作节点上部署应用

首先查看Spot工作节点上已部署的Pods

```
for n in $(kubectl get nodes -l lifecycle=Ec2Spot --no-headers | cut -d " " -f1); do echo "Pods on instance ${n}:";kubectl get pods --all-namespaces  --no-headers --field-selector spec.nodeName=${n} ; echo ; done
```
参考输出

```
Pods on instance ip-192-168-59-122.cn-northwest-1.compute.internal:
kube-system   aws-node-sqzg8                       1/1   Running   0     16m
kube-system   aws-node-termination-handler-6m2d9   1/1   Running   0     2m53s
kube-system   calico-node-qjsvn                    1/1   Running   0     16m
kube-system   ebs-csi-node-fx6z2                   3/3   Running   0     16m
kube-system   efs-csi-node-hxs7m                   3/3   Running   0     16m
kube-system   kube-proxy-f6mht                     1/1   Running   0     16m

Pods on instance ip-192-168-65-34.cn-northwest-1.compute.internal:
kube-system   aws-node-n5hlk                       1/1   Running   0     16m
kube-system   aws-node-termination-handler-x77p2   1/1   Running   0     2m53s
kube-system   calico-node-tzdlx                    1/1   Running   0     16m
kube-system   ebs-csi-node-jkwpf                   3/3   Running   0     16m
kube-system   efs-csi-node-btv9f                   3/3   Running   0     16m
kube-system   kube-proxy-mpvxh                     1/1   Running   0     16m
```
部署未配置Node Affinity和Tolerations的Nginx Deployment进行测试，可以预期Nginx会运行在所有Spot工作节点和OnDemand工作节点

```
cat << EoF > ./nginx-deployment.yaml
apiVersion: extensions/v1beta1
kind: Deployment
metadata:
  labels:
    app: nginx
  name: nginx
  namespace: default
spec:
  replicas: 1
  selector:
    matchLabels:
      app: nginx
  strategy:
    rollingUpdate:
      maxSurge: 25%
      maxUnavailable: 25%
    type: RollingUpdate
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - image: nginx
        imagePullPolicy: Always
        name: nginx
EoF

kubectl create -f ./nginx-deployment.yaml
```
提升Nginx Deployment副本数量

```
kubectl scale deployment nginx --replicas=8
```
参考输出，可以看到Spot工作节点和OnDemand节点都运行了Nginx Pod

```
NAME                     READY   STATUS    RESTARTS   AGE   IP               NODE                                                NOMINATED NODE   READINESS GATES
nginx-554b9c67f9-85wvx   1/1     Running   0          3s    192.168.91.54    ip-192-168-85-96.cn-northwest-1.compute.internal    <none>           <none>
nginx-554b9c67f9-99gtw   1/1     Running   0          3s    192.168.9.108    ip-192-168-30-112.cn-northwest-1.compute.internal   <none>           <none>
nginx-554b9c67f9-cjl8v   1/1     Running   0          3s    192.168.56.221   ip-192-168-53-158.cn-northwest-1.compute.internal   <none>           <none>
nginx-554b9c67f9-cr8pv   1/1     Running   0          3s    192.168.21.55    ip-192-168-19-144.cn-northwest-1.compute.internal   <none>           <none>
nginx-554b9c67f9-jnvnx   1/1     Running   0          3s    192.168.36.202   ip-192-168-53-158.cn-northwest-1.compute.internal   <none>           <none>
nginx-554b9c67f9-vgvwc   1/1     Running   0          28s   192.168.51.153   ip-192-168-53-158.cn-northwest-1.compute.internal   <none>           <none>
nginx-554b9c67f9-w76bd   1/1     Running   0          3s    192.168.12.25    ip-192-168-19-144.cn-northwest-1.compute.internal   <none>           <none>
nginx-554b9c67f9-xnnh6   1/1     Running   0          3s    192.168.69.25    ip-192-168-85-96.cn-northwest-1.compute.internal    <none>           <none>
```
修改nginx-deployment.yaml文件，在spec.template.spec下增加如下内容：

```
      affinity:
        nodeAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 1
            preference:
              matchExpressions:
              - key: lifecycle
                operator: In
                values:
                - Ec2Spot
      tolerations:
      - key: "spotInstance"
        operator: "Equal"
        value: "true"
        effect: "PreferNoSchedule"
```
重新部署nginx-deployment

```
kubectl delete deployment nginx

kubectl create -f nginx-deployment.yaml
kubectl scale deployment nginx --replicas=8
```
查看Pod运行在哪些节点上

```
kubectl get pods -o wide
```
参考输出，可以看到所有Pod已经全部调度到Spot工作节点

```
NAME                     READY   STATUS    RESTARTS   AGE   IP               NODE                                                NOMINATED NODE   READINESS GATES
nginx-5b5755b75f-5t74s   1/1     Running   0          3s    192.168.27.153   ip-192-168-19-144.cn-northwest-1.compute.internal   <none>           <none>
nginx-5b5755b75f-7t94c   1/1     Running   0          3s    192.168.51.153   ip-192-168-53-158.cn-northwest-1.compute.internal   <none>           <none>
nginx-5b5755b75f-fhddm   1/1     Running   0          44s   192.168.60.188   ip-192-168-53-158.cn-northwest-1.compute.internal   <none>           <none>
nginx-5b5755b75f-kfn8h   1/1     Running   0          3s    192.168.0.92     ip-192-168-19-144.cn-northwest-1.compute.internal   <none>           <none>
nginx-5b5755b75f-kllhn   1/1     Running   0          3s    192.168.12.25    ip-192-168-19-144.cn-northwest-1.compute.internal   <none>           <none>
nginx-5b5755b75f-t2t9m   1/1     Running   0          3s    192.168.24.15    ip-192-168-19-144.cn-northwest-1.compute.internal   <none>           <none>
nginx-5b5755b75f-vrgpd   1/1     Running   0          3s    192.168.37.30    ip-192-168-53-158.cn-northwest-1.compute.internal   <none>           <none>
nginx-5b5755b75f-x4qkf   1/1     Running   0          3s    192.168.56.165   ip-192-168-53-158.cn-northwest-1.compute.internal   <none>           <none>
```
## 15.5 清理环境

清理AWS Node Termination Handler Daemonset

```
helm uninstall aws-node-termination-handler --namespace=kube-system
```
删除先前添加的节点标签和已创建的Spot工作节点组

```
kubectl label nodes --all lifecycle-

eksctl delete nodegroup -f  ./eks-workshop-ng-spot.yaml --approve
```
