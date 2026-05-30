---
name: yourssh-roadmap
description: Use when the user wants to refresh, update, or regenerate the yourssh project roadmap at docs/roadmap.md — e.g. after shipping a feature, bumping version, completing a sprint, or asking "cập nhật roadmap"
---

# YourSSH Roadmap Refresh

Cập nhật `docs/roadmap.md` cho repo yourssh dựa trên trạng thái thực tế của codebase + git history. Tránh viết roadmap tay từ đầu mỗi lần — chỉ diff cái đã có và đề xuất feature mới.

## When to use

- User nói "update roadmap", "refresh roadmap", "cập nhật roadmap", "version bump xong rồi"
- Sau khi merge feature lớn vào develop/master
- Khi prep cho sprint planning
- Khi version trong `app/pubspec.yaml` thay đổi

**Không dùng khi:** user muốn brainstorm feature mới hoàn toàn từ đầu (dùng `superpowers:brainstorming`) hoặc viết spec cho 1 feature cụ thể (dùng `superpowers:writing-plans`).

## Workflow

1. **Đọc state hiện tại** (chạy song song):
   - `Read docs/roadmap.md` — roadmap cũ
   - `Bash git log --oneline -30` — commit gần đây
   - `Bash grep -E "^version:" app/pubspec.yaml` — version hiện tại
   - `Bash ls app/lib/providers app/lib/services app/lib/widgets packages/` — surface code đã có
   - `Bash git tag --sort=-creatordate | head -10` — release đã ship

2. **Phân loại đã ship vs còn lại** bằng cách so commit messages + tên file mới với danh sách roadmap cũ. Move bullet đã ship lên section "Đã có" ở đầu doc.

3. **Update metadata**:
   - Dòng version: `Version hiện tại: X.Y.Z`
   - Dòng date: `cập nhật: YYYY-MM-DD` (dùng date thật, không hard-code)

4. **Hỏi user 1 câu** (qua `AskUserQuestion`):
   - Có feature mới cần thêm vào P0/P1/P2 không?
   - Có muốn re-prioritize cái gì không?
   - Nếu user nói "không, chỉ update cái đã ship" → bỏ qua bước 5.

5. **Áp dụng change của user** (nếu có) vào đúng bảng/section.

6. **Show diff trước khi commit**: `Bash git diff docs/roadmap.md`. Đợi user OK rồi mới gợi ý commit.

## Cấu trúc roadmap (phải giữ nguyên)

```
# YourSSH — Roadmap
> Định hướng + version + date
[Section "Đã có"]
## P0 — Phải có để giữ user "power"  (table 10 hàng)
## P1 — Khác biệt hóa & độ sâu DevOps  (sub-sections theo theme)
## P2 — Team / Enterprise
## Top 3 đề xuất cho sprint kế tiếp
## Cách dùng tài liệu này
```

Không đổi cấu trúc trừ khi user yêu cầu. P0 luôn là bảng (Feature / Mục đích / Ghi chú thực thi). P1 luôn chia theme.

## Detection heuristics — "feature này đã ship chưa"

| Feature roadmap nói | Check |
|---|---|
| Command Palette | `grep -r "CommandPalette\|command_palette" app/lib/` |
| Tag/group | `grep -E "tags\s*:" app/lib/models/host.dart` |
| SSH config import | `grep -r "ssh_config\|parseSSHConfig" app/lib/` |
| Workspace persistence | `grep -r "workspace\|restoreSession" app/lib/providers/` |
| Search-in-scrollback | `grep -r "searchBuffer\|scrollback.*search" app/lib/` |
| Kubernetes panel | `ls packages/ \| grep -i kube` |

Khi grep ra match thực sự (không phải comment/TODO), coi như đã ship → move sang "Đã có".

## Common mistakes

- ❌ Re-generate toàn bộ roadmap từ đầu → mất ý kiến user đã thêm trước đó. **Always read first, edit in place.**
- ❌ Hard-code ngày trong skill. **Always Bash `date +%Y-%m-%d`.**
- ❌ Commit luôn không show diff. **Always show diff and wait for approval.**
- ❌ Bỏ qua `packages/` khi detect feature đã ship — plugin folder cũng tính.
- ❌ Đổi cấu trúc section/table format → khó diff giữa các version.

## Output

Edit file `docs/roadmap.md` in place (không tạo file mới). Cuối cùng output 2–3 dòng tóm tắt:
- Có bao nhiêu item move sang "Đã có"
- Có bao nhiêu item mới thêm
- Đề xuất commit message (nhưng không tự commit).
