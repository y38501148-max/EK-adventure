# 开发文档

本项目使用 Godot 4.x 与 GDScript 构建，不使用纯前端 JS/TS 技术栈。

## 项目结构

```text
assets/        图像、音频、字体等资源
resources/     卡牌、效果、主题等静态定义
scenes/        Godot 场景
scripts/       GDScript 源码
tests/         后续测试目录
```

## 入口

- 主场景：`res://scenes/main/Main.tscn`
- 应用图标：`res://assets/art/icon.png`
- 基础运行框架：`res://scenes/game/GameRoot.tscn`

## 平台

项目配置面向桌面端，包含 Windows 与 macOS 导出预设骨架。正式打包前需要在本机 Godot 编辑器中安装对应导出模板，并补齐签名、公证、输出路径等平台细节。

## 当前框架

- `Settings`、`SceneRouter`、`SaveManager` 作为全局服务。
- `GameState` 保存回合、能量、牌堆、手牌、弃牌堆等运行时状态。
- `CardDefinition` 与 `CardEffect` 作为后续数据驱动卡牌的基础资源。
- `Main`、`GameRoot`、`Hud`、`HandView`、`CardView` 组成当前可启动的基础界面。

## 后续建议

1. 定义第一批卡牌、敌人和遗物资源。
2. 完成抽牌、费用、弃牌、敌人意图和回合结算。
3. 增加地图、事件、奖励和存档。
4. 在 Godot 编辑器中生成导入缓存并运行主场景。

