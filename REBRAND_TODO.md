# 品牌清理待定清单

已完成（本次）：
- Android `applicationId` / `namespace`：`su.soilzhu.chilleast` → `mou.mou.mou`
- Kotlin 包目录与包声明、Manifest 组件名、Proguard 规则同步改为 `mou.mou.mou`
- 直播闹钟 Action：`su.soilzhu.chilleast.LIVE_FIRE/END` → `mou.mou.mou.LIVE_FIRE/END`
- iOS `PRODUCT_BUNDLE_IDENTIFIER` → `mou.mou.mou` / `mou.mou.mou.RunnerTests`
- iOS 显示名 → 牛牛牛牛牛，`CFBundleName` → moumou
- 应用显示名（Android `android:label`）→ 牛牛牛牛牛

待定（等你拍板后再改）：
1. 品牌文案：`ChillEast` / 自在东湖 / 东湖 在多语言 arb、`main.dart`、AI 系统提示词、引导页、分享文案等处的统一替换名。
2. 作者信息：替换为你的链接/邮箱
   - `lib/features/profile/screens/help_feedback_screen.dart`（soilzhu80@gmail.com、github.com/SoilZhu、SoilZhu 署名）
   - `README.md`（官网、Release、R2、贡献者徽章、邮箱）
   - `lib/core/services/update_service.dart`（`_githubRepo = 'soilzhu/chilleast'`，需你提供新仓库）
3. 默认 AI 模型名 `soilzhu-latest`（各语言 `aiModelNameHint` + `scripts/translate_dialects.py`）
4. BFF：`chill_east_session` cookie 名、`chill_east_bff` 包名、启动日志 `ChillEast BFF`
5. 云备份文件名前缀 `chilleast-backup-` / `chilleast-modern-` / `chilleast-sidecar-v2.json`（改动会导致旧备份无法自动识别，需单独评估）
6. CI 产物名 `chilleast-debug-<sha>`（`.github/workflows/ci.yml`）
7. 注释/文档：`.agents/skills/i18n-workflow/SKILL.md`、`assets/scripts/info_portal_md2.*`、`lib/features/workspace/utils/info_portal_theme.dart`
8. 测试内断言字符串（如 `ChillEast-MCP-Server`），需随品牌文案一起改
