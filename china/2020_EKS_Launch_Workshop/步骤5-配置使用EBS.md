# 步骤5 配置使用EBS CSI

* [官方ebs-csi指导](https://docs.aws.amazon.com/zh_cn/eks/latest/userguide/ebs-csi.html)
* [官方eks-persistent-storage支持手册](https://aws.amazon.com/premiumsupport/knowledge-center/eks-persistent-storage/)

5.1 创建所需要的IAM policy , EKS OIDC provider, service account

> 5.1.1 创建所需要的IAM policy
[https://raw.githubusercontent.com/kubernetes-sigs/aws-ebs-csi-driver/v0.4.0/docs/example-iam-policy.json](https://raw.githubusercontent.com/kubernetes-sigs/aws-ebs-csi-driver/v0.4.0/docs/example-iam-policy.json)

```bash

#中国区请使用aws-ebs-csi-driver/ebs-csi-iam-policy.json
aws iam create-policy \
    --policy-name Amazon_EBS_CSI_Driver \
    --policy-document file://./aws-ebs-csi-driver/ebs-csi-iam-policy.json \
    --region ${AWS_REGION}
        
#返回示例,请记录返回的Plociy ARN
POLICY_NAME=$(aws iam list-policies --query 'Policies[?PolicyName==`EKS_EBS_CSI_Driver_Policy`].Arn' 、
    --output text --region ${AWS_REGION})
```

> 5.1.2 获取EKS工作节点的IAM role

```bash
# 注意这一步如果是多个nodegroup就会有多个role
kubectl -n kube-system describe configmap aws-auth

# 单个节点组
ROLE_NAME=Role-name-in-above-output
aws iam attach-role-policy --policy-arn ${POLICY_NAME} \
    --role-name ${ROLE_NAME} --region ${AWS_REGION}

#多个节点组, 这里准备了一个脚本updaterole.sh
sh aws-ebs-csi-driver/updaterole.sh ${POLICY_NAME}
```

> 5.1.3 部署EBS CSI 驱动到eks 集群

[官方文档 https://docs.aws.amazon.com/zh_cn/eks/latest/userguide/ebs-csi.html](https://docs.aws.amazon.com/zh_cn/eks/latest/userguide/ebs-csi.html)

```bash
#git clone https://github.com/kubernetes-sigs/aws-ebs-csi-driver.git

#中国区请使用resource/aws-ebs-csi-driver的配置文件进行部署
kubectl apply -k aws-ebs-csi-driver/deploy/kubernetes/overlays/stable

# 验证部署正确 
kubectl get pods -n kube-system
NAME                                      READY   STATUS             RESTARTS   AGE
alb-ingress-controller-649b854d75-m8c75   1/1     Running            0          2d
aws-node-ct6rz                            1/1     Running            0          4d
aws-node-sfjtn                            1/1     Running            0          3d2h
aws-node-xzfx9                            1/1     Running            0          4d
coredns-6565755d58-pd5nm                  1/1     Running            0          4d
coredns-6565755d58-v9nl7                  1/1     Running            0          4d
ebs-csi-controller-6dcc4dc6f4-6k4s5       4/4     Running            0          47h
ebs-csi-controller-6dcc4dc6f4-vtklz       4/4     Running            0          47h
ebs-csi-node-2zmct                        3/3     Running            0          47h
ebs-csi-node-plljf                        3/3     Running            0          47h
ebs-csi-node-s9lbz                        3/3     Running            0          47h
kube-proxy-g4mcw                          1/1     Running            0          4d
kube-proxy-mb88w                          1/1     Running            0          4d
kube-proxy-tpx4x                          1/1     Running            0          3d2h
kubernetes-dashboard-5f7b999d65-dcc6h     1/1     Running            0          2d4h
metrics-server-7fcf9cc98b-rntrh           1/1     Running            0          26h
```

5.2 部署动态卷实例应用

```bash
cd aws-ebs-csi-driver/examples/kubernetes/dynamic-provisioning/
kubectl apply -f specs/

#查看storageclass
kubectl describe storageclass ebs-sc

#查看示例app状态
kubectl get pods --watch
#查看是否有失败
kubectl get events

kubectl get pv
PV_NAME=$(kubectl get pv -o json | jq -r '.items[0].metadata.name')
kubectl describe persistentvolumes ${PV_NAME}

kubectl exec -it app cat /data/out.txt
# Thu Mar 5 14:19:43 UTC 2020
# Thu Mar 5 14:19:48 UTC 2020

#删除示例程序
kubectl delete -f specs/
```