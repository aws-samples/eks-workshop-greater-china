# 多容器管理实践(可选)

在上一节中，我们从一个简单的静态网站开始，然后尝试了Flask应用。只需少量命令，我们都可以在本地和云中运行这两种方法。这两个应用程序的共同点是它们在单个容器中运行。

那些具有在生产环境中运行服务的经验的人知道，如今通常应用程序并不那么简单。几乎总是涉及一个数据库（或任何其他类型的持久性存储）。 Redis和Memcached之类的系统已成为大多数Web应用程序体系结构的基础。因此，在本节中，我们将花费一些时间来学习如何对依赖于不同服务的应用程序进行Dockerize。

我们将要用于Dockerize的应用程序称为Food Trucks。我构建这个应用程序的目标是要有一个有用的东西（因为它类似于真实世界的应用程序），至少依赖一项服务，但对于本教程而言并不太复杂。

首先，让我们进入我们的程序文件目录

```
cd docker-workshop/2-advanced/
```

其中，flask-app文件夹包含Python应用程序，而utils文件夹具有一些实用程序，可将数据加载到Elasticsearch中。该目录还包含一些YAML文件和一个Dockerfile，我们将在本教程中逐步详细介绍所有这些文件。

让我们考虑如何对应用程序进行Docker化。我们可以看到该应用程序由Flask后端服务器和Elasticsearch服务组成。拆分此应用的自然方法是拥有两个容器-一个运行Flask进程，另一个运行Elasticsearch（ES）进程。这样，如果我们的应用程序变得越来越多人用，我们可以根据瓶颈所在的位置添加更多容器来扩展它。因此我们需要两个容器。在上一节中，我们已经构建了自己的Flask容器。对于Elasticsearch，让我们看看是否可以在Docker Hub上找到合适的镜像。

```
docker search elasticsearch
```

Elasticsearch存在官方支持的镜像。为了使ES运行，我们可以简单地使用docker run并让一个单节点ES容器立即在本地运行。

```
docker pull docker.elastic.co/elasticsearch/elasticsearch:6.3.2
```

然后通过指定端口并设置一个环境变量将其运行在开发模式下，该环境变量将Elasticsearch集群配置为作为单节点运行。

```
docker run -d --rm --name es -p 9200:9200 -p 9300:9300 -e "discovery.type=single-node" docker.elastic.co/elasticsearch/elasticsearch:6.3.2
```

如上所示，我们使用--name es为我们的容器命名，这使得在后续命令中易于使用。启动容器后，我们可以通过运行带有容器名称（或ID）的`docker logs -f <镜像id>`来查看日志，以查看日志。如果Elasticsearch成功启动，您应该看到类似于以下的日志。

```
docker logs -f <镜像id>
```

现在，让我们尝试看看是否可以向Elasticsearch容器发送请求。我们使用9200端口将`cURL`请求发送到容器。

```
$ curl 0.0.0.0:9200
{
  "name" : "kg_udER",
  "cluster_name" : "docker-cluster",
  "cluster_uuid" : "QTuIzSsKTM2dzdf1zojwKQ",
  "version" : {
    "number" : "6.3.2",
    "build_flavor" : "default",
    "build_type" : "tar",
    "build_hash" : "053779d",
    "build_date" : "2018-07-20T05:20:23.451332Z",
    "build_snapshot" : false,
    "lucene_version" : "7.3.1",
    "minimum_wire_compatibility_version" : "5.6.0",
    "minimum_index_compatibility_version" : "5.0.0"
  },
  "tagline" : "You Know, for Search"
}
```

看起来不错！在此过程中，让我们也运行Flask容器。但在此之前，我们需要一个Dockerfile。在上一节中，我们使用python：3图像作为基本镜像。但是，这次，除了通过pip安装Python依赖项之外，我们还希望我们的应用程序还生成用于生产的小型Javascript文件。为此，我们将需要Nodejs。由于我们需要自定义构建步骤，因此我们将从ubuntu基本镜像开始，从头开始构建Dockerfile。

可以直接通过Cloud9编辑器打开`2-advanced/Dockerfile`

```
# start from base
FROM ubuntu:18.04

LABEL maintainer="Prakhar Srivastav <prakhar@prakhar.me>"

# install system-wide deps for python and node
RUN apt-get -yqq update
RUN apt-get -yqq install python3-pip python3-dev curl gnupg
RUN curl -sL https://deb.nodesource.com/setup_10.x | bash
RUN apt-get install -yq nodejs

# copy our application code
ADD flask-app /opt/flask-app
WORKDIR /opt/flask-app

# fetch app specific deps
RUN npm install
RUN npm run build
RUN pip3 install -r requirements.txt

# expose port
EXPOSE 5000

# start app
CMD [ "python3", "./app.py" ]
```

让我们快速浏览一下此文件。我们从Ubuntu LTS基本镜像开始，然后使用软件包管理器apt-get安装依赖项-Python和Node。

然后，我们使用ADD命令将应用程序复制到容器中的新卷`/opt/flask-app`。这是我们的代码所在的位置。我们还将其设置为工作目录，以便在该位置的上下文中运行以下命令。现在，我们已安装了系统范围的依赖项，接下来我们将逐步安装特定于应用程序的依赖项。首先，我们通过从npm安装软件包并运行`package.json`文件中定义的build命令来安装Node。我们通过安装Python软件包，暴露端口并定义CMD来运行文件。

最后，我们可以继续构建镜像并运行容器

```
docker build -t nikosheng/foodtrucks-web .
```

构建完成后，让我们尝试运行我们的应用程序。

```
$ docker run -P --rm nikosheng/foodtrucks-web
Unable to connect to ES. Retrying in 5 secs...
Unable to connect to ES. Retrying in 5 secs...
Unable to connect to ES. Retrying in 5 secs...
Out of retries. Bailing out...
```

糟糕！由于无法连接到Elasticsearch，我们的flask应用程序无法运行。我们如何将一个容器联通另一个容器，并让他们彼此互通？

### 如果对于Docker比较熟悉的小伙伴可以挑战一下，可以根据项目里面的代码去自己实现解决方法。如果第一次接触Docker的小伙伴，可以展开下面的折叠块来跟随教程一步一步完成实验。

<details>
<summary>查看解决方案</summary>
<pre>

## Docker Network

在讨论Docker用于处理此类情况的功能之前，让我们先看看是否可以找到解决问题的方法。希望这会使您对我们将要研究的能有所了解。

好的，让我们运行`docker container ls`（与`docker ps`相同），看看有什么。

```
admin:~/environment $ docker ps
CONTAINER ID        IMAGE                                                 COMMAND                  CREATED             STATUS              PORTS                                            NAMES
b17bd4d6a319        docker.elastic.co/elasticsearch/elasticsearch:6.3.2   "/usr/local/bin/dock…"   20 minutes ago      Up 20 minutes       0.0.0.0:9200->9200/tcp, 0.0.0.0:9300->9300/tcp   es
admin:~/environment $ 
```

因此，我们有一个ES容器运行在0.0.0.0:9200端口上，我们可以直接访问该容器。如果我们可以告诉Flask应用连接到该URL，则它应该可以连接并与ES通信。让我们深入研究Python代码，看看如何定义连接的详细信息。

让我们打开`2-advanced/flask-app/app.py`

```
es = Elasticsearch(host='es')
```

在代码中，我们需要告诉Flask容器，ES容器正在0.0.0.0主机上运行（默认端口为9200），这应该使它工作，对吗？不幸的是，这是不正确的，因为IP 0.0.0.0是从主机（localhost）访问ES容器的IP。另一个容器将无法在同一IP地址上访问它。如果不是该IP，那么ES容器应可访问哪个IP地址？

现在是开始探索Docker网络的好时机。安装docker后，它将自动创建三个网络。

```
admin:~/environment $ docker network ls
NETWORK ID          NAME                DRIVER              SCOPE
d037c38ecd83        bridge              bridge              local
6a3b3ab8c510        host                host                local
de2a13d13a7a        none                null                local
```

桥接网络(bridge)是默认情况下运行容器的网络。因此，这意味着当我运行ES容器时，它正在此桥接网络中运行。为了验证这一点，让我们检查网络。

```
admin:~/environment $ docker network inspect bridge
[
    {
        "Name": "bridge",
        "Id": "d037c38ecd83d19ab65cd70020b996e9a53dd9c31a457658b47c14208f483410",
        "Created": "2020-07-29T01:04:11.675105689Z",
        "Scope": "local",
        "Driver": "bridge",
        "EnableIPv6": false,
        "IPAM": {
            "Driver": "default",
            "Options": null,
            "Config": [
                {
                    "Subnet": "172.17.0.0/16",
                    "Gateway": "172.17.0.1"
                }
            ]
        },
        "Internal": false,
        "Attachable": false,
        "Ingress": false,
        "ConfigFrom": {
            "Network": ""
        },
        "ConfigOnly": false,
        "Containers": {
            "b17bd4d6a319e6206d47d9a5496d107a025c5cdfd7a37c64d7aa8e3570232b79": {
                "Name": "es",
                "EndpointID": "9944409131e57a61f18d86fab2e776126d42a2d20884b5c01ecfa7faecc385ce",
                "MacAddress": "02:42:ac:11:00:02",
                "IPv4Address": "172.17.0.2/16",
                "IPv6Address": ""
            }
        },
        "Options": {
            "com.docker.network.bridge.default_bridge": "true",
            "com.docker.network.bridge.enable_icc": "true",
            "com.docker.network.bridge.enable_ip_masquerade": "true",
            "com.docker.network.bridge.host_binding_ipv4": "0.0.0.0",
            "com.docker.network.bridge.name": "docker0",
            "com.docker.network.driver.mtu": "1500"
        },
        "Labels": {}
    }
]
```
您可以看到我们的容器`b17bd4d6a319`在输出的“容器”部分下列出。我们还看到的是此容器已分配的IP地址-172.17.0.2。这是我们要查找的IP地址吗？让我们通过运行Flask容器并尝试访问此IP来找出答案。

```
$ docker run -it --rm nikosheng/foodtrucks-web curl 172.17.0.2:9200
{
  "name" : "-ml6cJ3",
  "cluster_name" : "docker-cluster",
  "cluster_uuid" : "LoB0rDHaTqKMqoKMnnD2dA",
  "version" : {
    "number" : "6.3.2",
    "build_flavor" : "default",
    "build_type" : "tar",
    "build_hash" : "053779d",
    "build_date" : "2018-07-20T05:20:23.451332Z",
    "build_snapshot" : false,
    "lucene_version" : "7.3.1",
    "minimum_wire_compatibility_version" : "5.6.0",
    "minimum_index_compatibility_version" : "5.0.0"
  },
  "tagline" : "You Know, for Search"
}
```

我们可以直接在运行docker的时候加上我们希望容器执行的命令，我们看到我们确实可以在172.17.0.2:9200上与ES对话。Awesome！

尽管我们已经找到了一种使容器相互通信的方法，但是这种方法仍然存在两个问题

 - 我们如何告诉Flask容器es主机名代表172.17.0.2或其他IP，因为IP可能会随时变化

 - 由于默认情况下每个容器都共享桥接网络，因此此方法并不安全。我们如何隔离我们的网络？

好消息是Docker对我们的问题有很好的答案。它允许我们定义自己的网络，同时使用docker network命令将它们隔离。

首先，让我们创建自己的网络。

```
$ docker network create aws-net

$ docker network ls
NETWORK ID          NAME                DRIVER              SCOPE
a5e79e75b97b        aws-net             bridge              local
```

`docker network create`命令创建一个新的网桥网络，这是我们目前需要的。就Docker而言，网桥网络使用软件网桥，该软件网桥允许连接到同一网桥网络的容器进行通信，同时将未连接到该网桥网络的容器隔离。 Docker网桥驱动程序会自动在主机中部署规则，以使不同网桥网络上的容器无法直接相互通信。

现在我们有了一个自定义网络，我们可以使用--net标志在该网络内启动容器。但首先，为了启动具有相同名称的新容器，我们将停止并删除在网桥（默认）网络中运行的ES容器。

```
$ docker container stop es
es

$ docker container rm es
es

$ docker run -d --name es --net aws-net -p 9200:9200 -p 9300:9300 -e "discovery.type=single-node" docker.elastic.co/elasticsearch/elasticsearch:6.3.2

$ docker network inspect aws-net
[
    {
        "Name": "aws-net",
        "Id": "a5e79e75b97bddc921f59cc233e3d4fd47cf05753fe9cba833dcf6d0e39e9fb2",
        "Created": "2020-07-29T01:52:29.251280599Z",
        "Scope": "local",
        "Driver": "bridge",
        "EnableIPv6": false,
        "IPAM": {
            "Driver": "default",
            "Options": {},
            "Config": [
                {
                    "Subnet": "172.18.0.0/16",
                    "Gateway": "172.18.0.1"
                }
            ]
        },
        "Internal": false,
        "Attachable": false,
        "Ingress": false,
        "ConfigFrom": {
            "Network": ""
        },
        "ConfigOnly": false,
        "Containers": {
            "aa04d18a7d073df6159717029ae5b42aa10a476d93a637fab24f122b94eee651": {
                "Name": "es",
                "EndpointID": "1ab25adb60508edc9d422095c89a8a6f28da0eb3576882be16ca0f234a8b8f46",
                "MacAddress": "02:42:ac:12:00:02",
                "IPv4Address": "172.18.0.2/16",
                "IPv6Address": ""
            }
        },
        "Options": {},
        "Labels": {}
    }
]
```

如您所见，我们的es容器现在在aws-net网桥网络中运行。现在，让我们检查一下在aws-net网络中启动时发生的情况。

```
$ docker run -it --rm --net aws-net nikosheng/foodtrucks-web curl es:9200
{
  "name" : "8HgCcmE",
  "cluster_name" : "docker-cluster",
  "cluster_uuid" : "-C8xgQccSVmqx3KQFteyZA",
  "version" : {
    "number" : "6.3.2",
    "build_flavor" : "default",
    "build_type" : "tar",
    "build_hash" : "053779d",
    "build_date" : "2018-07-20T05:20:23.451332Z",
    "build_snapshot" : false,
    "lucene_version" : "7.3.1",
    "minimum_wire_compatibility_version" : "5.6.0",
    "minimum_index_compatibility_version" : "5.0.0"
  },
  "tagline" : "You Know, for Search"
}
```
可行！在用户定义的网络（如aws-net）上，容器不仅可以通过IP地址进行通信，而且还可以将容器名称解析为IP地址。此功能称为自动服务发现。让我们立即启动Flask容器

请注意，如果出现`The container name "foodtrucks-web" is already in use by container` 的错误，可以先通过 docker container ls -a 获取停止的容器id，然后通过docker container stop <容器id> 以及 docker container rm <容器id> 来彻底注销容器

```
$ docker run -d --net aws-net -p 5000:5000 --name foodtrucks-web nikosheng/foodtrucks-web

$ docker container ls
CONTAINER ID        IMAGE                                                 COMMAND                  CREATED             STATUS              PORTS                                            NAMES
308e2ed9d218        nikosheng/foodtrucks-web                              "python3 ./app.py"       18 seconds ago      Up 17 seconds       0.0.0.0:5000->5000/tcp                           foodtrucks-web
aa04d18a7d07        docker.elastic.co/elasticsearch/elasticsearch:6.3.2   "/usr/local/bin/dock…"   42 minutes ago      Up 42 minutes       0.0.0.0:9200->9200/tcp, 0.0.0.0:9300->9300/tcp   es

$ curl -I 0.0.0.0:5000
HTTP/1.0 200 OK
Content-Type: text/html; charset=utf-8
Content-Length: 3685
Server: Werkzeug/1.0.1 Python/3.6.9
Date: Wed, 29 Jul 2020 02:40:47 GMT
```

我们可以看到web服务已经可以成功调用es服务啦。

</pre>
</details>