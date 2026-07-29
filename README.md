# we-emoera-site

E时代团队展示站，线上地址 <https://we.emoera.com/>。手写静态站点，无框架、无运行时依赖。

主题衍生自 [zhheo/HeoWeb](https://github.com/zhheo/HeoWeb)，按其许可保留了 [`LICENSE`](LICENSE) 与页面内的来源标注，请勿移除。这个仓库公开源代码，但上游许可不是 OSI 标准开源许可证；使用和分发时仍须遵守其中的适用范围与署名要求。

## 目录

| 路径 | 内容 |
| --- | --- |
| `index.html` | 全部页面内容，包含现任/往届团队名单 |
| `main.css` | 主样式 |
| `qifalab-banner*.css` | 启发实验室横幅样式 |
| `js/` | 交互脚本 |
| `img/` | 站点图片与图标 |
| `uploads/` | 团队成员头像 |
| `jump/` | 跳转页 |

仓库公开前已移除所有未被站点引用的旧示例图和历史上传图。当前保留的图片均由页面直接使用，其版权与使用边界见 [`ASSETS.md`](ASSETS.md)。

## 本地预览

```bash
python3 -m http.server 8000    # http://127.0.0.1:8000/
```

## 修改内容

增删团队成员：改 `index.html`，头像放进 `uploads/`。提交前跑一下检查：

```bash
bash scripts/check-site.sh
```

## 提交与发布

GitHub Actions 只负责组装发布包和部署；结构、资源引用及凭据检查请在提交前于本地运行。PR 会组装并上传发布包，合并进 `main` 后自动发布到线上。站点上的老投稿入口已于 2026-07-29 下线，加成员一律走 PR。流程与所需 Secret 见 [`docs/deploy.md`](docs/deploy.md)。
