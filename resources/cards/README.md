# 卡牌资源目录

正式卡牌建议使用 `CardDefinition` 资源保存：

- 稳定 `id`
- 显示标题与描述
- 费用、类型、标签
- 可组合的 `CardEffect` 列表

当前框架里的占位卡在 `GameRoot.gd` 运行时创建，后续可以迁移为 `.tres` 资源。

