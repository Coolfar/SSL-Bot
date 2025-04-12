#!/bin/bash

# 强制脚本在遇到任何错误时退出
set -e

# 初始化清理函数
cleanup() {
    echo "** 检测到中断，正在清理..."
    rm -f /root/${DOMAIN}.{key,crt} 2>/dev/null || true
    ~/.acme.sh/acme.sh --remove -d "$DOMAIN" >/dev/null 2>&1 || true
    mv /root/acme_renew.log /root/acme_failed_$(date +%Y%m%d%H%M%S).log 2>/dev/null || true
    echo "清理完成，脚本已退出。"
    exit 1
}
trap cleanup INT TERM

# 检测操作系统
detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
    elif type lsb_release >/dev/null 2>&1; then
        OS=$(lsb_release -si | tr 'A-Z' 'a-z')
    else
        echo "⚠️  无法检测操作系统类型，请手动安装依赖"
        exit 1
    fi
}

# 安装基础依赖
install_deps() {
    case $OS in
        ubuntu|debian)
            apt update -qq
            apt upgrade -y -qq
            apt install -y -qq curl socat git cron >/dev/null
            ;;
        centos|rhel)
            yum update -y -q
            yum install -y -q curl socat git cronie >/dev/null
            systemctl start crond
            systemctl enable crond >/dev/null
            ;;
        *)
            echo "❌ 不支持的操作系统：$OS"
            exit 1
            ;;
    esac
}

# 主执行流程
echo "▌ SSL 证书自动化部署脚本（DNS 验证版）▐"

# 步骤 1: 用户输入
read -p "» 请输入域名（如 example.com）: " DOMAIN
while [[ ! "$DOMAIN" =~ ^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; do
    echo "⚠️  无效域名，请重新输入"
    read -p "» 请输入域名（如 example.com）: " DOMAIN
done

read -p "» 请输入邮箱（用于证书通知）: " EMAIL
EMAIL=${EMAIL:-user@example.com}

# 步骤 2: 选择 DNS 提供商
PS3="» 请选择 DNS 提供商（数字）: "
select provider in "Cloudflare" "阿里云" "腾讯云(DNSPod)"; do
    case $provider in
        Cloudflare)
            read -p "• 请输入 Cloudflare API 密钥: " CF_KEY
            read -p "• 请输入 Cloudflare 注册邮箱: " CF_EMAIL
            export CF_Key="$CF_KEY"
            export CF_Email="$CF_EMAIL"
            DNS_SERVICE="dns_cf"
            break
            ;;
        阿里云)
            read -p "• 请输入阿里云 AccessKey ID: " ALI_KEY
            read -p "• 请输入阿里云 AccessKey Secret: " ALI_SECRET
            export Ali_Key="$ALI_KEY"
            export Ali_Secret="$ALI_SECRET"
            DNS_SERVICE="dns_ali"
            break
            ;;
        "腾讯云(DNSPod)")
            read -p "• 请输入DNSPod SecretId: " DP_ID
            read -p "• 请输入DNSPod SecretKey: " DP_KEY
            export DP_Id="$DP_ID"
            export DP_Key="$DP_KEY"
            DNS_SERVICE="dns_dp"
            break
            ;;
        *)
            echo "❌ 无效选择，请重新输入"
            ;;
    esac
done

# 步骤 3: 选择 CA 机构
PS3="» 请选择证书颁发机构（数字）: "
select ca in "Let's Encrypt" "Buypass" "ZeroSSL"; do
    case $ca in
        "Let's Encrypt") CA_SERVER="letsencrypt" ;;
        Buypass) CA_SERVER="buypass" ;;
        ZeroSSL) CA_SERVER="zerossl" ;;
        *) echo "❌ 无效选择，请重新输入"; continue ;;
    esac
    break
done

# 步骤 4: 系统检测与依赖安装
echo "⏳ 正在检测系统环境..."
detect_os
echo "⏳ 正在安装系统依赖..."
install_deps

# 步骤 5: 安装 acme.sh
echo "⏳ 正在部署 acme.sh 客户端..."
curl -s https://get.acme.sh | sh >/dev/null
source ~/.bashrc 2>/dev/null
export PATH="$HOME/.acme.sh:$PATH"
acme.sh --upgrade --auto-upgrade 0 >/dev/null

# 步骤 6: 注册账户
echo "⏳ 正在向 $CA_SERVER 注册账户..."
acme.sh --register-account -m "$EMAIL" --server "$CA_SERVER" >/dev/null

# 步骤 7: 申请证书
echo "⏳ 正在签发 SSL 证书（DNS 验证）..."
if ! acme.sh --issue --dns "$DNS_SERVICE" -d "$DOMAIN" --server "$CA_SERVER" --force; then
    echo "❌ 证书签发失败，请检查："
    echo "   - 域名是否已正确解析"
    echo "   - API 密钥是否有 DNS 写入权限"
    echo "   - 网络连接是否正常"
    cleanup
fi

# 步骤 8: 安装证书
echo "⏳ 正在安装证书到系统目录..."
acme.sh --install-cert -d "$DOMAIN" \
    --key-file       /root/"$DOMAIN".key \
    --fullchain-file /root/"$DOMAIN".crt \
    --reloadcmd     "echo '» 证书已更新，请重启相关服务！'"

# 步骤 9: 配置自动续期
echo "⏳ 正在配置自动续期任务..."

# 生成续期脚本
cat > /root/renew_cert.sh <<EOF
#!/bin/bash
export PATH="\$HOME/.acme.sh:\$PATH"

# 重新加载环境变量
case "$provider" in
    "Cloudflare")
        export CF_Key="$CF_KEY" CF_Email="$CF_EMAIL"
        ;;
    "阿里云")
        export Ali_Key="$ALI_KEY" Ali_Secret="$ALI_SECRET"
        ;;
    "腾讯云(DNSPod)")
        export DP_Id="$DP_ID" DP_Key="$DP_KEY"
        ;;
esac

# 续期证书
echo "[$(date '+%Y-%m-%d %H:%M:%S')] 正在续期证书..." >> /root/acme_renew.log
acme.sh --renew -d "$DOMAIN" --server "$CA_SERVER" --force >> /root/acme_renew.log 2>&1
EOF

# 赋予续期脚本执行权限
chmod +x /root/renew_cert.sh

# 添加 cron 任务（每天 03:00 检查续期）
(crontab -l 2>/dev/null; echo "0 3 * * * /root/renew_cert.sh >> /root/acme_renew.log 2>&1") | crontab -

# 完成提示
echo "✅ 部署完成！"
echo "────────────────────────────────────"
echo "证书路径:"
echo "  私钥文件: /root/${DOMAIN}.key"
echo "  证书文件: /root/${DOMAIN}.crt"
echo "────────────────────────────────────"
echo "测试续期命令: /root/renew_cert.sh"
echo "查看续期日志: tail -f /root/acme_renew.log"
echo "────────────────────────────────────"

# 腾讯云特别提示
if [ "$provider" = "腾讯云(DNSPod)" ]; then
    echo "ℹ️  腾讯云用户注意："
    echo "   - 请确保SecretId有DNS解析权限"
    echo "   - 如需子账号，需授予「DNSPod 所有权限」"
    echo "   - 密钥管理地址：https://console.dnspod.com/account/token"
fi
