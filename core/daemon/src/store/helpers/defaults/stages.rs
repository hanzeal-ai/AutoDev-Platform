use super::super::super::StageDownloadDefaults;
use super::super::super::StageDefaults;
use super::super::super::StageWorkUnitDefaults;
use serde_json::json;

pub(super) fn feasibility() -> StageDefaults {
    StageDefaults {
        objective: "完成可行性判断并形成受控立项决策",
        input_contexts: vec![
            "一句话概述：待补充",
            "问题定义：待补充",
            "目标用户：待补充",
            "当前立项结论：待评估",
        ],
        step_progress: json!([
            {"title":"需求澄清","status":"running"},
            {"title":"资料分析","status":"queued"},
            {"title":"立项确认","status":"awaiting_confirmation"}
        ]),
        risk_items: vec!["问题定义不闭合", "关键约束未完整", "资料结论冲突"],
        event_flow: vec!["需求挖掘", "报告更新", "立项确认"],
        primary_action: "确认立项",
        secondary_actions: vec!["继续讨论", "补充资料"],
        downloads: vec![
            StageDownloadDefaults {
                id: "feasibility-report",
                title: "可行性报告",
                category: "stage_snapshot",
                availability: "ready",
                file_path: None,
                updated_at_ms: None,
                content_type: Some("text/markdown"),
            },
            StageDownloadDefaults {
                id: "reference-materials",
                title: "参考资料原件",
                category: "raw_input",
                availability: "view_only",
                file_path: None,
                updated_at_ms: None,
                content_type: None,
            },
        ],
        work_units: vec![],
    }
}

pub(super) fn prd() -> StageDefaults {
    StageDefaults {
        objective: "冻结 PRD 范围边界、功能拆分与验收标准",
        input_contexts: vec![
            "范围内：总览、项目库、立项线程、阶段详情",
            "范围外：多人协作、外部插件市场",
            "核心场景：立项确认后进入阶段托管推进",
            "待确认点：验收口径是否包含回归基线",
        ],
        step_progress: json!([
            {"title":"范围收敛","status":"running"},
            {"title":"功能拆分","status":"running"},
            {"title":"验收标准冻结","status":"awaiting_confirmation"}
        ]),
        risk_items: vec!["范围膨胀", "需求不完整", "依赖未确认"],
        event_flow: vec!["PRD 生成", "PRD 调整", "用户确认"],
        primary_action: "确认 PRD",
        secondary_actions: vec![],
        downloads: vec![StageDownloadDefaults {
            id: "prd-snapshot",
            title: "PRD 快照",
            category: "stage_snapshot",
            availability: "pending",
            file_path: None,
            updated_at_ms: None,
            content_type: Some("text/markdown"),
        }],
        work_units: vec![],
    }
}

pub(super) fn ui() -> StageDefaults {
    StageDefaults {
        objective: "完成页面地图、交互流与关键组件定义",
        input_contexts: vec![
            "页面地图：待生成",
            "核心交互流：待生成",
            "关键组件：待生成",
            "视觉方向：简约控制台",
            "待确认设计点：待补充",
        ],
        step_progress: json!([
            {"title":"页面结构生成","status":"running"},
            {"title":"交互方案更新","status":"queued"},
            {"title":"设计确认","status":"awaiting_confirmation"}
        ]),
        risk_items: vec!["交互冲突", "信息架构不清", "视觉未定稿"],
        event_flow: vec!["页面结构生成", "交互更新", "设计确认"],
        primary_action: "跳过 UI，进入研发",
        secondary_actions: vec!["继续完善 UI"],
        downloads: vec![StageDownloadDefaults {
            id: "ui-snapshot",
            title: "UI 方案快照",
            category: "stage_snapshot",
            availability: "view_only",
            file_path: None,
            updated_at_ms: None,
            content_type: None,
        }],
        work_units: vec![],
    }
}

pub(super) fn development() -> StageDefaults {
    StageDefaults {
        objective: "完成前后端需求分析、任务拆分、Git/GitHub 协作、编码审查循环、稳定预览与交付归档",
        input_contexts: vec![
            "前端需求分析：页面清单、路由表、组件拆分、状态依赖、API 依赖、frontend-tasks.md",
            "后端需求分析：接口契约、数据模型、模块拆分、错误码、部署配置、backend-tasks.md",
            "任务拆分：前后端各自形成可执行任务包，边界与依赖同步冻结",
            "Git/GitHub：agent/* 开发分支合入 develop，必要时同步 GitHub 仓库与 PR 状态",
            "稳定预览：只有 develop 验证通过后才能推进 preview，用户稳定预览只指向 preview",
            "编码循环：编码 -> Code Review -> 修复 Review -> 测试 -> 继续编码，直到完成标准闭环",
            "交付归档：构建产物、接口文档、预览记录、审查记录、测试报告与最终归档都要可追踪",
        ],
        step_progress: json!([
            {"title":"前后端需求分析", "status":"running"},
            {"title":"任务拆分与接口契约冻结", "status":"queued"},
            {"title":"Git/GitHub 分支策略确认", "status":"queued"},
            {"title":"前端编码 -> Review -> 修复 -> 测试", "status":"queued"},
            {"title":"后端编码 -> Review -> 修复 -> 测试", "status":"queued"},
            {"title":"develop 集成验证", "status":"queued"},
            {"title":"preview 稳定预览发布", "status":"queued"},
            {"title":"交付归档", "status":"queued"}
        ]),
        risk_items: vec!["接口契约未冻结会导致前后端返工", "develop 未验证直接预览会破坏用户稳定访问", "Code Review 修复未闭环会积累缺陷", "GitHub 仓库同步失败会影响源代码归档"],
        event_flow: vec![
            "生成前后端需求分析",
            "拆分任务并冻结契约",
            "创建 agent 开发分支并同步 GitHub",
            "执行编码与 Code Review 循环",
            "合入 develop 并集成验证",
            "推进 preview 稳定预览",
            "打包归档可下载产物",
        ],
        primary_action: "继续推进",
        secondary_actions: vec!["查看预览", "进入测试"],
        downloads: vec![
            StageDownloadDefaults {
                id: "frontend-tasks",
                title: "前端任务拆分",
                category: "stage_snapshot",
                availability: "pending",
                file_path: None,
                updated_at_ms: None,
                content_type: Some("text/markdown"),
            },
            StageDownloadDefaults {
                id: "backend-tasks",
                title: "后端任务拆分",
                category: "stage_snapshot",
                availability: "pending",
                file_path: None,
                updated_at_ms: None,
                content_type: Some("text/markdown"),
            },
            StageDownloadDefaults {
                id: "git-github-plan",
                title: "Git/GitHub 协作记录",
                category: "audit_archive",
                availability: "pending",
                file_path: None,
                updated_at_ms: None,
                content_type: Some("text/markdown"),
            },
            StageDownloadDefaults {
                id: "stable-preview",
                title: "稳定预览记录",
                category: "stage_snapshot",
                availability: "pending",
                file_path: None,
                updated_at_ms: None,
                content_type: Some("text/markdown"),
            },
            StageDownloadDefaults {
                id: "code-review-log",
                title: "Code Review 记录",
                category: "audit_archive",
                availability: "pending",
                file_path: None,
                updated_at_ms: None,
                content_type: Some("text/markdown"),
            },
            StageDownloadDefaults {
                id: "test-report",
                title: "测试报告",
                category: "audit_archive",
                availability: "pending",
                file_path: None,
                updated_at_ms: None,
                content_type: Some("text/markdown"),
            },
            StageDownloadDefaults {
                id: "delivery-archive",
                title: "交付归档",
                category: "audit_archive",
                availability: "pending",
                file_path: None,
                updated_at_ms: None,
                content_type: Some("application/zip"),
            },
        ],
        work_units: vec![
            StageWorkUnitDefaults {
                id: "requirement-analysis",
                title: "前后端需求分析",
                agent_role: "需求分析 Agent",
                status: "running",
                progress: 0.35,
                depends_on: vec![],
                current_output: Some("需求拆分草稿"),
                next_step: "冻结需求边界后生成任务拆分",
            },
            StageWorkUnitDefaults {
                id: "api-contract",
                title: "接口契约与架构选择",
                agent_role: "后端规划 Agent",
                status: "blocked",
                progress: 0.0,
                depends_on: vec!["requirement-analysis"],
                current_output: None,
                next_step: "等待需求分析完成",
            },
            StageWorkUnitDefaults {
                id: "frontend-task-split",
                title: "前端任务拆分",
                agent_role: "前端规划 Agent",
                status: "blocked",
                progress: 0.0,
                depends_on: vec!["requirement-analysis", "api-contract"],
                current_output: None,
                next_step: "等待接口契约后生成页面与组件任务",
            },
            StageWorkUnitDefaults {
                id: "backend-task-split",
                title: "后端任务拆分",
                agent_role: "后端规划 Agent",
                status: "blocked",
                progress: 0.0,
                depends_on: vec!["requirement-analysis", "api-contract"],
                current_output: None,
                next_step: "等待接口契约后生成模块与数据任务",
            },
            StageWorkUnitDefaults {
                id: "implementation-loop",
                title: "编码与 Code Review 循环",
                agent_role: "实现与审查 Agent",
                status: "blocked",
                progress: 0.0,
                depends_on: vec!["frontend-task-split", "backend-task-split"],
                current_output: None,
                next_step: "等待任务拆分完成后进入编码循环",
            },
            StageWorkUnitDefaults {
                id: "stable-preview-delivery",
                title: "稳定预览与交付归档",
                agent_role: "集成验证 Agent",
                status: "blocked",
                progress: 0.0,
                depends_on: vec!["implementation-loop"],
                current_output: None,
                next_step: "等待编码测试通过后推进 preview 并归档",
            },
        ],
    }
}

pub(super) fn testing() -> StageDefaults {
    StageDefaults {
        objective: "验证质量门禁并形成发布准入结论",
        input_contexts: vec![
            "测试范围：待补充",
            "通过率：待补充",
            "失败项：待补充",
            "阻塞项：待补充",
            "回归状态：待补充",
        ],
        step_progress: json!([
            {"title":"测试启动","status":"running"},
            {"title":"失败记录","status":"queued"},
            {"title":"验收确认","status":"awaiting_confirmation"}
        ]),
        risk_items: vec!["关键失败项", "阻塞未清", "质量未达标"],
        event_flow: vec!["测试启动", "失败记录", "回归通过"],
        primary_action: "确认发布",
        secondary_actions: vec![],
        downloads: vec![
            StageDownloadDefaults {
                id: "test-report",
                title: "测试报告",
                category: "audit_archive",
                availability: "ready",
                file_path: None,
                updated_at_ms: None,
                content_type: Some("text/markdown"),
            },
            StageDownloadDefaults {
                id: "acceptance-snapshot",
                title: "验收结论快照",
                category: "stage_snapshot",
                availability: "pending",
                file_path: None,
                updated_at_ms: None,
                content_type: Some("text/markdown"),
            },
        ],
        work_units: vec![],
    }
}

pub(super) fn release() -> StageDefaults {
    StageDefaults {
        objective: "完成发布准备、执行与回滚保障",
        input_contexts: vec![
            "版本信息：待补充",
            "发布准备：待补充",
            "检查项：待补充",
            "当前发布状态：待确认",
            "回滚条件：待补充",
            "上线窗口：待补充",
        ],
        step_progress: json!([
            {"title":"发布准备","status":"running"},
            {"title":"发布开始","status":"queued"},
            {"title":"结果确认","status":"awaiting_confirmation"}
        ]),
        risk_items: vec!["发布阻塞", "检查项未通过", "回滚风险"],
        event_flow: vec!["发布准备", "发布开始", "回滚执行"],
        primary_action: "确认发布",
        secondary_actions: vec![],
        downloads: vec![
            StageDownloadDefaults {
                id: "release-record",
                title: "发布记录",
                category: "audit_archive",
                availability: "pending",
                file_path: None,
                updated_at_ms: None,
                content_type: Some("text/markdown"),
            },
            StageDownloadDefaults {
                id: "rollback-archive",
                title: "回滚方案留档",
                category: "audit_archive",
                availability: "pending",
                file_path: None,
                updated_at_ms: None,
                content_type: Some("text/markdown"),
            },
        ],
        work_units: vec![],
    }
}

pub(super) fn maintenance() -> StageDefaults {
    StageDefaults {
        objective: "监控运行健康并沉淀下一轮优化建议",
        input_contexts: vec![
            "运行健康：待补充",
            "问题反馈：待补充",
            "已处理问题：待补充",
            "风险信号：待补充",
            "下一轮优化建议：待补充",
        ],
        step_progress: json!([
            {"title":"问题上报","status":"running"},
            {"title":"修复完成","status":"queued"},
            {"title":"建议生成","status":"queued"}
        ]),
        risk_items: vec!["运行异常", "反馈集中", "质量回落"],
        event_flow: vec!["问题上报", "修复完成", "维护观察"],
        primary_action: "记录问题",
        secondary_actions: vec!["触发新立项", "归档项目"],
        downloads: vec![
            StageDownloadDefaults {
                id: "maintenance-log",
                title: "维护记录",
                category: "audit_archive",
                availability: "pending",
                file_path: None,
                updated_at_ms: None,
                content_type: Some("text/markdown"),
            },
            StageDownloadDefaults {
                id: "follow-up-backlog",
                title: "下一轮优化建议",
                category: "stage_snapshot",
                availability: "pending",
                file_path: None,
                updated_at_ms: None,
                content_type: Some("text/markdown"),
            },
        ],
        work_units: vec![],
    }
}
