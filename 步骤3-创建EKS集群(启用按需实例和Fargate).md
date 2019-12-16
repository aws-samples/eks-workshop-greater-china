# 步骤3: 创建EKS集群(启用按需实例和Fargate)

3.1 打开Cloud9终端管理控制台， 使用eksctl 创建EKS集群(操作需要10-15分钟),该命令同时会创建一个使用t3.small的受管节点组。

 ```bash
 eksctl create cluster \
       --name eksworkshop \
       --version 1.14 \
       --node-type t3.small \
       --nodes 1 \
       --managed
 ```
 
 ![](media/15764759782724/15764761011094.jpg)

  查看EKS集群工作节点
  ```bash
   kubectl get node
  ```
  ![](media/15764759782724/15764762619982.jpg)

3.2 (可选)部署一个测试应用
在Cloud9创建一个nginx.yaml,内容如下

```yaml
---
apiVersion: extensions/v1beta1
kind: Deployment
metadata:
  name: nginx-deployment
  labels:
    app: nginx
spec:
  replicas: 1
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: "service-nginx"
  annotations:
        service.beta.kubernetes.io/aws-load-balancer-type: nlb
spec:
  selector:
    app: nginx
  type: LoadBalancer
  ports:
  - protocol: TCP
    port: 80
    targetPort: 80



```
 
 > 部署nginx
 
 ```bash
  kubectl apply -f nginx.yaml

 ```

3.3 使用eksctl创建fargateprofile
   我们将会创建一个fargateprofile,并且将namespace参数设置为dev, 这样之后所有在dev部署的deployment、pod就会使用fargatefu实例运行了。

```bash

 kubectl create namespace dev

 eksctl create fargateprofile --cluster eksworkshop --name fargate-dev  --namespace dev

#(可选)部署nginx到fargate
kubectl apply -f nginx.yaml --namespace dev
```



