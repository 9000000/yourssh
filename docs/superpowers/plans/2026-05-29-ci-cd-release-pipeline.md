# CI/CD Release Pipeline Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Tạo GitHub Actions workflow tự động build YourSSH cho macOS và Windows khi push lên `master`, sau đó publish GitHub Release với 2 file đính kèm.

**Architecture:** Một file workflow duy nhất (`.github/workflows/release.yml`) với 3 job: `build-macos` và `build-windows` chạy song song trên runner tương ứng, sau đó `release` gom artifact và tạo GitHub Release. Version lấy từ `app/pubspec.yaml`.

**Tech Stack:** GitHub Actions, `subosito/flutter-action@v2`, `actions/upload-artifact@v4`, `actions/download-artifact@v4`, `softprops/action-gh-release@v2`

---

## File Structure

- **Create:** `.github/workflows/release.yml` — toàn bộ pipeline CI/CD

---

### Task 1: Tạo thư mục và file workflow

**Files:**
- Create: `.github/workflows/release.yml`

- [ ] **Step 1: Tạo thư mục `.github/workflows/`**

```bash
mkdir -p .github/workflows
```

- [ ] **Step 2: Tạo file `release.yml` với nội dung đầy đủ**

Tạo file `.github/workflows/release.yml`:

```yaml
name: Release

on:
  push:
    branches:
      - master

permissions:
  contents: write

jobs:
  build-macos:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4

      - uses: subosito/flutter-action@v2
        with:
          channel: stable

      - name: Install dependencies
        working-directory: app
        run: flutter pub get

      - name: Build macOS
        working-directory: app
        run: flutter build macos --release

      - name: Zip macOS app
        run: zip -r YourSSH-macos.zip "app/build/macos/Build/Products/Release/YourSSH.app"

      - uses: actions/upload-artifact@v4
        with:
          name: macos-build
          path: YourSSH-macos.zip

  build-windows:
    runs-on: windows-latest
    steps:
      - uses: actions/checkout@v4

      - uses: subosito/flutter-action@v2
        with:
          channel: stable

      - name: Install dependencies
        working-directory: app
        run: flutter pub get

      - name: Build Windows
        working-directory: app
        run: flutter build windows --release

      - name: Zip Windows build
        run: Compress-Archive -Path "app\build\windows\x64\runner\Release\*" -DestinationPath "YourSSH-windows.zip"

      - uses: actions/upload-artifact@v4
        with:
          name: windows-build
          path: YourSSH-windows.zip

  release:
    runs-on: ubuntu-latest
    needs: [build-macos, build-windows]
    steps:
      - uses: actions/checkout@v4

      - name: Extract version from pubspec.yaml
        id: version
        run: |
          VERSION=$(grep '^version:' app/pubspec.yaml | sed 's/^version:[[:space:]]*//')
          echo "version=$VERSION" >> $GITHUB_OUTPUT

      - uses: actions/download-artifact@v4
        with:
          name: macos-build

      - uses: actions/download-artifact@v4
        with:
          name: windows-build

      - uses: softprops/action-gh-release@v2
        with:
          tag_name: v${{ steps.version.outputs.version }}
          name: YourSSH v${{ steps.version.outputs.version }}
          generate_release_notes: true
          files: |
            YourSSH-macos.zip
            YourSSH-windows.zip
```

- [ ] **Step 3: Verify YAML syntax hợp lệ**

```bash
python3 -c "import yaml; yaml.safe_load(open('.github/workflows/release.yml'))" && echo "YAML OK"
```

Expected output: `YAML OK`

- [ ] **Step 4: Commit**

```bash
git add .github/workflows/release.yml
git commit -m "feat: add GitHub Actions CI/CD pipeline for macOS and Windows release"
```

---

### Task 2: Push và verify pipeline chạy đúng

- [ ] **Step 1: Push lên master**

```bash
git push origin master
```

- [ ] **Step 2: Theo dõi Actions trên GitHub**

Vào tab **Actions** trên GitHub repo → chọn workflow run mới nhất → kiểm tra:
- `build-macos` job chạy thành công (khoảng 8-12 phút)
- `build-windows` job chạy thành công (khoảng 8-12 phút)
- `release` job chạy sau khi cả 2 xong

- [ ] **Step 3: Verify GitHub Release được tạo**

Vào tab **Releases** trên GitHub repo → kiểm tra:
- Release tên `YourSSH v0.1.0+1` (hoặc version hiện tại trong pubspec.yaml)
- Có đính kèm `YourSSH-macos.zip` và `YourSSH-windows.zip`
- Release notes được auto-generate từ commit messages

---

## Troubleshooting thường gặp

**macOS build lỗi "Xcode not found":**
- `macos-latest` runner có sẵn Xcode, nhưng nếu lỗi thì thêm step:
```yaml
- uses: maxim-lobanov/setup-xcode@v1
  with:
    xcode-version: latest-stable
```

**Windows build lỗi "Visual Studio not found":**
- `windows-latest` runner có sẵn VS Build Tools. Nếu vẫn lỗi, thêm:
```yaml
- name: Setup VS
  uses: microsoft/setup-msbuild@v2
```

**`release` job lỗi "tag already exists":**
- `softprops/action-gh-release@v2` sẽ update release nếu tag đã tồn tại — không cần làm gì thêm.
- Nếu muốn tránh release rác, cân nhắc đổi trigger sang push tag `v*` sau này.

**Version extraction ra sai:**
- Test locally: `grep '^version:' app/pubspec.yaml | sed 's/^version:[[:space:]]*//'`
- Expected output: `0.1.0+1`
