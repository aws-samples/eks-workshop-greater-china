# 步骤5：在EKS中使用IAM Role进行权限管理(可选)
我们将要为ServiceAccount配置一个S3的访问角色，并且部署一个job应用到EKS集群，完成S3的写入。

5.1 配置IAM Role、ServiceAccount

```bash
#创建OIDC身份提供商 
eksctl utils associate-iam-oidc-provider --cluster eksworkshop --approve

#创建serviceaccount s3-echoer with IAM role
eksctl create iamserviceaccount --name s3-echoer --cluster eksworkshop --attach-policy-arn arn:aws:iam::aws:policy/AmazonS3FullAccess --approve

```

 5.2 部署测试应用
*请确保bucket名字唯一,s3 bucket才能创建成功

```bash
#获取测试应用源代码
git clone https://github.com/mhausenblas/s3-echoer.git && cd s3-echoer

#请替换<user_name> 
TARGET_BUCKET=<user_name>-irsa-2019

aws s3api create-bucket  --bucket $TARGET_BUCKET  --create-bucket-configuration LocationConstraint=$AWS_DEFAULT_REGION  --region $AWS_DEFAULT_REGION

#替换模版里面的BUCKET名字和Region
sed -e "s/TARGET_BUCKET/${TARGET_BUCKET}/g;s/us-west-2/${AWS_DEFAULT_REGION}/g" s3-echoer-job.yaml.template > s3-echoer-job.yaml

#部署job到eks集群
kubectl apply -f s3-echoer-job.yaml
#查看job是否完成
kubectl get job 

#查看bucket是否有文件生成
aws s3api list-objects --bucket $TARGET_BUCKET --query 'Contents[].{Key: Key, Size: Size}'

```
