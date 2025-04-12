# **SSL-Bot**

SSL-Bot 是一个自动化工具，用于通过 DNS 验证方式申请和续期 SSL/TLS 证书。支持 Cloudflare、阿里云、腾讯云（DNSPod）等主流 DNS 提供商，并兼容 Let's Encrypt、Buypass 和 ZeroSSL 等 CA 机构。

![License](https://img.shields.io/badge/license-MIT-green) ![Version](https://img.shields.io/badge/version-1.0-blue)

---

## **功能特点**

- **多 DNS 提供商支持**：
  - 支持 Cloudflare、阿里云、腾讯云（DNSPod）等主流 DNS 提供商。
  - 易于扩展，支持更多 DNS 服务商。

- **多 CA 机构兼容**：
  - 支持 Let's Encrypt、Buypass 和 ZeroSSL 等 CA 机构。

- **自动续期**：
  - 自动配置 Cron 定时任务，定期检查并续期证书。

- **系统环境检测**：
  - 自动检测操作系统类型并安装所需依赖。

- **用户友好性**：
  - 提供清晰的交互提示，确保用户轻松完成证书申请和管理。

---

## **快速开始**

### **1. 克隆项目**
```bash
git clone https://github.com/yourusername/SSL-Bot.git
cd SSL-Bot
```

### **2. 赋予脚本执行权限**
```bash
chmod +x SSL-Bot.sh
```

### **3. 运行脚本**
```bash
./SSL-Bot.sh
```

脚本会引导你完成以下步骤：
1. 输入域名和邮箱。
2. 选择 DNS 提供商（Cloudflare、阿里云、腾讯云）。
3. 输入 DNS 提供商的 API 密钥。
4. 选择 CA 机构（Let's Encrypt、Buypass、ZeroSSL）。

---

## **配置说明**

### **DNS 提供商配置**
根据所选的 DNS 提供商，输入相应的 API 密钥和邮箱：
- **Cloudflare**：
  - API 密钥：可以从 Cloudflare 控制台获取。
  - 注册邮箱：Cloudflare 账户的注册邮箱。

- **阿里云**：
  - AccessKey ID 和 AccessKey Secret：可以从阿里云控制台获取。

- **腾讯云（DNSPod）**：
  - SecretId 和 SecretKey：可以从腾讯云控制台获取。

### **CA 机构选择**
支持以下 CA 机构：
- **Let's Encrypt**：免费且广泛使用。
- **Buypass**：提供长期有效期的免费证书。
- **ZeroSSL**：支持免费和付费证书。

---

## **日志管理**

- 续期日志存储在 `/root/acme_renew.log` 中。
- 查看日志：
  ```bash
  tail -f /root/acme_renew.log
  ```

---

## **目录结构**

```
SSL-Bot/
├── SSL-Bot.sh          # 主脚本文件
├── README.md           # 项目说明文档
├── LICENSE             # 开源许可证（MIT）
├── config/             # 配置文件目录（可选）
│   ├── dns_config.sh   # DNS 提供商配置模板
│   └── acme_config.sh  # ACME 配置模板
└── logs/               # 日志目录
    └── acme_renew.log  # 续期日志文件
```

---

## **注意事项**

1. **域名解析**：
   - 确保域名已正确解析到目标服务器，否则可能导致证书签发失败。

2. **API 权限**：
   - 确保提供的 DNS API 密钥具有写入权限，以便脚本能够自动添加和删除 DNS 记录。

3. **网络连接**：
   - 确保服务器能够正常访问互联网，以便与 CA 机构通信。

4. **敏感信息保护**：
   - 不要将 API 密钥或私钥文件泄露给他人。
   - 建议对敏感文件设置严格的权限，例如：
     ```bash
     chmod 600 /root/*.key
     ```

---

## **常见问题**

### **Q1: 证书签发失败怎么办？**
A: 检查以下内容：
- 域名是否已正确解析。
- DNS API 密钥是否有写入权限。
- 网络连接是否正常。

### **Q2: 如何手动测试续期？**
A: 执行以下命令：
```bash
/root/renew_cert.sh
```

### **Q3: 如何查看续期日志？**
A: 使用以下命令查看日志：
```bash
tail -f /root/acme_renew.log
```

---

## **许可证**

本项目采用 [MIT 许可证](LICENSE)，允许任何人自由使用、修改和分发代码。

---

## **贡献**

欢迎提交 Issue 或 Pull Request，帮助改进本项目！如果你有任何建议或发现 Bug，请随时联系我。

---


