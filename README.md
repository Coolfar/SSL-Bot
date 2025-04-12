# SSL-Bot

SSL-Bot 是一个自动化工具，用于通过 DNS 验证方式申请和续期 SSL/TLS 证书。支持 Cloudflare、阿里云、腾讯云（DNSPod）等主流 DNS 提供商，并兼容 Let's Encrypt、Buypass 和 ZeroSSL 等 CA 机构。

## 功能特点
- 自动检测系统环境并安装依赖
- 支持多 DNS 提供商（Cloudflare、阿里云、腾讯云）
- 自动续期证书并通过 Cron 定时任务管理
- 易于扩展，支持更多 DNS 和 CA 机构

## 使用方法
1. 克隆项目到本地：
   ```bash
   git clone https://github.com/yourusername/SSL-Bot.git
   cd SSL-Bot
