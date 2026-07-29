# 部署说明

`we.emoera.com` 是手写静态站。GitHub Actions 不运行测试，只负责组装发布包和部署；代码与内容检查应在推送前于本地完成。

## 分支策略

| 场景 | 工作流 | 行为 |
| --- | --- | --- |
| Pull Request | `ci.yml` | 组装并上传静态发布包，不接触部署 Secret，也不会部署 |
| 推送至 `main` | `ci.yml` + `deploy.yml` | 组装发布包并发布到源站 |
| 手动运行 `deploy.yml` | `deploy` / `rollback` / `list` | 发布、回滚或查看版本 |

`main` 是唯一自动部署的分支。

## 本地检查与预览

```bash
bash scripts/check-site.sh
bash scripts/build-site.sh dist
python3 -m http.server 8000
```

`scripts/check-site.sh` 会检查必需文件、本地资源引用、服务器端代码和疑似凭据。`scripts/build-site.sh` 将站点内容组装到 `dist/`，排除仓库元数据和维护文档。

## 发布与回滚

每次发布使用 UTC 时间戳和提交短 SHA 生成版本号。源站保存独立版本并原子切换当前版本，避免访客读到半更新内容；具体服务器目录、账号和网络拓扑不属于公开仓库。

发布完成后，工作流会直接回源确认：

- 当前版本已经切换；
- 首页返回 HTTP 200；
- `main.css`、`js/main.js` 和 `img/elogo.jpg` 可访问。

需要回滚时，在 GitHub Actions 中手动运行 **Deploy**：

- `operation: rollback`，版本留空：回到上一个版本；
- `operation: rollback`，填写版本：切换到指定版本；
- `operation: list`：查看可用版本。

## 成员内容

早期服务器端成员投稿入口已永久下线，不属于代码仓库或发布包。新增或修改成员资料请提交 Pull Request：

1. 将经授权的头像放入 `uploads/`；
2. 更新 `index.html` 中对应成员条目；
3. 本地运行 `bash scripts/check-site.sh`；
4. 合并至 `main` 后自动发布。

不要提交未获授权的图片、个人敏感信息或服务器端脚本。

## 缓存

站点使用 CDN，但 CSS 和 JavaScript 文件名没有内容哈希，因此不应设置长期不可变缓存。HTML 应保持可重新验证；正常发布通常不需要主动刷新 CDN。

## GitHub Actions Secrets

仓库需要配置以下 Secret：

| 名称 | 内容 |
| --- | --- |
| `DEPLOY_HOST` | 源站地址 |
| `DEPLOY_USER` | 受限部署账号 |
| `DEPLOY_SSH_KEY` | 专用部署私钥 |
| `DEPLOY_KNOWN_HOSTS` | 源站 SSH 主机公钥 |

部署账号应使用最小权限，并由服务器端限制为只能执行发布、回滚和版本查询操作。任何 Secret 都不得提交到仓库。
