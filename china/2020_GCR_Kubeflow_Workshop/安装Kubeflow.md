#### 前提

本kubeflow workshop 需要的软件环境有 aws cli , eksctl ,kubectl,e aws-iam-authenticator以及eks对应操作的IAM权限。具体安装步骤请参考[2020_EKS_Launch_Workshop/步骤1-准备实验环境]([https://github.com/aws-samples/eks-workshop-greater-china/blob/master/china/2020_EKS_Launch_Workshop/%E6%AD%A5%E9%AA%A41-%E5%87%86%E5%A4%87%E5%AE%9E%E9%AA%8C%E7%8E%AF%E5%A2%83.md](https://github.com/aws-samples/eks-workshop-greater-china/blob/master/china/2020_EKS_Launch_Workshop/步骤1-准备实验环境.md))。

本workshop选择了缺省的kfctl配置文件，以简化kubeflow安装。但是，我们建议在生产环境中安装Cognito配置并添加身份验证和SSL(通过ACM)。有关启用Cognito所需的其他步骤，请参阅[Kubeflow documentation](https://www.kubeflow.org/docs/aws/deploy/install-kubeflow/)文档

#### 设置环境变量

执行以下命令来设置环境变量，然后为这个部署设置Kubeflow应用程序目录,在CLUSTER_NAME指定您的EKS集群名称

```bash
export REGION=cn-northwest-1
export CLUSTER_NAME=eks
export BASE_DIR=$(pwd)
export KF_NAME=${CLUSTER_NAME}
export KF_DIR=${BASE_DIR}/${KF_NAME}
export CONFIG_FILE=${KF_DIR}/kfctl_aws.yaml
```

#### 使用eksctl创建EKS集群

由于Kubeflow需要较多的资源来部署，通过执行以下操作创建一个6个工作节点EKS集群，大约需要15分钟，请耐心等待。

```bash
eksctl create cluster --name=${CLUSTER_NAME} --nodes=4 --managed --alb-ingress-access --region=${REGION}
```

获取EKS 工作节点role，配置环境变量用于后续使用

```bash
export STACK_NAME=$(eksctl get nodegroup --cluster $CLUSTER_NAME --region $REGION  -o json | jq -r '.[].StackName')
export NODE_INSTANCE_ROLE=$(aws cloudformation describe-stack-resources --region $REGION --stack-name $STACK_NAME | jq -r '.StackResources[] | select(.LogicalResourceId=="NodeInstanceRole") | .PhysicalResourceId' ) 
```

#### 安装kubeflow

下载并安装kfctl

```
curl --silent --location "https://github.com/kubeflow/kfctl/releases/download/v1.0.1/kfctl_v1.0.1-0-gf3edb9b_linux.tar.gz" | tar xz -C /tmp
sudo mv -v /tmp/kfctl /usr/local/bin
```

配置和下载kubeflow文件，本实验使用非cognito版本，默认不进行身份验证。（注意：如果存在文件不能下载的问题，可以尝试重新运行wget -O ${KF_DIR}/kfctl_aws.yaml $CONFIG_URI）

```bash
export CONFIG_URI="https://raw.githubusercontent.com/kubeflow/manifests/v1.0-branch/kfdef/kfctl_aws.v1.0.1.yaml"
export KF_NAME=${CLUSTER_NAME}
mkdir -p ${BASE_DIR}
export KF_DIR=${BASE_DIR}/${KF_NAME}
mkdir -p ${KF_DIR}
wget -O ${KF_DIR}/kfctl_aws.yaml $CONFIG_URI
export CONFIG_FILE=${KF_DIR}/kfctl_aws.yaml

```

替换kfctl_aws.yaml中的region和role为当前的创建eks的region和node节点使用的role

```bash
sed -i'.bak' ${CONFIG_FILE}
sed -i -e "s/eksctl-kubeflow-aws-nodegroup-ng-a2-NodeInstanceRole-xxxxxxx/$NODE_INSTANCE_ROLE/g" ${CONFIG_FILE}
sed -i -e 's/us-west-2/'"$REGION"'/' ${CONFIG_FILE}
```

检查kfctl_aws.yaml是否正确替换

```
region: cn-northwest-1
roles:
- eksctl-kubeflow-example-nodegroup-ng-185-NodeInstanceRole-1DDJJXQBG9EM6
```

kfclt 本质上是使用了 kustomize 来安装，通过kfctl build生成kubeflow  kustomize配置文件

```bash
kfctl build -f ${CONFIG_FILE}
```

由于防火墙或安全限制，海外gcr.io, quay.io的镜像可能无法下载，需要通过修改镜像的方式安装，把镜像url替换成aws国内镜像站点url：

```bash
sed -i "s/gcr.io/048912060910.dkr.ecr.cn-northwest-1.amazonaws.com.cn\/gcr/g" `grep "gcr.io" -rl ${KF_DIR}`
sed -i "s/quay.io/048912060910.dkr.ecr.cn-northwest-1.amazonaws.com.cn\/quay/g" `grep "quay.io" -rl ${KF_DIR}`
```

开始部署kubeflow

```bash
kfctl apply -V -f ${CONFIG_FILE}
```

安装Kubeflow及其工具集可能需要数分钟。有一些的pod最初可能会出现Error或CrashLoopBackOff状态。需要一些时间，它们会自动修复，并进入运行状态



#### 验证kubeflow是否成功部署

运行下面的命令检查状态

```
kubectl -n kubeflow get all
```

如果一段时间后仍不正常，请通过查看日志进行故障排除

<details>
<summary>状态信息</summary>
<pre><codes>
$ kubectl -n kubeflow get all                         
NAME                                                               READY   STATUS      RESTARTS   AGE
pod/admission-webhook-bootstrap-stateful-set-0                     1/1     Running     0          5m50s
pod/admission-webhook-deployment-64cb96ddbf-x2zfm                  1/1     Running     0          5m12s
pod/alb-ingress-controller-c76dd95d-z2kc7                          1/1     Running     0          5m45s
pod/application-controller-stateful-set-0                          1/1     Running     0          6m32s
pod/argo-ui-778676df64-w4lpj                                       1/1     Running     0          5m51s
pod/centraldashboard-7dd7dd685d-fjnr2                              1/1     Running     0          5m51s
pod/jupyter-web-app-deployment-89789fd5-pmwmf                      1/1     Running     0          5m50s
pod/katib-controller-6b789b6cb5-rc7xz                              1/1     Running     1          5m48s
pod/katib-db-manager-64f548b47c-6p6nv                              1/1     Running     0          5m48s
pod/katib-mysql-57884cb488-6g9zk                                   1/1     Running     0          5m48s
pod/katib-ui-5c5cc6bd77-mwmrl                                      1/1     Running     0          5m48s
pod/metacontroller-0                                               1/1     Running     0          5m51s
pod/metadata-db-76c9f78f77-pjvh8                                   1/1     Running     0          5m49s
pod/metadata-deployment-674fdd976b-946k6                           1/1     Running     0          5m49s
pod/metadata-envoy-deployment-5688989bd6-j5bdh                     1/1     Running     0          5m49s
pod/metadata-grpc-deployment-5579bdc87b-fc88k                      1/1     Running     2          5m49s
pod/metadata-ui-9b8cd699d-drm2p                                    1/1     Running     0          5m49s
pod/minio-755ff748b-hdfwk                                          1/1     Running     0          5m47s
pod/ml-pipeline-79b4f85cbc-hcttq                                   1/1     Running     5          5m47s
pod/ml-pipeline-ml-pipeline-visualizationserver-5fdffdc5bf-nqjb5   1/1     Running     0          5m46s
pod/ml-pipeline-persistenceagent-645cb66874-rgrt4                  1/1     Running     1          5m47s
pod/ml-pipeline-scheduledworkflow-6c978b6b85-dxgw4                 1/1     Running     0          5m46s
pod/ml-pipeline-ui-6995b7bccf-ktwb2                                1/1     Running     0          5m47s
pod/ml-pipeline-viewer-controller-deployment-8554dc7b9f-n4ccc      1/1     Running     0          5m46s
pod/mpi-operator-5bf8b566b7-gkbz9                                  1/1     Running     0          5m45s
pod/mysql-598bc897dc-srtpt                                         1/1     Running     0          5m47s
pod/notebook-controller-deployment-7db57b9ccf-4pqkw                1/1     Running     0          5m49s
pod/nvidia-device-plugin-daemonset-4s9tv                           1/1     Running     0          5m46s
pod/nvidia-device-plugin-daemonset-5p8kn                           1/1     Running     0          5m46s
pod/nvidia-device-plugin-daemonset-84jv6                           1/1     Running     0          5m46s
pod/nvidia-device-plugin-daemonset-d7x5f                           1/1     Running     0          5m46s
pod/nvidia-device-plugin-daemonset-m8cpr                           1/1     Running     0          5m46s
pod/profiles-deployment-b45dbc6f-7jfqw                             2/2     Running     0          5m46s
pod/pytorch-operator-5fd5f94bdd-dbddk                              1/1     Running     0          5m49s
pod/seldon-controller-manager-679fc777cd-58vzl                     1/1     Running     0          5m45s
pod/spark-operatorcrd-cleanup-tc4nw                                0/2     Completed   0          5m50s
pod/spark-operatorsparkoperator-c7b64b87f-w6glw                    1/1     Running     0          5m50s
pod/spartakus-volunteer-5b7d86d9cd-2z4dn                           1/1     Running     0          5m49s
pod/tensorboard-6544748d94-dr87g                                   1/1     Running     0          5m48s
pod/tf-job-operator-7d7c8fb8bb-bh2j9                               1/1     Running     0          5m48s
pod/workflow-controller-945c84565-ctx84                            1/1     Running     0          5m51s


NAME                                                  TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)             AGE
service/admission-webhook-service                     ClusterIP   10.100.34.137    <none>        443/TCP             5m50s
service/application-controller-service                ClusterIP   10.100.122.252   <none>        443/TCP             6m32s
service/argo-ui                                       NodePort    10.100.56.77     <none>        80:32722/TCP        5m51s
service/centraldashboard                              ClusterIP   10.100.122.184   <none>        80/TCP              5m51s
service/jupyter-web-app-service                       ClusterIP   10.100.184.50    <none>        80/TCP              5m50s
service/katib-controller                              ClusterIP   10.100.96.16     <none>        443/TCP,8080/TCP    5m48s
service/katib-db-manager                              ClusterIP   10.100.161.38    <none>        6789/TCP            5m48s
service/katib-mysql                                   ClusterIP   10.100.186.115   <none>        3306/TCP            5m48s
service/katib-ui                                      ClusterIP   10.100.110.39    <none>        80/TCP              5m48s
service/metadata-db                                   ClusterIP   10.100.92.177    <none>        3306/TCP            5m49s
service/metadata-envoy-service                        ClusterIP   10.100.17.145    <none>        9090/TCP            5m49s
service/metadata-grpc-service                         ClusterIP   10.100.238.212   <none>        8080/TCP            5m49s
service/metadata-service                              ClusterIP   10.100.183.244   <none>        8080/TCP            5m49s
service/metadata-ui                                   ClusterIP   10.100.28.97     <none>        80/TCP              5m49s
service/minio-service                                 ClusterIP   10.100.185.36    <none>        9000/TCP            5m48s
service/ml-pipeline                                   ClusterIP   10.100.45.162    <none>        8888/TCP,8887/TCP   5m48s
service/ml-pipeline-ml-pipeline-visualizationserver   ClusterIP   10.100.211.60    <none>        8888/TCP            5m47s
service/ml-pipeline-tensorboard-ui                    ClusterIP   10.100.150.113   <none>        80/TCP              5m47s
service/ml-pipeline-ui                                ClusterIP   10.100.135.60    <none>        80/TCP              5m47s
service/mysql                                         ClusterIP   10.100.37.144    <none>        3306/TCP            5m48s
service/notebook-controller-service                   ClusterIP   10.100.250.183   <none>        443/TCP             5m49s
service/profiles-kfam                                 ClusterIP   10.100.24.246    <none>        8081/TCP            5m47s
service/pytorch-operator                              ClusterIP   10.100.104.208   <none>        8443/TCP            5m49s
service/seldon-webhook-service                        ClusterIP   10.100.68.153    <none>        443/TCP             5m46s
service/tensorboard                                   ClusterIP   10.100.25.5      <none>        9000/TCP            5m49s
service/tf-job-operator                               ClusterIP   10.100.165.41    <none>        8443/TCP            5m48s

NAME                                            DESIRED   CURRENT   READY   UP-TO-DATE   AVAILABLE   NODE SELECTOR   AGE
daemonset.apps/nvidia-device-plugin-daemonset   5         5         5       5            5           <none>          5m46s

NAME                                                          READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/admission-webhook-deployment                  1/1     1            1           5m50s
deployment.apps/alb-ingress-controller                        1/1     1            1           5m46s
deployment.apps/argo-ui                                       1/1     1            1           5m51s
deployment.apps/centraldashboard                              1/1     1            1           5m51s
deployment.apps/jupyter-web-app-deployment                    1/1     1            1           5m50s
deployment.apps/katib-controller                              1/1     1            1           5m48s
deployment.apps/katib-db-manager                              1/1     1            1           5m48s
deployment.apps/katib-mysql                                   1/1     1            1           5m48s
deployment.apps/katib-ui                                      1/1     1            1           5m48s
deployment.apps/metadata-db                                   1/1     1            1           5m49s
deployment.apps/metadata-deployment                           1/1     1            1           5m49s
deployment.apps/metadata-envoy-deployment                     1/1     1            1           5m49s
deployment.apps/metadata-grpc-deployment                      1/1     1            1           5m49s
deployment.apps/metadata-ui                                   1/1     1            1           5m49s
deployment.apps/minio                                         1/1     1            1           5m48s
deployment.apps/ml-pipeline                                   1/1     1            1           5m48s
deployment.apps/ml-pipeline-ml-pipeline-visualizationserver   1/1     1            1           5m47s
deployment.apps/ml-pipeline-persistenceagent                  1/1     1            1           5m48s
deployment.apps/ml-pipeline-scheduledworkflow                 1/1     1            1           5m47s
deployment.apps/ml-pipeline-ui                                1/1     1            1           5m47s
deployment.apps/ml-pipeline-viewer-controller-deployment      1/1     1            1           5m47s
deployment.apps/mpi-operator                                  1/1     1            1           5m46s
deployment.apps/mysql                                         1/1     1            1           5m48s
deployment.apps/notebook-controller-deployment                1/1     1            1           5m49s
deployment.apps/profiles-deployment                           1/1     1            1           5m47s
deployment.apps/pytorch-operator                              1/1     1            1           5m49s
deployment.apps/seldon-controller-manager                     1/1     1            1           5m46s
deployment.apps/spark-operatorsparkoperator                   1/1     1            1           5m50s
deployment.apps/spartakus-volunteer                           1/1     1            1           5m49s
deployment.apps/tensorboard                                   1/1     1            1           5m49s
deployment.apps/tf-job-operator                               1/1     1            1           5m48s
deployment.apps/workflow-controller                           1/1     1            1           5m51s

NAME                                                                     DESIRED   CURRENT   READY   AGE
replicaset.apps/admission-webhook-deployment-64cb96ddbf                  1         1         1       5m50s
replicaset.apps/alb-ingress-controller-c76dd95d                          1         1         1       5m45s
replicaset.apps/argo-ui-778676df64                                       1         1         1       5m51s
replicaset.apps/centraldashboard-7dd7dd685d                              1         1         1       5m51s
replicaset.apps/jupyter-web-app-deployment-89789fd5                      1         1         1       5m50s
replicaset.apps/katib-controller-6b789b6cb5                              1         1         1       5m48s
replicaset.apps/katib-db-manager-64f548b47c                              1         1         1       5m48s
replicaset.apps/katib-mysql-57884cb488                                   1         1         1       5m48s
replicaset.apps/katib-ui-5c5cc6bd77                                      1         1         1       5m48s
replicaset.apps/metadata-db-76c9f78f77                                   1         1         1       5m49s
replicaset.apps/metadata-deployment-674fdd976b                           1         1         1       5m49s
replicaset.apps/metadata-envoy-deployment-5688989bd6                     1         1         1       5m49s
replicaset.apps/metadata-grpc-deployment-5579bdc87b                      1         1         1       5m49s
replicaset.apps/metadata-ui-9b8cd699d                                    1         1         1       5m49s
replicaset.apps/minio-755ff748b                                          1         1         1       5m47s
replicaset.apps/ml-pipeline-79b4f85cbc                                   1         1         1       5m47s
replicaset.apps/ml-pipeline-ml-pipeline-visualizationserver-5fdffdc5bf   1         1         1       5m46s
replicaset.apps/ml-pipeline-persistenceagent-645cb66874                  1         1         1       5m47s
replicaset.apps/ml-pipeline-scheduledworkflow-6c978b6b85                 1         1         1       5m46s
replicaset.apps/ml-pipeline-ui-6995b7bccf                                1         1         1       5m47s
replicaset.apps/ml-pipeline-viewer-controller-deployment-8554dc7b9f      1         1         1       5m46s
replicaset.apps/mpi-operator-5bf8b566b7                                  1         1         1       5m45s
replicaset.apps/mysql-598bc897dc                                         1         1         1       5m47s
replicaset.apps/notebook-controller-deployment-7db57b9ccf                1         1         1       5m49s
replicaset.apps/profiles-deployment-b45dbc6f                             1         1         1       5m46s
replicaset.apps/pytorch-operator-5fd5f94bdd                              1         1         1       5m49s
replicaset.apps/seldon-controller-manager-679fc777cd                     1         1         1       5m45s
replicaset.apps/spark-operatorsparkoperator-c7b64b87f                    1         1         1       5m50s
replicaset.apps/spartakus-volunteer-5b7d86d9cd                           1         1         1       5m49s
replicaset.apps/tensorboard-6544748d94                                   1         1         1       5m48s
replicaset.apps/tf-job-operator-7d7c8fb8bb                               1         1         1       5m48s
replicaset.apps/workflow-controller-945c84565                            1         1         1       5m51s

NAME                                                        READY   AGE
statefulset.apps/admission-webhook-bootstrap-stateful-set   1/1     5m50s
statefulset.apps/application-controller-stateful-set        1/1     6m32s
statefulset.apps/metacontroller                             1/1     5m51s

NAME                                  COMPLETIONS   DURATION   AGE
job.batch/spark-operatorcrd-cleanup   1/1           42s        5m50s
</codes></pre>
</details>


#### 可选操作：创建profile

Kubeflow提供多租户支持，用户无法在Kubeflow的默认名称空间中创建笔记本。

第一次访问kubeflow时，可以使用一个匿名命名空间。如果您想要创建不同的jupter用户空间，您可以创建配置文件，然后运行kubectl apply -f Profile .yaml。kubeflow配置文件控制器将创建新的名称空间和服务帐户，允许在该名称空间中创建笔记本。

```yaml
apiVersion: kubeflow.org/v1beta1
kind: Profile
metadata:
  name: aws-sample-user
spec:
  owner:
    kind: User
    name: aws-sample-user
```

