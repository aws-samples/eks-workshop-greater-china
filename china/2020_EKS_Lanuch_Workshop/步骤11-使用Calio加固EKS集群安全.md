# 步骤11 使用Calio加固EKS集群安全

Kubernetes Network Policy 网络策略是有关如何允许Pod组与彼此以及其他网络端点进行通信的规范。
Network Policy资源使用标签选择Pods并定义规则，这些规则指定允许流量到选定Pods。Network policies 由Kubernetes 网络插件实现。
默认情况下，Pods是non-isolated的, 他们接受来自任何来源的流量。通过选择了一定Pods的Network Policy，可以使得Pods可以被Isolated。
在本节中，我们将学习使用开源工具通过网络策略来加固群集安全，保护集群资源。
[官方文档](https://kubernetes.io/docs/concepts/services-networking/network-policies/)

> 本节目的
1. 使用Calico 在Kubernetes集群中实施网络策略，保护服务资源
2. 使用Tigera的Secure Cloud Edition将Kubernetes网络策略与EKS的VPC安全组集成


11.1 配置Calico

Apply the Calico manifest from the aws/amazon-vpc-cni-k8s GitHub project. This creates the daemon sets in the kube-system namespace.
Taints and tolerations work together to ensure pods are not scheduled onto inappropriate nodes. Taints are applied to nodes, and the only pods that can tolerate the taint are allowed to run on those nodes.

## 部署 Calico
```bash
# 部署 calico
mkdir network-policy && cd network-policy
wget https://raw.githubusercontent.com/aws/amazon-vpc-cni-k8s/master/config/v1.6/calico.yaml
kubectl apply -f calico.yaml

# wait for the calico-node daemon set to have the DESIRED number of pods in the READY state
kubectl get daemonset calico-node --namespace=kube-system
NAME          DESIRED   CURRENT   READY   UP-TO-DATE   AVAILABLE   NODE SELECTOR                 AGE
calico-node   3         3         3       3            3           beta.kubernetes.io/os=linux   3m9s

kubectl get pods --namespace=kube-system

```

## 创建 Policy示例
```bash
# create stars namespace
mkdir -p calico_resources && cd calico_resources
wget https://eksworkshop.com/beginner/120_network-policies/calico/stars_policy_demo/create_resources.files/namespace.yaml
cat namespace.yaml
kubectl apply -f namespace.yaml

# create frontend and backend replication controllers and services under stars namespace
wget https://eksworkshop.com/beginner/120_network-policies/calico/stars_policy_demo/create_resources.files/management-ui.yaml
wget https://eksworkshop.com/beginner/120_network-policies/calico/stars_policy_demo/create_resources.files/backend.yaml
wget https://eksworkshop.com/beginner/120_network-policies/calico/stars_policy_demo/create_resources.files/frontend.yaml
wget https://eksworkshop.com/beginner/120_network-policies/calico/stars_policy_demo/create_resources.files/client.yaml

kubectl apply -f management-ui.yaml
kubectl apply -f backend.yaml
kubectl apply -f frontend.yaml
kubectl apply -f client.yaml

kubectl get pods --namespace=stars
NAME             READY   STATUS    RESTARTS   AGE
backend-lfmj5    1/1     Running   0          8m29s
frontend-bnmvt   1/1     Running   0          8m25s

kubectl get pods --namespace=management-ui
NAME                  READY   STATUS    RESTARTS   AGE
management-ui-xnp4r   1/1     Running   0          8m55s

kubectl get pods --namespace=client
NAME           READY   STATUS    RESTARTS   AGE
client-9nfbq   1/1     Running   0          7s
```

## 配置 Policy
1. By default, pods can communicate with other pods
```bash
kubectl get svc -o wide -n management-ui
ALB_INGRESS=$(kubectl get svc -n management-ui -o json | jq -r '.items[0].status.loadBalancer.ingress[].hostname')
echo ${ALB_INGRESS}
# Visit management-ui to show the default behavior: all services being able to reach each other.
```

2. Let's isolate the services from each other
```bash
# Sample deny all policy: podSelector does not have any matchLabels, essentially blocking all the pods from accessing it
wget https://eksworkshop.com/beginner/120_network-policies/calico/stars_policy_demo/apply_network_policies.files/default-deny.yaml
kubectl apply -n stars -f default-deny.yaml
kubectl apply -n client -f default-deny.yaml
# management UI cannot reach any of the nodes, so nothing shows up in the UI.
```

3. Traffic is allowed in specific direction on a specific port
```bash
# allow stars namespaces pods accessed by management-ui and allow client namespaces pods accessed by management-ui
wget https://eksworkshop.com/beginner/120_network-policies/calico/stars_policy_demo/apply_network_policies.files/allow-ui.yaml
wget https://eksworkshop.com/beginner/120_network-policies/calico/stars_policy_demo/apply_network_policies.files/allow-ui-client.yaml
kubectl apply -f allow-ui.yaml
kubectl apply -f allow-ui-client.yaml
# management UI can reach stars and client, shown traffic in UI, but front, backend and client pods still isolated.

# allow backend pods accessed by front pods but deny directly access from client
# allow front pods accessed by client pods
wget https://eksworkshop.com/beginner/120_network-policies/calico/stars_policy_demo/directional_traffic.files/backend-policy.yaml
wget https://eksworkshop.com/beginner/120_network-policies/calico/stars_policy_demo/directional_traffic.files/frontend-policy.yaml

kubectl apply -f backend-policy.yaml -n stars
kubectl apply -f frontend-policy.yaml -n stars
# management UI can reach stars and client, shown traffic in UI, front->backend and client->front, but client->backend still blocked.
# backend-policy. Its spec has a podSelector that selects all pods with the label role:backend, and allows ingress from all pods that have the label role:frontend and on TCP port 6379, but not the other way round. 
# frontend-policy. Its spec allows ingress from namespaces that have the label role: client on TCP port 80.
```

4. cleanup
```bash
kubectl delete namespace client stars management-ui
kubectl get pods --all-namespaces
```
