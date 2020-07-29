# Docker 基本操作

Docker 是一个开源的商业产品，有两个版本：社区版（Community Edition，缩写为 CE）和企业版（Enterprise Edition，缩写为 EE）。企业版包含了一些收费服务，个人开发者一般用不到。下面的介绍都针对社区版。

AWS Cloud9 已经内置了Docker CE版本，我们可以通过如下命令确认

```
docker info

# 或者

docker version
```

## Hello World

确认本机已经安装好Docker后，我们可以通过`docker run`来尝试运行一个`hello-world`程序

```
$ docker run hello-world

...
Hello from Docker.
This message shows that your installation appears to be working correctly.
...
```

当我们在输出文本中能看到`Hello from Docker.`，证明我们的Docker可以正常运行。

## 小试牛刀 - Playing with Busybox


现在我们已经完成了所有设置，现在该小试牛刀了。在本节中，我们将在系统上运行`Busybox`容器，并对`docker run`命令有所了解。

首先，让我们在终端中运行以下命令：

```
docker pull busybox
```

`pull`命令从`Docker注册表`中获取`busybox`镜像并将其保存到我们的系统中。您可以使用docker images命令来查看系统上所有镜像的列表。

```
admin:~/environment $ docker images
REPOSITORY          TAG                 IMAGE ID            CREATED             SIZE
busybox             latest              018c9d7b792b        6 hours ago         1.22MB
```

现在让我们基于该镜像运行一个Docker容器。为此，我们将使用全能的docker run命令。

```
docker run busybox
```

等等，什么都没发生！那是个错误吗？好吧，不。在底层，其实发生了很多事情。当您调用run时，Docker客户端会找到镜像（在本例中为busbox），加载容器，然后在该容器中运行命令。当我们运行docker run busybox时，我们没有提供命令，因此容器启动，运行空命令，然后退出。

```
admin:~/environment $ docker run busybox echo "hello from busybox"
hello from busybox
```

很好-终于我们看到了一些输出。在这种情况下，Docker客户端会在我们的busybox容器中忠实地运行echo命令，然后退出它。好的，现在该看docker ps命令了。 docker ps命令向您显示当前正在运行的所有容器。

```
admin:~/environment $ docker ps
CONTAINER ID        IMAGE               COMMAND             CREATED             STATUS              PORTS               NAMES
```

由于没有容器在运行，因此我们看到一个空行。让我们尝试一个更有用的命令：docker ps -a

```
admin:~/environment $ docker ps -a
CONTAINER ID        IMAGE               COMMAND                  CREATED             STATUS                      PORTS               NAMES
28d676f7d6ef        busybox             "echo 'hello from bu…"   2 minutes ago       Exited (0) 2 minutes ago                        blissful_jones
6cdf37f9bffa        busybox             "sh"                     2 minutes ago       Exited (0) 2 minutes ago                        reverent_lamarr
818eb4f23324        hello-world         "/hello"                 10 minutes ago      Exited (0) 10 minutes ago                       ecstatic_goodall
```

因此，我们在上面看到的是我们运行的所有容器的历史列表。请注意，STATUS列显示这些容器是在几分钟前退出的。

您可能想知道是否有一种方法可以在容器中运行多个命令。

```
admin:~/environment $ docker run -it busybox sh
/ # ls
bin   dev   etc   home  proc  root  sys   tmp   usr   var
/ # uname -a
Linux 9c8b02f615cb 4.14.186-110.268.amzn1.x86_64 #1 SMP Tue Jul 14 02:57:34 UTC 2020 x86_64 GNU/Linux
/ # exit
```

使用-it标志运行run命令会将我们附加到容器中的交互式tty。现在，我们可以在容器中运行任意数量的命令。

接下来，您可以运行docker rm命令去删除我们刚才运行的容器。只需从上方docker ps -a复制容器ID，然后将其粘贴到命令旁边即可。


```
docker rm 9c8b02f615cb 28d676f7d6ef 6cdf37f9bffa 818eb4f23324
```

如果您要一次性删除一堆容器，那么粘贴粘贴的ID可能很繁琐。在这种情况下，您只需运行

```
admin:~/environment $ docker rm $(docker ps -a -q -f status=exited)
9c8b02f615cb
28d676f7d6ef
6cdf37f9bffa
818eb4f23324
```

最后，我们可以删除我们不需要的镜像，通过docker images 查看所有镜像，然后抽取需要删除的镜像id，通过 docker rmi -f <镜像id> 删除镜像

```
docker rmi -f 018c9d7b792b bf756fb1ae65
```


## 清除环境

请注意，由于本次实验的实例环境容量只有10G，因此我们需要尽量减少其他占用资源的空间，所以我们需要删除一些在这次实验中不需要的Docker镜像保证空间足够。我们可以通过`docker rmi <镜像id>` 删除 `docker images` 中的所有镜像内容。

