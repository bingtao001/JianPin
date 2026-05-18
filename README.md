# JianPin 简拼通讯录

一键为通讯录联系人添加拼音属性，解决 iPhone 通讯录排序错乱。

> **Mac 运行一次，iPhone 自动生效**（通过 iCloud 同步）

<p align="center">
  <img src="Resources/AppIcon.icns" width="128" alt="简拼通讯录">
</p>

---

## 使用前必读

### 必要条件

| 条件 | 说明 |
|------|------|
| 同一 Apple ID | Mac 与 iPhone 必须登录**同一个 Apple ID** |
| 开启 iCloud 通讯录同步 | Mac：系统设置 → Apple ID → iCloud → **通讯录**（必须打开） |
| iPhone 同步已开启 | iPhone：设置 → Apple ID → iCloud → 通讯录（已打开） |

如果 Mac「通讯录」App 里看不到 iPhone 上的联系人，说明 iCloud 同步未开启，App 无法处理这些联系人。

### 工作原理

App 修改的是 **Mac 本地通讯录数据库**，修改后通过 iCloud 自动同步到 iPhone。**不需要在 iPhone 上安装任何东西。**

---

## 使用方法

### 安装

1. [下载最新版](https://github.com/lexrus/JianPin/releases) `简拼通讯录.app`
2. 拖入 `Applications` 文件夹
3. 双击打开
4. 如有安全提示，前往 系统设置 → 隐私与安全性 → 仍要打开

### 操作步骤

1. 点击 **「开始整理」**
2. 首次使用会弹出通讯录权限授权，点击「允许」
3. 等待处理完成（环形进度条显示进度）
4. 可选：点击 **「查找重复联系人」** → **「一键合并」**
5. 等待 iCloud 同步（约 1-5 分钟）
6. 打开 iPhone「电话」或「通讯录」App，联系人已按拼音首字母排序

---

## 功能

| 特性 | 说明 |
|------|------|
| 智能去重 | 已有拼音的联系人自动跳过，不重复处理 |
| 多音字姓氏 | 65+ 特殊姓氏词典（盖→Ge、曾→Zeng、解→Xie、单→Chan 等） |
| 组织名支持 | 仅有公司名没有姓名的联系人也会处理拼音 |
| 暂停/继续 | 处理过程中可随时中断 |
| 撤销操作 | 一键恢复原始数据 |
| 合并重复 | 自动查找并合并同名联系人（合并电话和邮箱后删除重复项） |
| 深色模式 | 跟随系统自动切换 |
| 隐私保护 | 纯本地运行，不上传任何数据 |

---

## 注意事项

1. **同步需要时间** — iCloud 同步不是即时的，完成后等 1-5 分钟再去 iPhone 上查看
2. **不影响现有数据** — 只添加拼音属性，不修改姓名、电话、邮箱等其他信息
3. **已跳过的联系人** — 已有拼音的联系人不会重复处理
4. **撤销仅限本次运行** — 关闭 App 后撤销备份会丢失，操作前建议手动备份通讯录
5. **处理失败** — 极少情况下系统可能写入失败，重试即可

---

## 自行编译

### 系统要求

- macOS 12.0+（Monterey）
- Apple Silicon / Intel
- Xcode 14+ 或 Command Line Tools

### 编译步骤

```bash
git clone https://github.com/lexrus/JianPin.git
cd JianPin
./build-app.sh
```

编译产物在 `.build/release/简拼通讯录.app`

### 运行测试

```bash
swift test
```

---

## 隐私

- 纯本地运行，不需要网络权限
- 不上传任何数据
- 不追踪用户
- 开源代码可审计

---

## 技术栈

- SwiftUI — macOS 原生 UI 框架
- Contacts (CNContactStore) — Apple 通讯录框架
- CFStringTransform — 中文拼音转换
- Swift Package Manager — 包管理和构建

---

## 开源协议

MIT License