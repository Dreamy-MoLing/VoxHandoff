# VoxHandoff 配对式首次配置（Onboarding）设计基线

> 状态：**设计基线（待决策）**。本文件定义 v0.1.x 的首次配置体验升级方向：
> 以「配对」取代「配置」，解决当前首次使用流程对普通用户门槛过高的问题。
> 待与外部方案（ChatGPT）最终商讨后，作为 M6 onboarding 里程碑的实施依据；
> 未实施前不改变当前 spec/PRODUCT.md 4.1 的配置式流程。

## 1. 问题

当前首次配置模型像"开发者控制台"：
- Hermes 设置页要求用户理解并填写：HTTPS 地址、model、API key、profile path、测试连接；
- 语音设置页同时暴露 Hermes、Direct LLM、CA 导入、STT 类型/地址/Token、TLS policy、
  retention、Piper、GPT-SoVITS、speaker、reference audio 等大量内部概念；
- 对高级用户是合理的高级设置，对普通用户的首次使用流程不合理；
- 证书/HTTPS 信任（CA 安装 / Tailscale）对小白用户门槛高。

产品理念（spec 定义的"低摩擦、接近电话交流体验"）与 onboarding 之间缺一层收口。

## 2. 目标体验

普通用户第一次打开 VoxHandoff：

```
电脑端（Hermes / VoxHandoff）：
  → "连接手机" → 显示二维码

手机端：
  → 扫二维码 → "正在连接你的 Hermes" → 成功

随后：
  → 选择声音 → 完成
```

URL、端口、model、Session ID/Key、证书、API key、STT 地址**都不出现在默认路径**。
只有进入"高级 → 手动连接"才显示完整表单。

## 3. 技术方案：主机侧 bootstrap + QR 配对包 + 证书固定 + secure storage

### 3.1 二维码载荷（一次性配对包）

```
协议版本
Hermes endpoint（默认 https://<host>:8642）
profile
证书指纹（pin）
一次性 pairing token
过期时间（如 10 分钟）
```

手机扫码获得**预期证书指纹**，首次连接直接验证该证书——比"连上未知自签证书再问用户
是否信任"的裸 TOFU 更好：首次身份也有"主机屏幕 → 手机摄像头"这一条独立信任通道。

### 3.2 连接建立后

- 长期凭据进入 Android secure storage；
- certificate pin 与 Hermes/设备身份绑定；
- 证书突然变化 → **fail closed**，提示"服务器身份发生变化，需要重新配对"；
- model、capabilities、session 等**自动发现**；
- 原 URL / Key / model 表单全部移进「高级 → 手动连接」。

### 3.3 连接方式定位（按用户类型）

| 方式 | 定位 |
| --- | --- |
| 二维码 + certificate pin | **默认推荐路径** |
| Tailscale | 已在用 Tailscale 的用户可选"快捷路径" |
| 公网 HTTPS / Cloudflare Tunnel | 高级远程部署 |
| URL + API Key + CA | 专家手动配置 |
| 裸 TOFU（看到指纹点信任） | 手动连接时的 fallback |

产品不绑定 Tailscale，也不强迫用户学证书。

### 3.4 主机端 bootstrap 职责（克制）

- 只做：安装/配置 TLS terminator 的一次性工具，或长期极薄的 pairing proxy；
- **禁止**把冻结的 Gateway/Node 控制面重新造一遍；
- 主机侧仅暴露配对接口（签发 QR 载荷）+ 转发 Hermes 对话/STT/TTS 流量。

## 4. Companion Connection Bundle（数据模型方向）

一次配对后由主机告诉手机：

```
Hermes
 ├─ Chat endpoint
 ├─ STT endpoint
 ├─ TTS endpoint
 ├─ 能力
 ├─ 推荐模型/声音
 └─ 安全身份
```

手机 UI 只呈现：
- Hermes：已连接
- 语音识别：可用
- 声音：Bronya
- 通话模式：开启

点「高级」后才看到 provider、URL、TLS、retention 等。

## 5. 现有代码的对接点（已核实）

- `HermesChatHttpTransport` 允许注入 HttpClient → 可注入 pinning 逻辑；
- 凭据与配置已分离存储（`hermes_conversation_secret_store.dart`）；
- `isSafe` 已把 HTTPS/路径/origin 限制封装在 domain 层；
- Android release 已关闭 cleartext、只信任系统根 → 底线可保留；
- 视觉状态机对齐 Hermes 主链路（M5-SIG）是前置。

## 6. 待决策点

1. 主机端 bootstrap 做到多重：一次性工具 vs 长期薄 pairing proxy（倾向后者但必须克制）；
2. STT/TTS endpoint 是否纳入首次配对包（倾向纳入，避免用户二次撞配置墙）；
3. QR 扫描库选型（mobile_scanner / zxing 等）与最小权限；
4. 是否保留"手动连接"作为第一屏的高级入口（倾向保留）。

## 7. 影响

- spec/PRODUCT.md 4.1 首次配置章节需重写为配对流程；
- 新增主机侧 bootstrap 组件（命名避免与冻结 Gateway 混淆）；
- 安全边界增加 certificate pinning 语义（TOFU + pin）；
- 视觉/语音设置页重构为「状态总览 + 高级折叠」。
