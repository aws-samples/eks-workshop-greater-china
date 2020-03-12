# 步骤6 配置使用EFS

6.1 创建EFS file system
```bash
# 创建EFS Security group
VPC_ID=$(aws eks describe-cluster --name ${CLUSTER_NAME} --region ${AWS_REGION} --query "cluster.resourcesVpcConfig.vpcId" --output text)
VPC_CIDR=$(aws ec2 describe-vpcs --vpc-ids ${VPC_ID} --query "Vpcs[].CidrBlock"  --region ${AWS_REGION} --output text)
aws ec2 create-security-group --description ${CLUSTER_NAME}-efs-eks-sg --group-name efs-sg --vpc-id ${VPC_ID}
SGGroupID=上一步的结果访问
aws ec2 authorize-security-group-ingress --group-id ${SGGroupID}  --protocol tcp --port 2049 --cidr ${VPC_CIDR}

# 创建EFS file system 和 mount-target
aws efs create-file-system --creation-token eks-efs --region ${AWS_REGION}
aws efs create-mount-target --file-system-id FileSystemId --subnet-id SubnetID --security-group SGGroupID

```



6.2. 部署EFS驱动和示例程序
[官方文档]（https://docs.aws.amazon.com/zh_cn/eks/latest/userguide/efs-csi.html）

```bash
git clone https://github.com/kubernetes-sigs/aws-efs-csi-driver.git
cd aws-efs-csi-driver
```

6.2.1 Deploy EFS CSI driver to EKS cluster 

> 已知问题：

https://github.com/kubernetes-sigs/aws-efs-csi-driver/issues/138
v0.2.0 image contains old version of efs-utils, efs-utils added China region support from v1.19
The v.0.3.0 does work, you can also build your image to use v.0.2.0 CSI

```bash
#使用EFS CSI v0.3.0 镜像
kubectl apply -k /aws-efs-csi-driver/deploy/kubernetes/overlays/stable
kubectl get pods -n kube-system

NAME                                      READY   STATUS    RESTARTS   AGE
alb-ingress-controller-649b854d75-m8c75   1/1     Running   0          2d18h
aws-node-ct6rz                            1/1     Running   0          4d18h
aws-node-sfjtn                            1/1     Running   0          3d21h
aws-node-xzfx9                            1/1     Running   0          4d18h
coredns-6565755d58-pd5nm                  1/1     Running   0          4d18h
coredns-6565755d58-v9nl7                  1/1     Running   0          4d18h
ebs-csi-controller-6dcc4dc6f4-6k4s5       4/4     Running   0          2d17h
ebs-csi-controller-6dcc4dc6f4-vtklz       4/4     Running   0          2d17h
ebs-csi-node-2zmct                        3/3     Running   0          2d17h
ebs-csi-node-plljf                        3/3     Running   0          2d17h
ebs-csi-node-s9lbz                        3/3     Running   0          2d17h
efs-csi-node-5jtlc                        3/3     Running   0          10h
efs-csi-node-lqdz9                        3/3     Running   0          10h
efs-csi-node-snqmh                        3/3     Running   0          10h
kube-proxy-g4mcw                          1/1     Running   0          4d18h
kube-proxy-mb88w                          1/1     Running   0          4d18h
kube-proxy-tpx4x                          1/1     Running   0          3d21h
kubernetes-dashboard-5f7b999d65-dcc6h     1/1     Running   0          2d23h
metrics-server-7fcf9cc98b-rntrh           1/1     Running   0          44h

kubectl exec -ti efs-csi-node-5jtlc -n kube-system -- mount.efs --version
# Make sure the version is > 1.19
```

6.2.2 部署样例测试
```bash
## Deploy app use the EFS
cd examples/kubernetes/multiple_pods/
aws efs describe-file-systems --query "FileSystems[*].[FileSystemId,Name]" --region ${AWS_REGION} --output text

# 修改 the specs/pv.yaml file and replace the volumeHandle with FILE_SYSTEM_ID
# 例子：
#csi:
#    driver: efs.csi.aws.com
#    volumeHandle: fs-9c21a999


# 部署 the efs-sc storage class, efs-claim pv claim, efs-pv, and app1 and app2 sample applications.
kubectl apply -f specs/

kubectl describe storageclass efs-sc
kubectl get pv
kubectl describe pv efs-pv
kubectl get pods --watch
kubectl get events

# 验证
kubectl exec -ti app1 -- tail /data/out1.txt
kubectl exec -ti app2 -- tail /data/out1.txt

# 清理
kubectl delete -f specs/
```
