# 步骤7 在EKS中使用IAM Role进行权限管理
我们将要为ServiceAccount配置一个S3的访问角色，并且部署一个job应用到EKS集群，完成S3的写入。

[官方文档](https://aws.amazon.com/blogs/opensource/introducing-fine-grained-iam-roles-service-accounts/)

7.1 配置IAM Role、ServiceAccount

>7.1.1 使用eksctl 创建service account 

```bash
# 在步骤3我们已经创建了OIDC身份提供商 
# 请检查IAM Open ID Connect provider已经创建
aws eks describe-cluster --name ${CLUSTER_NAME} --region ${AWS_REGION} --query cluster.identity.oidc.issuer --output text
# 如果上述命令无输出，run below command to create one
eksctl utils associate-iam-oidc-provider --cluster=${CLUSTER_NAME} --approve --region ${AWS_REGION}

#创建serviceaccount s3-echoer with IAM role
eksctl create iamserviceaccount --name s3-echoer --namespace default \
    --cluster ${CLUSTER_NAME} --attach-policy-arn arn:aws-cn:iam::aws:policy/AmazonS3FullAccess \
    --approve --override-existing-serviceaccounts --region ${AWS_REGION}

```

7.2 部署测试访问S3的应用
*请确保bucket名字唯一,s3 bucket才能创建成功

```bash
git clone https://github.com/mhausenblas/s3-echoer.git && cd s3-echoer

# 准备S3 bucket
TARGET_BUCKET=eksworkshop-irsa-2019
if [ $(aws s3 ls | grep $TARGET_BUCKET | wc -l) -eq 0 ]; then
    aws s3api create-bucket  --bucket $TARGET_BUCKET  --create-bucket-configuration LocationConstraint=$AWS_REGION  --region $AWS_REGION
else
    echo "S3 bucket $TARGET_BUCKET existed, skip creation"
fi

# 修改Region,部署Job
sed -e "s/TARGET_BUCKET/${TARGET_BUCKET}/g;s/us-west-2/${AWS_REGION}/g" s3-echoer-job.yaml.template > s3-echoer-job.yaml
kubectl apply -f s3-echoer-job.yaml

# 验证
kubectl get job/s3-echoer
kubectl logs job/s3-echoer
## 参考输出
Uploading user input to S3 using eksworkshop-irsa-2019/s3echoer-1583415691

# 检查S3 bucket上面的文件
aws s3api list-objects --bucket $TARGET_BUCKET --query 'Contents[].{Key: Key, Size: Size}'  --region $AWS_REGION
[
    {
        "Key": "s3echoer-1583415691",
        "Size": 27
    }
]

#清理
kubectl delete job/s3-echoer
```

7.3 部署第二个测试应用
```bash
# download pod yaml
curl -LO https://eksworkshop.com/beginner/110_irsa/deploy.files/iam-pod.yaml
# replace the serviceAccountName: s3-echoer
# add the env AWS_DEFAULT_REGION or AWS_REGION to resolve issue: An error occurred (InvalidIdentityToken) when calling the AssumeRoleWithWebIdentity operation: No OpenIDConnect provider found in your account for

# Apply the testing
kubectl apply -f iam-pod.yaml
deployment.apps/eks-iam-test created

kubectl get pod -l app=eks-iam-test
NAME                            READY   STATUS    RESTARTS   AGE
eks-iam-test-76cfbb6fdc-qqn7m   1/1     Running   0          85s

# verify the sa work
kubectl exec -it <place Pod Name> /bin/bash
# In promote input, the output Arn should looks like assumed-role/eksctl-gcr-zhy-eksworkshop-addon-iamservicea-Role
aws sts get-caller-identity
# output shoudld list all the S3 bucket in AWS_REGION under the account 
aws s3 ls
aws ec2 describe-instances
# output should be like: An error occurred (UnauthorizedOperation) when calling the DescribeInstances operation: You are not authorized to perform this operation.

# cleanup
kubectl delete -f iam-pod.yaml

```
