# 🚀 www.gaopeng.site 完整部署指南

## 📋 概述

本指南将帮助您将 gaopeng-demo 项目完整部署到 www.gaopeng.site。我们提供了多种部署方式，从简单的一键部署到详细的手动配置。

## 🛠️ 部署文件说明

| 文件名 | 用途 | 说明 |
|--------|------|------|
| `deploy.sh` | Docker一键部署 | 本地开发/测试用 |
| `production-deploy.sh` | 生产环境部署 | 完整的生产环境自动化部署 |
| `ssl-setup.sh` | SSL证书配置 | Let's Encrypt免费SSL证书 |
| `monitor.sh` | 服务监控 | 健康检查和自动修复 |
| `Dockerfile` | Docker镜像 | 容器化配置 |
| `docker-compose.yml` | 容器编排 | 多服务管理 |
| `nginx.conf` | Nginx配置 | 反向代理和SSL |

## 🚀 快速部署（推荐）

### 步骤1: 准备服务器

1. **获取服务器**（Ubuntu 20.04+ 推荐）
2. **配置域名DNS**
   ```bash
   # 确保以下记录指向您的服务器IP
   gaopeng.site        A    [您的服务器IP]
   www.gaopeng.site    A    [您的服务器IP]
   ```

### 步骤2: 连接服务器并部署

```bash
# 1. 连接服务器
ssh user@[您的服务器IP]

# 2. 更新系统
sudo apt update && sudo apt upgrade -y

# 3. 克隆项目
git clone https://github.com/dangkimlinh60-sys/gaopeng-demo.git
cd gaopeng-demo

# 4. 执行一键部署
chmod +x production-deploy.sh
./production-deploy.sh

# 5. 配置SSL证书
chmod +x ssl-setup.sh
./ssl-setup.sh

# 6. 设置监控
chmod +x monitor.sh
# 添加定时任务
(crontab -l 2>/dev/null; echo "*/5 * * * * /home/$(whoami)/gaopeng-demo/monitor.sh check") | crontab -
```

### 步骤3: 验证部署

访问 https://www.gaopeng.site 检查网站是否正常运行。

## 🔧 详细部署步骤

### 方式一：使用生产部署脚本

```bash
# 在服务器上执行
./production-deploy.sh
```

**该脚本会自动：**
- ✅ 检查系统依赖
- ✅ 安装 Node.js、PM2、Nginx
- ✅ 克隆或更新代码
- ✅ 构建应用
- ✅ 配置 PM2 进程管理
- ✅ 设置 Nginx 反向代理
- ✅ 配置防火墙

### 方式二：Docker部署

```bash
# 在服务器上执行
docker-compose up -d
```

### 方式三：手动部署

<details>
<summary>展开查看手动部署步骤</summary>

#### 1. 安装依赖
```bash
# 安装 Node.js 18+
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt-get install -y nodejs

# 安装 PM2
sudo npm install -g pm2

# 安装 Nginx
sudo apt install -y nginx
```

#### 2. 部署应用
```bash
# 克隆代码
git clone https://github.com/dangkimlinh60-sys/gaopeng-demo.git
cd gaopeng-demo

# 安装依赖并构建
npm ci
npm run build

# 启动应用
pm2 start .next/standalone/server.js --name gaopeng-demo
pm2 save
pm2 startup
```

#### 3. 配置 Nginx
```bash
# 复制配置文件
sudo cp nginx.conf /etc/nginx/sites-available/gaopeng-demo
sudo ln -s /etc/nginx/sites-available/gaopeng-demo /etc/nginx/sites-enabled/
sudo rm /etc/nginx/sites-enabled/default

# 测试并重启
sudo nginx -t
sudo systemctl restart nginx
```

</details>

## 🔐 SSL证书配置

### 自动配置（推荐）
```bash
./ssl-setup.sh
```

### 手动配置
```bash
# 安装 Certbot
sudo apt install certbot python3-certbot-nginx

# 获取证书
sudo certbot --nginx -d www.gaopeng.site -d gaopeng.site

# 设置自动续期
echo "0 2 * * 1 certbot renew --quiet" | sudo crontab -
```

## 📊 监控和维护

### 设置监控
```bash
# 手动检查
./monitor.sh check

# 设置定时监控（每5分钟）
echo "*/5 * * * * /path/to/gaopeng-demo/monitor.sh check" | crontab -
```

### 常用维护命令
```bash
# 查看应用状态
pm2 status
pm2 logs gaopeng-demo

# 重启应用
pm2 restart gaopeng-demo

# 查看 Nginx 状态
sudo systemctl status nginx
sudo nginx -t

# 查看 SSL 证书状态
sudo certbot certificates

# 更新应用
cd /var/www/gaopeng-demo
git pull origin main
npm ci
npm run build
pm2 restart gaopeng-demo
```

## 🛡️ 安全配置

### 防火墙设置
```bash
sudo ufw enable
sudo ufw allow ssh
sudo ufw allow 80
sudo ufw allow 443
```

### 额外安全措施
```bash
# 禁用root登录
sudo sed -i 's/PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config
sudo systemctl restart ssh

# 安装fail2ban
sudo apt install fail2ban

# 配置自动更新
sudo apt install unattended-upgrades
sudo dpkg-reconfigure unattended-upgrades
```

## 🚨 故障排查

### 常见问题

#### 1. 网站无法访问
```bash
# 检查服务状态
pm2 status
sudo systemctl status nginx

# 检查端口占用
sudo netstat -tlnp | grep :80
sudo netstat -tlnp | grep :443

# 查看日志
pm2 logs gaopeng-demo
sudo tail -f /var/log/nginx/error.log
```

#### 2. SSL证书问题
```bash
# 检查证书状态
sudo certbot certificates

# 手动续期
sudo certbot renew --nginx

# 测试证书配置
curl -I https://www.gaopeng.site
```

#### 3. 应用构建失败
```bash
# 检查Node.js版本
node -v  # 需要18+

# 清理缓存重新构建
rm -rf .next node_modules
npm install
npm run build
```

#### 4. 域名解析问题
```bash
# 检查DNS解析
nslookup www.gaopeng.site
dig www.gaopeng.site

# 检查从其他位置
# 可以使用在线DNS检查工具
```

## 📈 性能优化

### 1. 启用Gzip压缩
在 Nginx 配置中添加：
```nginx
gzip on;
gzip_types text/plain text/css application/json application/javascript text/xml application/xml;
```

### 2. 设置CDN
推荐使用 Cloudflare：
1. 将域名DNS托管到Cloudflare
2. 启用代理（橙色云朵）
3. 配置缓存规则

### 3. 数据库优化（如需要）
```bash
# 如果使用MySQL
sudo mysql_secure_installation

# 如果使用PostgreSQL
sudo -u postgres psql -c "SHOW shared_preload_libraries;"
```

## 📞 技术支持

### 监控检查命令
```bash
# 完整健康检查
./monitor.sh check

# 仅检查特定项目
./monitor.sh service    # 服务状态
./monitor.sh website    # 网站访问
./monitor.sh ssl        # SSL证书
./monitor.sh resources  # 系统资源
```

### 日志查看
```bash
# 应用日志
pm2 logs gaopeng-demo

# Nginx日志
sudo tail -f /var/log/nginx/access.log
sudo tail -f /var/log/nginx/error.log

# 系统日志
sudo journalctl -u nginx -f
```

### 备份建议
```bash
# 创建备份脚本
#!/bin/bash
DATE=$(date +%Y%m%d_%H%M%S)
tar -czf "/var/backups/gaopeng-demo-$DATE.tar.gz" /var/www/gaopeng-demo
# 保留最近7天的备份
find /var/backups/ -name "gaopeng-demo-*.tar.gz" -mtime +7 -delete
```

## ✅ 部署检查清单

部署完成后，请确认以下项目：

- [ ] 网站可通过 http://www.gaopeng.site 访问（应重定向到HTTPS）
- [ ] 网站可通过 https://www.gaopeng.site 正常访问
- [ ] SSL证书有效且自动续期已配置
- [ ] PM2进程正常运行
- [ ] Nginx服务正常运行
- [ ] 防火墙规则已配置
- [ ] 监控脚本已设置定时任务
- [ ] 备份策略已实施

---

## 🎉 部署完成！

如果一切顺利，您的网站现在应该可以通过 https://www.gaopeng.site 正常访问了！

有任何问题，请查看故障排查部分或运行监控脚本进行诊断。