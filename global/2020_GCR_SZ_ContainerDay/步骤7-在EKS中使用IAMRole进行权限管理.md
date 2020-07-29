# 步骤7 在EKS中使用IAM Role进行权限管理
我们将要为ServiceAccount配置一个S3的访问角色，并且部署一个job应用到EKS集群，完成S3的写入。



7.1 配置IAM Role、ServiceAccount

>7.1.1 使用eksctl 创建service account 

```bash
# 在步骤3我们已经创建了OIDC身份提供商 
# 请检查IAM OpenID Connect (OIDC) 身份提供商是否已经创建
aws eks describe-cluster --name ${CLUSTER_NAME} --query cluster.identity.oidc.issuer --output text
# 如果上述命令无输出，请执行以下命令创建OpenID Connect (OIDC) 身份提供商
#eksctl utils associate-iam-oidc-provider --cluster=${CLUSTER_NAME} --approve --region ${AWS_REGION}

#创建serviceaccount s3-echoer with IAM role
eksctl create iamserviceaccount --name s3-echoer --namespace default \
    --cluster ${CLUSTER_NAME} --attach-policy-arn arn:aws-cn:iam::aws:policy/AmazonS3FullAccess \
    --approve --override-existing-serviceaccounts 

```

7.2 部署测试访问S3的应用
*使用已有s3 bucket或创建s3 bucket, 请确保bucket名字唯一才能创建成功.

```bash
# 设置环境变量TARGET_BUCKET,Pod访问的S3 bucket
TARGET_BUCKET=eksworkshop-irsa-2020
if [ $(aws s3 ls | grep $TARGET_BUCKET | wc -l) -eq 0 ]; then
    aws s3api create-bucket  --bucket $TARGET_BUCKET   --create-bucket-configuration LocationConstraint=$AWS_DEFAULT_REGION  --region $AWS_DEFAULT_REGION
else
    echo "S3 bucket $TARGET_BUCKET existed, skip creation"
fi

# 修改Region,部署Job
sed -e "s/TARGET_BUCKET/${TARGET_BUCKET}/g;s/us-west-2/${AWS_DEFAULT_REGION}/g" s3-echoer/s3-echoer-job.yaml.template > s3-echoer/s3-echoer-job.yaml
kubectl apply -f s3-echoer/s3-echoer-job.yaml

# 验证
kubectl get job/s3-echoer
kubectl logs job/s3-echoer
## 参考输出
Uploading user input to S3 using eksworkshop-irsa-2019/s3echoer-1583415691

# 检查S3 bucket上面的文件
aws s3api list-objects --bucket $TARGET_BUCKET --query 'Contents[].{Key: Key, Size: Size}'  
[
    {
        "Key": "s3echoer-1583415691",
        "Size": 27
    }
]

#清理
kubectl delete job/s3-echoer
```

7.3 部署第二个IAM 权限测试Pod(可选)

```bash
cd china/2020_EKS_Launch_Workshop/resource/

# Apply the testing
kubectl apply -f IRSA/iam-pod.yaml
pod/s3-echoer created created

kubectl get pod  s3-echoer
NAME                            READY   STATUS    RESTARTS   AGE
s3-echoer                       1/1     Running   0          2m38s

# 验证IAM Role 是否生效
kubectl exec -it s3-echoer bash
# In promote input, the output Arn should looks like assumed-role/eksctl-gcr-zhy-eksworkshop-addon-iamservicea-Role
aws sts get-caller-identity
# output shoudld list all the S3 bucket in AWS_REGION under the account 
aws s3 ls
aws ec2 describe-instances
# output should be like: An error occurred (UnauthorizedOperation) when calling the DescribeInstances operation: You are not authorized to perform this operation.

# cleanup
kubectl delete -f IRSA/iam-pod.yaml

```
