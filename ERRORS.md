# ERRORS

## Godot GDScript 类型推断

- 问题：`var can_drop := data is Dictionary and data.get("kind", "") == "card"` 会报错，原因是 `data` 是 `Variant`，Godot 不能稳定推断表达式结果类型。
- 避免：涉及 `Variant`、`Dictionary`、`Array` 混合判断时，显式写类型，例如 `var can_drop: bool = ...`。

## Typed Array 参数

- 问题：函数参数写成 `targets: Array[int]` 后，调用 `play_card(card_id, [0])` 会因为 `[0]` 是普通 `Array` 而类型不匹配。
- 避免：UI 信号、测试字面量和数据驱动入口优先使用 `Array`，在函数内部校验元素是否能转成目标 id。

## Typed Export 数组赋值

- 问题：`RunConfig.starting_deck` 是 `Array[Resource]`，直接赋值 `[card]` 会被 Godot 判定为普通 `Array`，出现类型不匹配。
- 避免：先声明 `var deck: Array[Resource] = [card]`，再赋值给导出数组。

## 手写场景的唯一节点路径

- 问题：手写 `.tscn` 后直接在脚本里用 `%SlotLabel` 读取节点，运行时出现 `Node not found`。
- 避免：手写场景优先使用完整 `$Root/Columns/...` 路径；需要 `%Name` 时最好由 Godot 编辑器维护 `unique_name_in_owner`。
