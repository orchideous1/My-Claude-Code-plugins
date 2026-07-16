# 工作流定位

本阶段属于 `arch` 工作流的 **CONNECT**。DRILL 已理解组件；本阶段追溯组件间关系。

**离开本阶段的验收标准**：
- 已描述数据流、控制流、事件流、状态归属、外部依赖；
- 已给出一个典型运行示例；
- 关系描述已写入 `.claude/state/sessions/<id>/session.md` 的 `context.relationships`；
- 如关系不清，返回 DRILL 补充。

## 输出格式与操作

追溯组件间关系。

对焦点区域映射：

- 数据流：数据如何进入、转换、离开？
- 控制流：谁发起调用？
- 事件流：发布/订阅、回调、钩子？
- 状态归属：每块状态存在哪里？
- 外部依赖：数据库、API、库
- 典型运行示例：给出一组具体参数/输入，说明系统如何走完一次完整流程

产出文本或 Mermaid 图。复杂的数据流建议用序列图，关键分支建议用带具体数值的例子说明。

更新 `.claude/state/sessions/<id>/session.md`：
- `current_phase`: CONNECT
- `context.relationships`
