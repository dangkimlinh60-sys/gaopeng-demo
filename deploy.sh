#!/bin/bash

# 部署脚本 - 将应用部署到 www.gaopeng.site

echo "🚀 开始部署 Gaopeng Demo 到 www.gaopeng.site"

# 检查 Docker 是否安装
if ! command -v docker &> /dev/null; then
    echo "❌ Docker 未安装，请先安装 Docker"
    exit 1
fi

# 检查 Docker Compose 是否安装
if ! command -v docker-compose &> /dev/null; then
    echo "❌ Docker Compose 未安装，请先安装 Docker Compose"
    exit 1
fi

# 停止现有容器（如果存在）
echo "🛑 停止现有容器..."
docker-compose down 2>/dev/null || true

# 构建新镜像
echo "🔧 构建 Docker 镜像..."
docker-compose build

# 启动服务
echo "🔄 启动服务..."
docker-compose up -d

# 等待服务启动
echo "⏳ 等待服务启动..."
sleep 10

# 检查服务状态
echo "📊 检查服务状态..."
docker-compose ps

# 显示日志
echo "📝 显示最近的日志..."
docker-compose logs --tail=20

echo "✅ 部署完成！"
echo "🌐 网站应该在以下地址可访问："
echo "   - http://localhost:3000 (直接访问应用)"
echo "   - http://localhost (通过 Nginx)"
echo "   - https://www.gaopeng.site (生产环境，需要 SSL 证书)"

echo ""
echo "📋 后续步骤："
echo "1. 配置域名 DNS 指向您的服务器 IP"
echo "2. 在服务器上设置 SSL 证书（Let's Encrypt 推荐）"
echo "3. 确保防火墙开放 80 和 443 端口"