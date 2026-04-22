use super::super::helpers::ensure_parent_dir;
use super::super::{Store, StoreResult};
use super::{SeedFiles, SeedIds};
use std::fs;

pub(super) fn write_seed_files(store: &Store, ids: &SeedIds) -> StoreResult<SeedFiles> {
    let report_file = store
        .paths
        .blobs_dir()
        .join("reports")
        .join(&ids.thread_id)
        .join("feasibility-report-v0.1.md");
    let material_file = store
        .paths
        .blobs_dir()
        .join("materials")
        .join(format!("{}-业务背景访谈.md", ids.material_id));

    ensure_parent_dir(&report_file)?;
    ensure_parent_dir(&material_file)?;
    fs::write(
        &report_file,
        concat!(
            "# AutoDev Delivery Control 可行性报告\n\n",
            "## 问题定义\n",
            "需求到交付之间链路割裂，缺少持续推进机制。\n\n",
            "## 目标用户\n",
            "独立开发者、小型软件团队。\n\n",
            "## 结论\n",
            "可行，建议进入受控立项。"
        ),
    )
    .map_err(|err| err.to_string())?;
    fs::write(
        &material_file,
        "访谈要点：需要一个可并行托管多个项目全生命周期的交付系统。",
    )
    .map_err(|err| err.to_string())?;

    Ok(SeedFiles {
        report_file,
        material_file,
    })
}
