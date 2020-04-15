

自定义tcp-log plugin包含了request body 和 response body。
http://tech.jiu-shu.com/Micro-Services/kong-quickstart-plugindev

## 插件打包
进入目录运行命令打包安装并测试。 （构建docker的宿主机需要安装kong）

```
luarocks make
luarocks pack kong-plugin-tcp-log-body 0.1.0
luarocks install kong-plugin-tcp-log-body-0.1.0-1.all.rock  # 本地测试用
```

## 构建镜像
构建镜像前确定 luarocks pack 步骤已经完成
```
docker build -t jiu-shu/kong:2.0.3 .
```

## 运行测试
参考 https://docs.konghq.com/install/docker/， 这里采取声明式作为示例。 

 - 创建网络`https://docs.konghq.com/install/docker/`
 - 创建容器卷`docker volume create kong-vol`
 - 配置kong.ym, 路径: `/var/lib/docker/volumes/kong-vol/_data/kong.yml`
 - 运行；注意设置plugins: `-e "KONG_PLUGINS=bundled,tcp-log-body"`

```
docker run -d --name kong \
     --network=kong-net \
     -v "kong-vol:/usr/local/kong/declarative" \
     -e "KONG_DATABASE=off" \
     -e "KONG_PLUGINS=bundled,tcp-log-body" \
     -e "KONG_DECLARATIVE_CONFIG=/usr/local/kong/declarative/kong.yml" \
     -e "KONG_PROXY_ACCESS_LOG=/dev/stdout" \
     -e "KONG_ADMIN_ACCESS_LOG=/dev/stdout" \
     -e "KONG_PROXY_ERROR_LOG=/dev/stderr" \
     -e "KONG_ADMIN_ERROR_LOG=/dev/stderr" \
     -e "KONG_ADMIN_LISTEN=0.0.0.0:8001, 0.0.0.0:8444 ssl" \
     -p 8000:8000 \
     -p 8443:8443 \
     -p 127.0.0.1:8001:8001 \
     -p 127.0.0.1:8444:8444 \
     jiu-shu/kong:2.0.3
```

## 推送镜像
```
docker tag jiu-shu/kong:2.0.3  registry.cn-qingdao.aliyuncs.com/jiu-shu/kong:2.0.3
docker tag jiu-shu/kong:2.0.3  registry.cn-qingdao.aliyuncs.com/jiu-shu/kong:latest
docker login --username=choelea@gmail.com registry.cn-qingdao.aliyuncs.com
docker push registry.cn-qingdao.aliyuncs.com/jiu-shu/kong:2.0.3
docker push registry.cn-qingdao.aliyuncs.com/jiu-shu/kong:latest
```