# 爆炸蒟蒻历险记

Godot 4.x 原生 2D 卡牌游戏框架。主角为 `ExplodingKonjac`，题材围绕 OI 与 XCPC，目标类型是杀戮尖塔式 Roguelike Deckbuilder。

当前阶段只搭建工程框架，不锁定具体数值、卡牌数据和完整玩法。

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

## 后续建议

1. 定义第一批卡牌、敌人和遗物资源。
2. 完成抽牌、费用、弃牌、敌人意图和回合结算。
3. 增加地图、事件、奖励和存档。
4. 用 Godot 编辑器打开项目，生成导入缓存并运行主场景。

