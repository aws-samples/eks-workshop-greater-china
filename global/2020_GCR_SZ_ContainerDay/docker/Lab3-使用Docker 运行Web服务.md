# 使用Docker 运行Web服务


## 实验前准备工作

接下来的实验我们需要构建一个网站，所以我们需要提前开放实例的安全组端口。

- 首先我们需要构建一个额外的安全组开放TCP流量。在运行这个命令前，我们需要提前获取到我们Cloud9实例的vpc-id。该vpc-id可以在EC页面下获取

	![VPC-ID](media/15764751257913/15764752078709.jpg)

	```
	admin:~/environment/github/docker-workshop/static-site (master) $ aws ec2 create-security-group --description allow-web-traffic --group-name allow-web-traffic --vpc-id vpc-0a122ceb83e361a52
	{
	    "GroupId": "sg-03a4bafaf94c45139"
	}
	```
	
- 配置安全组的入站规则，需要将上面命令获取到的安全组id 填入以下命令的 `--group-id`

	```
	aws ec2 authorize-security-group-ingress \
	    --group-id sg-03a4bafaf94c45139 \
	    --ip-permissions IpProtocol=tcp,FromPort=0,ToPort=65535,IpRanges='[{CidrIp=0.0.0.0/0}]'
	```
	
- 绑定安全组到我们的Cloud9实例

	![Attach-SG](media/15764751257913/15764752078709.jpg)

## 开始构建Docker Web应用

我们将使用的镜像是一个单页面的网站，本次实验已经将其托管在Docker Hub中nikosheng/static-site。我们可以使用docker run直接下载并运行镜像。如上所述，-rm标志在容器退出时自动删除。

```
admin:~/environment/github/docker-workshop/static-site (master) $ docker run -d -P --rm --name static-site nikosheng/static-site
1545b3eb32d9e02a864b21248bd7631e016c8c4de3ec16888940ff5fc6ea9372
```
在上面的命令中，`-d`表示容器在后端运行，`-P`将所有公开的端口发布到随机端口，最后`--name`对应于我们要提供的名称。现在我们可以通过运行`docker port [CONTAINER]`命令来查看端口

```
admin:~/environment $ docker port static-site
80/tcp -> 0.0.0.0:32769
```

您可以在浏览器中打开`http://<ec2-dns>:32769`

您还可以指定客户端将连接转发到容器的自定义端口

```
admin:~/environment $ docker run -p 8080:80 nikosheng/static-site
Nginx is running...
```

要停止容器，请提供容器ID来运行docker stop。在这种情况下，我们可以使用用于启动容器的名称static-site

```
docker stop static-site
```

## 构建Dockerfile

现在我们对容器镜像有了更好的了解，是时候创建自己的镜像了。我们在本节中的目标是创建一个将简单Flask应用程序镜像。这是一个有趣的Flask小应用程序，该应用程序每次加载时都会显示一个随机的`cat.gif`

首先我们需要通过Git 下载本次实验的代码

```
git clone https://github.com/nikosheng/docker-workshop.git

cd docker-workshop/1-basic/flask-app
```

Dockerfile是一个简单的文本文件，其中包含Docker客户端在创建镜像时调用的命令列表。您在Dockerfile中编写的命令几乎与它们的等效Linux命令相同。

通过Cloud9打开flask-app中的Dockerfile

```
# 指定基准镜像
FROM python:3

# 设置工作目录
WORKDIR /usr/src/app

# 复制当前目录的文件到容器
COPY . .

# 安装依赖
RUN pip install --no-cache-dir -r requirements.txt

# 容器需要暴露的端口
EXPOSE 5000

# 运行
CMD ["python", "./app.py"]
```

现在我们有了Dockerfile，我们可以构建镜像了。 docker build命令完成了从Dockerfile创建Docker镜像的繁重工作。（可以替换下面的用户名`nikosheng`）

```
docker build -t nikosheng/flask-app .
```

检查镜像是否构建成功

```
admin:~/environment (master) $ docker images
REPOSITORY            TAG                 IMAGE ID            CREATED             SIZE
nikosheng/flask-app   latest              15ee6b5ca463        2 minutes ago       943MB
```

当镜像构建完成后，最后一步是运行镜像，并查看它是否确实有效。

```
docker run -p 5000:5000 nikosheng/flask-app
```
运行成功后，可以在浏览器中访问

```
http://<ec2-dns>:5000/
```

恭喜您！现在您应该可以看到一只可爱的小猫咪^_^

