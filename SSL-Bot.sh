#!/bin/bash

# 强制脚本在遇到任何错误时退出
set -e

# acme.sh 可执行文件路径
ACME_SH="$HOME/.acme.sh/acme.sh"

# 初始化清理函数
cleanup() {
    echo "** 检测到中断，正在清理..."
    rm -f "$CERT_PATH/${DOMAIN}.key" "$CERT_PATH/${DOMAIN}.crt" 2>/dev/null || true
    "$ACME_SH" --remove -d "$DOMAIN" >/dev/null 2>&1 || true
    mv /root/acme_renew.log /root/acme_failed_$(date +%Y%m%d%H%M%S).log 2>/dev/null || true
    echo "清理完成，脚本已退出。"
    exit 1
}
trap cleanup INT TERM

# 检测操作系统
detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        case $ID in
            ubuntu|debian)
                OS=$ID
                ;;
            centos|rhel|alinux)
                OS="centos"  # 将 alinux 视为 CentOS 处理
                ;;
            *)
                echo "❌ 不支持的操作系统：$ID"
                exit 1
                ;;
        esac
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
           # 提示用户是否更新系统
read -p "» 是否更新系统包（y/n，默认 n）？" UPDATE_SYSTEM
UPDATE_SYSTEM=${UPDATE_SYSTEM:-n}

# **无论用户是否更新，都先更新包列表**
echo "⏳ 正在更新软件包列表..."
apt-get update -qq

if [[ "$UPDATE_SYSTEM" =~ ^[Yy]$ ]]; then
    echo "⏳ 正在更新系统..."
    apt-get upgrade -y -qq
else
    echo -e "\e[33mℹ️ 跳过系统更新。如果系统缺少必要的依赖或版本过旧，可能会导致脚本失败。\e[0m"
fi

            echo "⏳ 正在安装系统依赖..."
            apt-get install -y -qq curl socat git cron >/dev/null
            ;;
        centos|rhel)
            # 提示用户是否更新系统
            read -p "» 是否更新系统包（y/n，默认 n）？" UPDATE_SYSTEM
            UPDATE_SYSTEM=${UPDATE_SYSTEM:-n}

            if [[ "$UPDATE_SYSTEM" =~ ^[Yy]$ ]]; then
                echo "⏳ 正在更新系统..."
                yum update -y -q
            else
                echo "ℹ️ 跳过系统更新。如果系统缺少必要的依赖或版本过旧，可能会导致脚本失败。"
            fi

            echo "⏳ 正在安装系统依赖..."
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

# 步骤 1: 用户输入域名
read -p "» 请输入域名（如 example.com）: " DOMAIN
while [[ ! "$DOMAIN" =~ ^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; do
    echo "⚠️  无效域名，请重新输入"
    read -p "» 请输入域名（如 example.com）: " DOMAIN
done

# 步骤 2: 输入邮箱
read -p "» 请输入邮箱（用于证书通知）: " EMAIL
EMAIL=${EMAIL:-user@example.com}

# 步骤 3: 选择 DNS 提供商
PS3="» 请选择 DNS 提供商（数字）: "
select provider in "Cloudflare" "阿里云" "腾讯云(DNSPod)"; do
    case $provider in
        Cloudflare)
            read -s -p "• 请输入 Cloudflare API 密钥（输入时不显示，粘贴后按回车）: " CF_KEY
            echo
            if [ -z "$CF_KEY" ]; then
                echo "❌ Cloudflare API 密钥不能为空"
                exit 1
            fi
            echo "✓ 已接收 Cloudflare API 密钥（长度: ${#CF_KEY}）"
            read -p "• 请输入 Cloudflare 注册邮箱: " CF_EMAIL
            export CF_Key="$CF_KEY"
            export CF_Email="$CF_EMAIL"
            DNS_SERVICE="dns_cf"
            break
            ;;
        阿里云)
            read -s -p "• 请输入阿里云 AccessKey ID（输入时不显示，粘贴后按回车）: " ALI_KEY
            echo
            if [ -z "$ALI_KEY" ]; then
                echo "❌ 阿里云 AccessKey ID 不能为空"
                exit 1
            fi
            echo "✓ 已接收阿里云 AccessKey ID（长度: ${#ALI_KEY}）"
            read -s -p "• 请输入阿里云 AccessKey Secret（输入时不显示，粘贴后按回车）: " ALI_SECRET
            echo
            if [ -z "$ALI_SECRET" ]; then
                echo "❌ 阿里云 AccessKey Secret 不能为空"
                exit 1
            fi
            echo "✓ 已接收阿里云 AccessKey Secret（长度: ${#ALI_SECRET}）"
            export Ali_Key="$ALI_KEY"
            export Ali_Secret="$ALI_SECRET"
            DNS_SERVICE="dns_ali"
            break
            ;;
        "腾讯云(DNSPod)")
            read -s -p "• 请输入DNSPod SecretId（输入时不显示，粘贴后按回车）: " DP_ID
            echo
            if [ -z "$DP_ID" ]; then
                echo "❌ DNSPod SecretId 不能为空"
                exit 1
            fi
            echo "✓ 已接收 DNSPod SecretId（长度: ${#DP_ID}）"
            read -s -p "• 请输入DNSPod SecretKey（输入时不显示，粘贴后按回车）: " DP_KEY
            echo
            if [ -z "$DP_KEY" ]; then
                echo "❌ DNSPod SecretKey 不能为空"
                exit 1
            fi
            echo "✓ 已接收 DNSPod SecretKey（长度: ${#DP_KEY}）"
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

# 步骤 4: 选择 CA 机构
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

# 步骤 5: 自定义证书安装路径
read -p "» 请输入证书安装路径（默认 /root/）: " CERT_PATH
CERT_PATH=${CERT_PATH:-/root/}

# 移除路径末尾的斜杠（如果有）
CERT_PATH=${CERT_PATH%/}

# 确保目录存在
mkdir -p "$CERT_PATH"

# 步骤 6: 系统检测与依赖安装
echo "⏳ 正在检测系统环境..."
detect_os
echo "⏳ 正在安装系统依赖..."
install_deps

# 步骤 7: 安装 acme.sh
echo "⏳ 正在部署 acme.sh 客户端..."
curl -s https://get.acme.sh | sh >/dev/null
if [ -f "$HOME/.bashrc" ]; then
    source "$HOME/.bashrc" 2>/dev/null || true
fi
export PATH="$HOME/.acme.sh:$PATH"
if [ ! -x "$ACME_SH" ]; then
    echo "❌ acme.sh 安装失败或不可执行：$ACME_SH"
    exit 1
fi
"$ACME_SH" --upgrade --auto-upgrade 0 >/dev/null

# 步骤 8: 注册账户
echo "⏳ 正在向 $CA_SERVER 注册账户..."
"$ACME_SH" --register-account -m "$EMAIL" --server "$CA_SERVER" >/dev/null

# 步骤 9: 申请证书
echo "⏳ 正在签发 SSL 证书（DNS 验证）..."
if ! "$ACME_SH" --issue --dns "$DNS_SERVICE" -d "$DOMAIN" --server "$CA_SERVER" --force; then
    echo "❌ 证书签发失败，请检查："
    echo "   - 域名是否已正确解析"
    echo "   - API 密钥是否有 DNS 写入权限"
    echo "   - 网络连接是否正常"
    cleanup
fi

# 步骤 10: 安装证书
echo "⏳ 正在安装证书到系统目录..."
"$ACME_SH" --install-cert -d "$DOMAIN" \
    --key-file       "$CERT_PATH/$DOMAIN.key" \
    --fullchain-file "$CERT_PATH/$DOMAIN.crt" \
    --reloadcmd     "echo '» 证书已更新，请重启相关服务！'"

# 步骤 11: 配置自动续期
echo "⏳ 正在配置自动续期任务..."

# 生成续期脚本
cat > /root/renew_cert.sh <<EOF
#!/bin/bash
export PATH="\$HOME/.acme.sh:\$PATH"
ACME_SH="\$HOME/.acme.sh/acme.sh"

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
"\$ACME_SH" --renew -d "$DOMAIN" --server "$CA_SERVER" >> /root/acme_renew.log 2>&1

# 重新安装证书到指定路径
"\$ACME_SH" --install-cert -d "$DOMAIN" \
    --key-file       "$CERT_PATH/$DOMAIN.key" \
    --fullchain-file "$CERT_PATH/$DOMAIN.crt" \
    --reloadcmd     "echo '» 证书已更新，请重启相关服务！'" >> /root/acme_renew.log 2>&1
EOF

# 赋予续期脚本执行权限
chmod +x /root/renew_cert.sh
chmod 600 /root/renew_cert.sh
# 添加 cron 任务（每天 03:00 检查续期，先去重）
CRON_LINE="0 3 * * * /root/renew_cert.sh >> /root/acme_renew.log 2>&1"
(crontab -l 2>/dev/null | grep -Fv "/root/renew_cert.sh >> /root/acme_renew.log 2>&1"; echo "$CRON_LINE") | crontab -

# 完成提示
echo "✅ 部署完成！"
echo "────────────────────────────────────"
echo "证书路径:"
echo "  私钥文件: $CERT_PATH/$DOMAIN.key"
echo "  证书文件: $CERT_PATH/$DOMAIN.crt"
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
