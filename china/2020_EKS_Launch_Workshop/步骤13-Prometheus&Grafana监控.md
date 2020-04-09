13.1 前提条件

检查Helm是否已安装

```
helm list
```
如未安装Helm，请参照" 步骤9-使用Helm部署应用/9.1 Install Helm "安装Helm，并添加stable repository

```
helm repo add stable https://burdenbear.github.io/kube-charts-mirror/
```
13.2 部署Prometheus

安装Prometheus

```
kubectl create namespace prometheus
helm install prometheus stable/prometheus \
    --namespace prometheus \
    --set alertmanager.persistentVolume.storageClass="gp2" \
    --set server.persistentVolume.storageClass="gp2"
```
留意Prometheus endpoint，后续步骤会使用到

```
The Prometheus server can be accessed via port 80 on the following DNS name from within your cluster:
prometheus-server.prometheus.svc.cluster.local
```
查看Prometheus组件是否部署成功

```
kubectl get all -n prometheus

```
参考输出，所有组件应该是Running或Available状态

```
NAME                                                 READY     STATUS    RESTARTS   AGE
pod/prometheus-alertmanager-77cfdf85db-s9p48         2/2       Running   0          1m
pod/prometheus-kube-state-metrics-74d5c694c7-vqtjd   1/1       Running   0          1m
pod/prometheus-node-exporter-6dhpw                   1/1       Running   0          1m
pod/prometheus-node-exporter-nrfkn                   1/1       Running   0          1m
pod/prometheus-node-exporter-rtrm8                   1/1       Running   0          1m
pod/prometheus-pushgateway-d5fdc4f5b-dbmrg           1/1       Running   0          1m
pod/prometheus-server-6d665b876-dsmh9                2/2       Running   0          1m

NAME                                    TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)    AGE
service/prometheus-alertmanager         ClusterIP   10.100.89.154    <none>        80/TCP     1m
service/prometheus-kube-state-metrics   ClusterIP   None             <none>        80/TCP     1m
service/prometheus-node-exporter        ClusterIP   None             <none>        9100/TCP   1m
service/prometheus-pushgateway          ClusterIP   10.100.136.143   <none>        9091/TCP   1m
service/prometheus-server               ClusterIP   10.100.151.245   <none>        80/TCP     1m

NAME                                      DESIRED   CURRENT   READY     UP-TO-DATE   AVAILABLE   NODE SELECTOR   AGE
daemonset.apps/prometheus-node-exporter   3         3         3         3            3           <none>          1m

NAME                                            DESIRED   CURRENT   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/prometheus-alertmanager         1         1         1            1           1m
deployment.apps/prometheus-kube-state-metrics   1         1         1            1           1m
deployment.apps/prometheus-pushgateway          1         1         1            1           1m
deployment.apps/prometheus-server               1         1         1            1           1m

NAME                                                       DESIRED   CURRENT   READY     AGE
replicaset.apps/prometheus-alertmanager-77cfdf85db         1         1         1         1m
replicaset.apps/prometheus-kube-state-metrics-74d5c694c7   1         1         1         1m
replicaset.apps/prometheus-pushgateway-d5fdc4f5b           1         1         1         1m
replicaset.apps/prometheus-server-6d665b876                1         1         1         1m

```

创建NodePort类型的Service，用于访问Prometheus

```
cat << EOF > ./prometheus-service.yml
apiVersion: v1
kind: Service
metadata:
  labels:
    app: prometheus
    chart: prometheus-11.0.4
    component: server
    heritage: Helm
    release: prometheus
  name: prometheus-nginx
  namespace: prometheus
spec:
  ports:
  - port: 9090
    protocol: TCP
    targetPort: 9090
  selector:
    app: prometheus
    component: server
    release: prometheus
  type: ClusterIP
EOF

kubectl apply -f prometheus-service.yml
```
通过Kube-proxy访问Prometheus

```
kubectl proxy --port=8080 --address='0.0.0.0' --disable-filter=true
```
打开浏览器，将\<localhost>替换为本机ip，访问Prometheus

```
http://<localhost>:8080/api/v1/namespaces/prometheus/services/prometheus-nginx/proxy/graph

```
依次选择Status/Targets，在UI中查看Prometheus监控的所有对象和指标

![avatar](https://github.com/toreydai/eks-workshop-greater-china/blob/master/china/2020_EKS_Launch_Workshop/media/Pictures/prometheus1.png)

13.3 部署Grafana

在部署参数中，将datasource指向Prometheus，并为Grafana创建LoadBalancer

```
kubectl create namespace grafana
helm install grafana stable/grafana \
    --namespace grafana \
    --set persistence.storageClassName="gp2" \
    --set adminPassword='EKS!sAWSome' \
    --set datasources."datasources\.yaml".apiVersion=1 \
    --set datasources."datasources\.yaml".datasources[0].name=Prometheus \
    --set datasources."datasources\.yaml".datasources[0].type=prometheus \
    --set datasources."datasources\.yaml".datasources[0].url=http://prometheus-server.prometheus.svc.cluster.local \
    --set datasources."datasources\.yaml".datasources[0].access=proxy \
    --set datasources."datasources\.yaml".datasources[0].isDefault=true \
    --set service.type=LoadBalancer
```
查看Grafana是否部署成功

```
kubectl get all -n grafana

```
参考输出，所有组件应该是Running或Available状态

```
NAME                          READY     STATUS    RESTARTS   AGE
pod/grafana-b9697f8b5-t9w4j   1/1       Running   0          2m

NAME              TYPE           CLUSTER-IP       EXTERNAL-IP                                                               PORT(S)        AGE
service/grafana   LoadBalancer   10.100.49.172   abe57f85de73111e899cf0289f6dc4a4-1343235144.us-west-2.elb.amazonaws.com   80:31570/TCP   3m


NAME                      DESIRED   CURRENT   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/grafana   1         1         1            1           2m

NAME                                DESIRED   CURRENT   READY     AGE
replicaset.apps/grafana-b9697f8b5   1         1         1         2m

```
获取Grafana ELB URL，将输出复制粘贴到浏览器中进行访问

```
export ELB=$(kubectl get svc -n grafana grafana -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

echo "http://$ELB"
```
使用用户名admin和如下命令获取的password hash登陆

```
kubectl get secret --namespace grafana grafana -o jsonpath="{.data.admin-password}" | base64 --decode ; echo
```
13.4 查看监控面板

13.4.1 创建集群监控面板

* 左侧面板点击' + '，选择' Import  '
* Grafana.com Dashboard下输入3119
* prometheus data source下拉框中选择prometheus
* 点击' Import  '

![avatar](https://github.com/toreydai/eks-workshop-greater-china/blob/master/china/2020_EKS_Launch_Workshop/media/Pictures/prometheus2.png)

查看所有集群节点的监控面板

![avatar](https://github.com/toreydai/eks-workshop-greater-china/blob/master/china/2020_EKS_Launch_Workshop/media/Pictures/prometheus3.png)

13.4.2 创建Pods监控面板

* 左侧面板点击' + '，选择' Import  '
* Grafana.com Dashboard下输6417
*  输入Kubernetes Pods Monitoring作为Dashboard名称
*  点击change，设置uid
* prometheus data source下拉框中选择prometheus
* 点击' Import  '

![avatar](https://github.com/toreydai/eks-workshop-greater-china/blob/master/china/2020_EKS_Launch_Workshop/media/Pictures/prometheus4.png)

查看Pods的监控面板

![avatar](https://github.com/toreydai/eks-workshop-greater-china/blob/master/china/2020_EKS_Launch_Workshop/media/Pictures/prometheus5.png)

13.5 清理环境

```
helm uninstall prometheus --namespace prometheus
helm uninstall grafana --namespace grafana
kubectl delete namespace prometheus
kubectl delete namespace grafana
```
