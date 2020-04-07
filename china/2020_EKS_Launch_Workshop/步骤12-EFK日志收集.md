1.配置工作线程节点的权限

获取工作线程节点Role ARN

```
STACK_NAME=$(eksctl get nodegroup --cluster eksworkshop -o json | jq -r '.[].StackName')
ROLE_NAME=$(aws cloudformation describe-stack-resources --stack-name $STACK_NAME | jq -r '.StackResources[] | select(.ResourceType=="AWS::IAM::Role") | .PhysicalResourceId')
echo "export ROLE_NAME=${ROLE_NAME}" | tee -a ~/.bash_profile
```
创建权限Policy文件，主要是CloudWatch Logs权限

```
cat <<EoF > ./k8s-logs-policy.json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": [
                "logs:DescribeLogGroups",
                "logs:DescribeLogStreams",
                "logs:CreateLogGroup",
                "logs:CreateLogStream",
                "logs:PutLogEvents"
            ],
            "Resource": "*",
            "Effect": "Allow"
        }
    ]
}
EoF
```
为工作线程节点Role增加CloudWatch Logs权限

```
aws iam put-role-policy --role-name $ROLE_NAME \
--policy-name Logs-Policy-For-Worker \
--policy-document file://./k8s-logs-policy.json
```

查看Policy是否已附加到工作线程节点Role

```
aws iam get-role-policy --role-name $ROLE_NAME \
--policy-name Logs-Policy-For-Worker
```
2.创建Amazon Elasticsearch Service

使用CLI命令行创建一个包含2节点的Elasticsearch Domain

```
aws es create-elasticsearch-domain \
  --domain-name kubernetes-logs \
  --elasticsearch-version 7.4 \
  --elasticsearch-cluster-config \
  InstanceType=m5.large.elasticsearch,InstanceCount=2 \
  --ebs-options EBSEnabled=true,VolumeType=standard,VolumeSize=100 \
  --access-policies '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"AWS":["*"]},"Action":["es:*"],"Resource":"*"}]}'
```
查看Elasticsearch Domian创建状态

```
aws es describe-elasticsearch-domain --domain-name kubernetes-logs \
--query 'DomainStatus.Processing'
```

3.部署Fluentd

下载Fluentd.yml文件

```
wget https://eksworkshop.com/intermediate/230_logging/deploy.files/fluentd.yml
```
将env中的REGION和CLUSTER_NAME修改为当前环境的值

```
    env:
      - name: REGION
        value: cn-northwest-1
      - name: CLUSTER_NAME
        value: eksworkshop
```
部署Fluentd

```
kubectl apply -f ./fluentd.yml
```
观察Fluentd Pod状态，直到其处于Running状态

```
kubectl get pods -w --namespace=kube-system
```
4.将CloudWatch Logs流式传输到Elasticsearch

创建传输过程中使用的Lambda附加的Role:*lambda_basic\_execution*

```
cat <<EoF > ~/efk/lambda-policy.json
{
   "Version": "2012-10-17",
   "Statement": [
   {
     "Effect": "Allow",
     "Principal": {
        "Service": "lambda.amazonaws.com"
     },
   "Action": "sts:AssumeRole"
   }
 ]
}
EoF
aws iam create-role --role-name lambda_basic_execution --assume-role-policy-document file://~/lambda-policy.json
aws iam attach-role-policy --role-name lambda_basic_execution --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole
```
为lambda_basic_execution增加Elasticsarch相关权限

注意：需要将'Resource'修改为新建的Elasticsearch Domain的ARN

```
cat <<EoF > ./lambda-es-policy.json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": [
                "es:*"
            ],
            "Effect": "Allow",
            "Resource": "arn:aws-cn:es:region:account-id:domain/target-domain-name/*"
        }
    ]
}
EoF
aws iam put-role-policy --role-name lambda_basic_execution --policy-name lambda-es-policy --policy-document file://./lambda-es-policy.json
aws iam get-role-policy --role-name lambda_basic_execution--policy-name lambda-es-policy
```

登陆AWS Console进行操作，选择log group: */eks/eksworkshop-eksctl/containers*
![avatar](https://github.com/toreydai/eks-workshop-greater-china/blob/master/china/2020_EKS_Launch_Workshop/media/Pictures/efk1.png)
![avatar](https://github.com/toreydai/eks-workshop-greater-china/blob/master/china/2020_EKS_Launch_Workshop/media/Pictures/efk2.png)
选择Elasticsearch Cluster *kubernetes-logs* 和IAM Role *lambda_basic\_execution*
![avatar](https://github.com/toreydai/eks-workshop-greater-china/blob/master/china/2020_EKS_Launch_Workshop/media/Pictures/efk3.png)
选择*Comm log Format*
![avatar](https://github.com/toreydai/eks-workshop-greater-china/blob/master/china/2020_EKS_Launch_Workshop/media/Pictures/efk4.png)
查看所有配置，点击*Start Streaming*
![avatar](https://github.com/toreydai/eks-workshop-greater-china/blob/master/china/2020_EKS_Launch_Workshop/media/Pictures/efk5.png)
打开Lambda函数界面，选择函数*LogsToElasticsearch_kubernetes-logs*，修改正文中
*function buildRequest*中的*var endpointParts*

```
var endpointParts = endpoint.match(/^([^\.]+)\.?([^\.]*)\.?([^\.]*)\.amazonaws\.com$/);
修改为：
var endpointParts = endpoint.match(/^([^\.]+)\.?([^\.]*)\.?([^\.]*)\.amazonaws\.com\.cn$/);

```
打开Elasticsearch界面，选择*kubernetes-logs*
![avatar](https://github.com/toreydai/eks-workshop-greater-china/blob/master/china/2020_EKS_Launch_Workshop/media/Pictures/efk6.png)
打开Kibana URL，几分钟后，ES中将会采集到数据。
<br>将索引规则设置为 *cwl-**
![avatar](https://github.com/toreydai/eks-workshop-greater-china/blob/master/china/2020_EKS_Launch_Workshop/media/Pictures/efk7.png)
下拉菜单中选择*@timestamp*，并创建索引规则
![avatar](https://github.com/toreydai/eks-workshop-greater-china/blob/master/china/2020_EKS_Launch_Workshop/media/Pictures/efk8.png)
![avatar](https://github.com/toreydai/eks-workshop-greater-china/blob/master/china/2020_EKS_Launch_Workshop/media/Pictures/efk9.png)
点击发现，以探索日志
![avatar](https://github.com/toreydai/eks-workshop-greater-china/blob/master/china/2020_EKS_Launch_Workshop/media/Pictures/efk10.png)

5.清理环境
```
kubectl delete -f ./fluentd.yml
aws es delete-elasticsearch-domain --domain-name kubernetes-logs
aws logs delete-log-group --log-group-name /eks/eksworkshop/containers
```





