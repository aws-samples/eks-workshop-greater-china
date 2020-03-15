# 步骤3 部署官方的Kubernetes dashboard

3.1 下载配置文件

```bash
# 如果采用了2.4 中的镜像webhook，直接进行部署，否则需要修改kubernetes-dashboard.yaml中镜像位置为国内Mirror，否则部署会因为Image无法下载而失败
kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v1.10.1/src/deploy/recommended/kubernetes-dashboard.yaml
kubectl get pods -n kube-system
kubectl get services -n kube-system

#由于我们部署的EKS cluster是private cluster，所以我们需要通过 proxy. Kube-proxy进行访问Dashboard
kubectl proxy --port=8080 --address='0.0.0.0' --disable-filter=true &

#访问
http://localhost:8080//api/v1/namespaces/kube-system/services/https:kubernetes-dashboard:/proxy/#!/login

#获取登录的token
aws eks get-token --cluster-name ${CLUSTER_NAME} --region ${AWS_REGION} | jq -r '.status.token'

#登录
选择 Dashbaord 登录页面的 “Token” 单选按钮，复制上述命令的输出，粘贴，之后点击 Sign In。
```

