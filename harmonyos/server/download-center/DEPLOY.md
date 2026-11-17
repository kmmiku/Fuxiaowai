# 独立下载引导页部署

此服务单独监听 TCP `18080`，只返回 `index.html`、`icon.png` 及平台标志图片；不连接分享服务、Node 主站或数据库。公开访问形式为 `http://<VPS 公网 IP>:18080/`。

将本目录的 `server.js`、`index.html`、`icon.png`、`android-logo.jpg`、`harmony-logo.jpg` 上传到 VPS 的 `/opt/fxw-download-center/`，并安装 unit：

```sh
sudo install -d -o root -g root -m 0755 /opt/fxw-download-center
sudo install -o root -g root -m 0644 server.js index.html icon.png /opt/fxw-download-center/
sudo install -o root -g root -m 0644 fxw-download-center.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now fxw-download-center
curl -fsS http://127.0.0.1:18080/ >/dev/null
```

云安全组和 VPS 主机防火墙都需要允许入站 TCP `18080`。上线后从外网检查页面和图标；备案状态、服务商策略与运营商网络可能仍会影响访问。此服务使用 HTTP 直连 IP，不提供 TLS。
