# Gaopeng Demo 部署指南

## 项目概述
这是一个基于 Next.js 15 的现代化 Web 应用，使用 TypeScript 和 TailwindCSS 构建。

## 部署方式

### 方式一：Docker 部署（推荐）

#### 前置要求
- Docker 和 Docker Compose 已安装
- 服务器可访问互联网
- 域名 www.gaopeng.site 已指向服务器 IP

#### 快速部署
```bash
# 克隆项目
git clone https://github.com/dangkimlinh60-sys/gaopeng-demo.git
cd gaopeng-demo

# 运行部署脚本
./deploy.sh
```

#### 手动部署步骤
```bash
# 1. 构建 Docker 镜像
docker-compose build

# 2. 启动服务
docker-compose up -d

# 3. 查看状态
docker-compose ps
docker-compose logs
```

### 方式二：传统部署

#### 在服务器上
```bash
# 1. 安装 Node.js (18+)
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt-get install -y nodejs

# 2. 克隆和构建
git clone https://github.com/dangkimlinh60-sys/gaopeng-demo.git
cd gaopeng-demo
npm install
npm run build

# 3. 启动应用
npm start
```

## SSL 证书配置

### 使用 Let's Encrypt（免费）
```bash
# 安装 certbot
sudo apt install certbot python3-certbot-nginx

# 获取证书
sudo certbot --nginx -d www.gaopeng.site -d gaopeng.site

# 创建 SSL 目录并复制证书
sudo mkdir -p ./ssl
sudo cp /etc/letsencrypt/live/www.gaopeng.site/fullchain.pem ./ssl/
sudo cp /etc/letsencrypt/live/www.gaopeng.site/privkey.pem ./ssl/
```

## 网络配置

### 防火墙设置
```bash
# Ubuntu/Debian
sudo ufw allow 80
sudo ufw allow 443
sudo ufw allow 22

# CentOS/RHEL
sudo firewall-cmd --permanent --add-port=80/tcp
sudo firewall-cmd --permanent --add-port=443/tcp
sudo firewall-cmd --reload
```

### DNS 配置
确保以下记录指向您的服务器 IP：
- A 记录：gaopeng.site → [服务器IP]
- CNAME 记录：www.gaopeng.site → gaopeng.site

## 监控和维护

### 查看日志
```bash
# Docker 方式
docker-compose logs -f

# 传统方式
pm2 logs  # 如果使用 PM2
```

### 重启服务
```bash
# Docker 方式
docker-compose restart

# 传统方式
pm2 restart gaopeng-demo  # 如果使用 PM2
```

### 更新部署
```bash
git pull origin main
docker-compose build
docker-compose up -d
```

## 故障排查

### 常见问题

1. **端口冲突**
   - 检查 3000 端口是否被占用：`lsof -i :3000`
   - 修改 docker-compose.yml 中的端口映射

2. **SSL 证书问题**
   - 检查证书路径是否正确
   - 确保证书文件权限正确

3. **域名无法访问**
   - 检查 DNS 配置：`nslookup www.gaopeng.site`
   - 检查防火墙设置

4. **容器启动失败**
   - 查看详细日志：`docker-compose logs`
   - 检查 Docker 资源使用情况

## 性能优化

- 启用 Nginx gzip 压缩
- 配置 CDN（如 Cloudflare）
- 设置适当的缓存策略
- 监控服务器资源使用情况

## 安全建议

- 定期更新系统和依赖
- 使用强密码和 SSH 密钥
- 配置防火墙规则
- 启用日志监控
- 定期备份数据