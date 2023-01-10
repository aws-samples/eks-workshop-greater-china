# 步骤8 配置使用EBS CSI

8. 创建所需要的IAM policy , EKS OIDC provider, service account




> 8.1.3 部署EBS CSI 驱动到eks 集群

```bash
kubectl apply -k  "github.com/kubernetes-sigs/aws-ebs-csi-driver/deploy/kubernetes/overlays/stable/?ref=release-1.10"

#验证部署是否正确 
kubectl get pods -n kube-system | grep csi
#参考输出,每个节点会各自部署ebs-csi-controller和ebs-csi-node 
NAME                                      READY   STATUS              RESTARTS   AGE
ebs-csi-controller-78bc69cb98-cddl6       4/4     Running   0          4m5s
ebs-csi-controller-78bc69cb98-ng6nx       4/4     Running   0          4m5s
ebs-csi-node-l4m88                        3/3     Running   0          4m5s
ebs-csi-node-z86xc                        3/3     Running   0          4m5s
```

8.2 部署EBS动态卷实例应用

```bash
 git clone https://github.com/kubernetes-sigs/aws-ebs-csi-driver.git
 cd aws-ebs-csi-driver
 git checkout v1.10.0

kubectl apply -f examples/kubernetes/dynamic-provisioning/manifests

#查看storageclass
kubectl describe storageclass ebs-sc

#查看示例app状态
kubectl get pods

#查看是否有失败事件(可选)
#kubectl get events

kubectl get pv
PV_NAME=$(kubectl get pv -o json | jq -r '.items[0].metadata.name')
kubectl describe persistentvolumes ${PV_NAME}

kubectl exec -it app --  tail -f  /data/out.txt
# Thu Mar 5 14:19:43 UTC 2020
# Thu Mar 5 14:19:48 UTC 2020

#删除示例程序
kubectl delete -f examples/kubernetes/dynamic-provisioning/manifests
```



8.2 部署EBS静态卷实例应用

```bash
kubectl apply -f examples/kubernetes/static-provisioning/manifests

... 中间验证步骤同8.1

kubectl delete -f examples/kubernetes/static-provisioning/manifests
```

