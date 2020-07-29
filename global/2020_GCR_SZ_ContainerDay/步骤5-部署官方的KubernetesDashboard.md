# 步骤5 部署官方的Kubernetes dashboard

5.1 下载配置文件

```bash
#2.0.0rc3
kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.0.0-rc3/aio/deploy/recommended.yaml

#kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v1.10.1/src/deploy/recommended/kubernetes-dashboard.yaml

kubectl get pods -n kube-system
kubectl get services -n kube-system

#方法1 通过kubectl proxy 进行访问
#由于我们部署的EKS cluster是private cluster，所以我们需要通过 proxy. Kube-proxy进行访问Dashboard
kubectl proxy --port=8080 --address='0.0.0.0' --disable-filter=true &

#通过proxy进行访问
http://localhost:8080/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/#!/login


#获取登录的token
aws eks get-token --cluster-name ${CLUSTER_NAME} --region ${AWS_REGION} | jq -r '.status.token'

#登录
#在cloud9里面选择tools -> preview -> preview run application

选择 Dashbaord 登录页面的 “Token” 单选按钮，复制上述命令的输出，粘贴，之后点击 Sign In。


#方法2 将Dashboard 服务类型从默认的cluster 修改为LoadBalancer 通过AWS ELB提供对外服务,生产系统不推荐
kubectl apply -f resource/dashboard/loadbalancer-recommended.yaml

#获取Dashboard访问地址
kubectl get svc kubernetes-dashboard -n kubernetes-dashboard -o json |  jq -r '.status.loadBalancer.ingress[].hostname'
#使用firefox 打开上述地址

```



![image-20200728161147477](/Users/wsuam/Library/Application Support/typora-user-images/image-20200728161147477.png)



**注意:** 新版本的chrome浏览器会禁止使用自签名https访问,所以推荐使用firefox访问dashboard

登录界面, 通过"aws eks get-token" 获取的TOKEN登录

```bash
aws eks get-token --cluster-name ${CLUSTER_NAME} --region ${AWS_REGION} | jq -r '.status.token'
```



![image-20200728161032875](/Users/wsuam/Library/Application Support/typora-user-images/image-20200728161032875.png)