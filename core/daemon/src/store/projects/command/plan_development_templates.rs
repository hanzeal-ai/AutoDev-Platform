use std::path::PathBuf;

pub(super) struct DevelopmentArtifactSpec {
    pub(super) id: &'static str,
    pub(super) name: &'static str,
    pub(super) title: &'static str,
    pub(super) kind: &'static str,
    pub(super) file_name: PathBuf,
    pub(super) content: String,
    pub(super) content_type: Option<&'static str>,
    pub(super) updated_at_ms: i64,
}

pub(super) fn render_frontend_tasks(project_name: &str) -> String {
    format!(
        r#"# {project_name} 前端任务拆分

## 目标
把项目交互收敛成可执行的页面、组件和状态任务，保证实现阶段按文件推进。

## 页面与路由
- 项目概览页：展示项目状态、阶段、最近事件和待办。
- 阶段详情页：展示研发阶段任务、产物和执行进展。
- 规划产物页：查看 `frontend-tasks.md`、`backend-tasks.md`、`api-contract.md`。

## 组件拆分
- 顶部项目标题和状态条。
- 阶段卡片和任务列表。
- 产物下载列表。
- 事件时间线。
- 空状态和错误状态。

## 状态依赖
- 项目详情数据。
- 阶段内容数据。
- stage_artifacts 列表。
- stage_events 列表。

## API 依赖
- `query.get_project_stage_detail`
- `command.plan_development`

## 文件边界
- 仅改前端展示层和状态组织。
- 不改后端契约和存储逻辑。

## 验证命令
- 以项目详情页为入口检查任务列表是否完整。
- 确认三个规划文件都能在阶段详情中看到。
"#
    )
}

pub(super) fn render_backend_tasks(project_name: &str) -> String {
    format!(
        r#"# {project_name} 后端任务拆分

## 目标
把项目后端实现拆成接口、数据、模块和验证任务，保证可直接进入编码。

## API endpoints
- `query.get_project_stage_detail`
- `command.plan_development`

## Request and response schema
- `command.plan_development` request:
  - `project_id: string`
- `command.plan_development.ok` response:
  - `project_id: string`
  - `stage: string`
  - `artifact_count: number`

## Data model or migration needs
- 使用现有 `projects`、`project_stages`、`stage_artifacts`、`stage_events`。
- 研发阶段需要写入阶段快照和产物路径。

## Module ownership
- `core/daemon/src/store/projects/command/plan_development.rs`
- `core/daemon/src/router/dispatch_command/plan_development.rs`

## Error codes
- `request_failed`
- `payload.project_id must be a string`
- `project_id must not be empty`
- `project not found`

## Logging and configuration needs
- 记录项目名称和生成结果数量。
- 不接真实模型服务，保持本地规划器可替换。

## Validation commands
- `cargo check`

## Contract compatibility checks
- 保持响应字段稳定。
- 保持 stage 仍然是 `development`。

## Files that must not be modified
- Swift 前端文件
- 根目录文档
- 非 `core/daemon/**` 文件
"#
    )
}

pub(super) fn render_api_contract(project_name: &str, project_id: &str) -> String {
    let project_id_json = serde_json::to_string(project_id).unwrap_or_else(|_| "\"\"".to_string());
    format!(
        r#"# {project_name} 接口契约

## Context
- project_id: `{project_id}`
- stage: `development`

## Command contract
### `command.plan_development`
Request:
```json
{{ "project_id": {project_id_json} }}
```

Response:
```json
{{ "project_id": {project_id_json}, "stage": "development", "artifact_count": 3 }}
```

## Stage artifacts
- `frontend-tasks.md`
- `backend-tasks.md`
- `api-contract.md`

## Compatibility rules
- 规划命令必须幂等地更新阶段快照。
- 阶段详情页读取到的 `downloads_json` 和 `work_units_json` 必须与文件内容一致。
- 不调用外部模型 API。
"#
    )
}
