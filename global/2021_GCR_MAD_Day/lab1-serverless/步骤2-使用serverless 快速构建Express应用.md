## 步骤1- 使用serverless 快速构建Express应用



### 目的

通过把一个传统 Web 应用使用容器化方式部署到 AWS Lambda，体验 AWS 无服务器服务。涉及服务：AWS Lambda、Amazon API Gateway、Amazon ECR、AWS SAM、AWS Cloud9。

### 步骤

1. 构建本地应用。在本地搭建 Express 应用，这是最传统的应用构建方式。
2. 改造成容器。将前述 Express 应用改造成容器。
3. 改造成无服务器应用。将容器应用改造成无服务器应用。

### 1. 构建本地应用

- 下载 Express 和 EJS
- 创建网页文件
- 本地测试

#### 1-1. 下载 Express 和 EJS

我们先下载 Express 和 EJS 以及 Body Parser 工具。

Express 是 Web 服务器，EJS（Embedded JavaScript）是一个用 JS 来写模板的工具，Body Parser 用于提取 HTTP 请求中的信息。

```shell

# 进入 environment 文件夹

cd ~/environment

# 创建子文件夹

mkdir serverless-express
cd serverless-express

# 初始化 Node 项目

npm init -y

# 下载 Express 和 EJS
npm i express ejs body-parser


```

#### 1-2. 创建网页文件

接下来我们创建一个非常简单的待办事项 Web 应用。复制下面的代码，粘贴到命令行，并执行。

```shell
# 创建入口文件（index.js）

cat <<"EOF" > index.js
var express = require('express');
var app = express();
var port = 8081;
var bodyParser = require("body-parser");

app.use(bodyParser.urlencoded({ extended: true }));

app.set('view engine', 'ejs');

var task = ["buy milk", "learn javascript", "learn express"];

app.post('/addtask', function (req, res) {
    var newTask = req.body.newtask;
    task.push(newTask);
    res.redirect("/");
});

app.get("/", function(req, res) {
    res.render('index', { task, completed });
});

var completed = ["finish learning nodejs"];

app.post("/removetask", function(req, res) {
    var completedTask = req.body.check;
    
    if (typeof completedTask === "string") {
        completed.push(completedTask);
        task.splice(task.indexOf(completedTask), 1);
    } else if (typeof completedTask === "object") {
        for (var i = 0; i < completedTask.length; i++){
            completed.push(completedTask[i]);
            task.splice(task.indexOf(completedTask[i]), 1);
        }
    }

    res.redirect("/");
});

app.listen(port, function () {
  console.log(`LISTENING PORT ${port}`);
});
EOF
```

然后我们创建一个网页模板。同样，复制下面的代码，粘贴到命令行，并执行。

```shell

# 创建模板文件夹

mkdir views

# 创建模板（views/index.ejs）

cat <<"EOF" > views/index.ejs
<html>
  <head>
    <title> Todo </title>
    <link href="/styles.css" rel="stylesheet">
  </head>
<body>
  <div class="container">
     <h2> Simple Todo app </h2>
<form action ="/addtask" method="POST">
       <input type="text" name="newtask" placeholder="add new task">        <button> Add Task </button>
<h2> Added Task </h2>
   <% for( var i = 0; i < task.length; i++){ %>
<li><input type="checkbox" name="check" value="<%= task[i] %>" /> <%= task[i] %> </li>
<% } %>
<button formaction="/removetask" type="submit"> Remove </button>
</form>
<h2> Completed task </h2>
    <% for(var i = 0; i < completed.length; i++){ %>
      <li><input type="checkbox" checked><%= completed[i] %> </li>
<% } %>
</div>
</body>
</html>
EOF

```

#### 1-3. 本地测试

接下来我们在本地测试一下。

先运行一下这个 Express 应用。

```shell

node index.js

```

看到显示 `LISTENING PORT 8081` 就启动成功了。接下来我们测试一下。

点击终端标签页旁边的绿色加号，选择 `New Terminal`，开启一个新的终端标签页输入如下命令。

```shell

curl localhost:8081

```

应该可以看到与下面框内类似的 HTML 输出。这就说明应用正常运行了。

```html
...

<li><input type="checkbox" name="check" value="learn javascript" /> learn javascript </li>

<li><input type="checkbox" name="check" value="learn express" /> learn express </li>

<button formaction="/removetask" type="submit"> Remove </button>
</form>
<h2> Completed task </h2>
    
      <li><input type="checkbox" checked>finish learning nodejs </li>

</div>
</body>
</html>

```

也可以直接通过 Cloud9 提供的代理预览在本地运行中的应用。

点击菜单 `Tools → Preview → Preview Running Application`，右下角会出现一个预览窗口。

点击预览窗口地址栏 `Browser` 字样右边的新窗口图标，会打开一个 `xxxxxxxx.vfs.cloud9.us-west-2.amazonaws.com` 的地址。你应该会看到蓝色 `Oops` 字样，这是因为默认浏览的是 `80` 端口，而我们的应用部署在 `8081` 端口。

在该地址末尾加上 `:8081`，可以看到这个 Todo 应用。可随意测试添加和删除一些条目。

部分区域可能不支持 `8080` 之外的其他端口，此时可以回去打开 `index.js` 将 `port` 从 `8081` 修改成 `8080` 再进行操作。如果此处做了修改，后续 `8081` 的部分请都修改成 `8080`。

这样我们就做好了一个正常可运行的 Express 应用。

### 2. 容器化

回到 Cloud9 窗口，点击预览标签页上的叉，关闭预览标签。注意不是控制台最右边的叉，会整个关掉控制台界面。如果不小心关闭控制台界面，点击菜单 `View → Console` 可以重新打开。

点击之前运行 `node index.js` 并且在显示 `LISTENING PORT 8081` 的控制台标签页，然后按 `Ctrl + C` 来终止 Express 应用。

接下来我们使用容器来封装应用。

```bash
#cloud9 环境安装docker
sudo yum install docker -y

```



#### 2-1. 创建 Dockerfile

首先我们创建一个 Dockerfile。复制如下代码并粘贴到命令行执行。

```shell

cat <<"EOF" > Dockerfile
FROM node:14
WORKDIR /usr/src/app
COPY package*.json ./
RUN npm install
COPY . .
EXPOSE 8081
CMD [ "node", "index.js" ]

COPY --from=public.ecr.aws/awsguru/aws-lambda-adapter:latest /opt/bootstrap /opt/bootstrap
ENV READINESS_CHECK_PORT=8081 PORT=8081 RUST_LOG=debug
ENTRYPOINT ["/opt/bootstrap"]
EOF

```

这个 Dockerfile 包括两个部分，中间用空行隔开。

第一部分是普通的镜像构建，用户可以使用任意命令来构建镜像，基础镜像也可以随意选择。

第二部分是一个 Lambda 运行时客户端（Lambda Runtime Client）。Lambda 在调用容器的时候，会激活容器，然后期待容器自己去某个地址去获取调用信息，自己执行，执行完了再把结果发到某个地址。

- 获取调用信息 `http://{AWS_LAMBDA_RUNTIME_API}/2018-06-01/runtime/invocation/next`
- 返回结果 `/runtime/invocation/<request-id>/response`

而我们这个 Lambda 运行时客户端的作用，就是帮用户解决这个转发问题。它把 Lambda 调用转换成 HTTP 请求，然后把返回的结果再转换成 Lambda 的响应。对于应用来说，这个过程是透明的。

如果应用没有运行在 Lambda 环境中，那么 `AWS_LAMBDA_RUNTIME_API` 环境变量就不会被设置，此时运行时客户端则会直接执行用户在 `CMD` 中指定的命令，不做任何变动。这也意味着我们的传统版应用和服务器版应用，可以使用同一个镜像，更方便。

接下来，我们添加一个 `.dockerignore` 避免把已经存在的包复制进镜像。这些包会在镜像构建时再下载，而不会被纳入镜像构建的版本追踪。

```shell

cat <<"EOF" > .dockerignore
node_modules
npm-debug.log
EOF

```

#### 2-2. 构建镜像

接下来我们测试下这个镜像。先进行构建。

```shell

docker build . -t serverless-express

docker images

```

#### 2-3. 运行容器

构建完成后，我们直接使用这个镜像来启动容器。这个容器将运行在后台。

```shell

docker run -d -p 8081:8081 serverless-express

```

同样，使用一个命令来测试效果。

```shell

curl localhost:8081

```

应该是和之前一样的效果。此时我们也可以使用之前同样的预览方式来进行预览。

预览完成之后，我们可以用 `docker ps` 来查看在后台运行的容器，找到第一列的容器 ID，然后用 `docker kill` 命令把这个容器停止掉。

```shell

docker ps

docker kill <container-id>

```

### 部署到无服务器服务

接下来我们用 AWS Lambda 来运行容器，并使用 Amazon API Gateway 来作为入口。

#### 创建 ECR 镜像仓库

首先，Lambda 只能使用 Amazon ECR 上的镜像来启动容器，所以我们先要创建一个 ECR 仓库。

```shell

aws ecr create-repository --repository-name serverless-express --query repository.repositoryUri

```

上面这条命令会输出一个地址，将它复制下来备用（不包含引号）。然后，我们需要登录到这个仓库。ECR 提供了一条命令来帮助我们登录仓库，把下面的 `<repo-uri>` 换成实际的仓库地址。


```shell

aws ecr get-login-password | docker login --username AWS --password-stdin <repo-uri>

```

接下来，我们使用 AWS SAM 来快速创建一个 Lambda 函数，以及对应的 API Gateway 入口。SAM 用模板的方式来描述需要创建的资源。

点击菜单 `File → New File`，将下面的模板粘贴进去，然后保存为 `template.yaml`。注意这个文件置于 `~/environment` 目录，即 `serverless-express/` 的上层目录。

```yaml
AWSTemplateFormatVersion: '2010-09-09'
Transform: AWS::Serverless-2016-10-31
Description: >
  sam-app

Globals:
  Function:
    Timeout: 10

Resources:
  ExpressFunction:
    Type: AWS::Serverless::Function
    Properties:
      PackageType: Image
      MemorySize: 128
      Policies:
        - CloudWatchLambdaInsightsExecutionRolePolicy # Add IAM Permission for Lambda Insight Extension
      Environment:
        Variables:
          RUST_LOG: debug
      Events:
        Root:
          Type: HttpApi
          Properties:
            Path: /
            Method: ANY
        Petstore:
          Type: HttpApi
          Properties:
            Path: /{proxy+}
            Method: ANY
    Metadata:
      DockerTag: v1
      DockerContext: ./serverless-express
      Dockerfile: Dockerfile

Outputs:
  ExpressApi:
    Description: "API Gateway endpoint URL for Prod stage for Express function"
    Value: !Sub "https://${ServerlessHttpApi}.execute-api.${AWS::Region}.amazonaws.com/"
```

接下来我们可以直接用下面的命令构建容器，并且创建 API Gateway 等资源，并部署容器到 Lambda 服务。注意把下面的 `<repo-uri>` 替换成你上面保存的 ECR 仓库地址。


```shell

cd ~/environment

sam build
sam deploy --stack-name serverless-express --image-repository <repo-uri> --capabilities CAPABILITY_IAM

```

运行完成后，我们可以看到类似下面的一个输出：

- `https://xxxxxx.execute-api.us-west-2.amazonaws.com/`

打开这个地址，我们就能看到 Express 应用了。这个应用和我们在本地运行的效果是一样的。

### 自由探索

我们可以打开 AWS CloudFormation 来查看刚刚通过 SAM 创建的模板和对应的资源。

在 Amazon API Gateway 下我们可以看到 API 网关和对应的 API 模型。

在 Lambda 中我们可以看到创建的函数、对应的镜像地址、触发器、权限等。

在 CloudWatch 中可以看到 Lambda 函数的日志以及实际运行时间，每个请求与通常在十数到数十毫秒。

### 注意

为了方便演示，我们没有使用数据库，数据临时存在了进程内。当容器被回收时，数据也就消失了，所以在使用过程中用户可能会发现数据归零。

在实际应用中，容器通常都是不保存状态的，数据的持久化会置于容器外，所以不存在这个问题。





