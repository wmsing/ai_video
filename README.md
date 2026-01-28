# AI Video App

一個整合影片下載、字幕提取與壓制功能的 Flutter 應用程式，支援 macOS 和 Web 部署。

# BLoC
-  UI 和邏輯分離

## Step
1. 設計 UI
先建立 UI 畫面（如 DownloadPage 和 DownloadView），包含輸入欄位、按鈕、進度條等元件。

2. 定義事件（Event）
在 blocs/download_event.dart 定義所有可能的事件，例如：
StartDownload：用戶點擊下載時觸發。

3. 定義狀態（State）
在 blocs/download_state.dart 定義所有 UI 可能呈現的狀態，例如：

DownloadInitial：初始狀態
DownloadLoading：下載中（可帶進度）
DownloadSuccess：下載完成
DownloadError：下載失敗

4. 實作 BLoC
在 blocs/download_bloc.dart：

監聽事件（如 StartDownload）
執行下載邏輯
根據進度或結果發出不同狀態

5. UI 綁定 BLoC
在 UI（如 DownloadPage）用 BlocProvider 提供 BLoC 實例，並用 BlocBuilder 監聽狀態變化，根據不同狀態更新畫面（顯示進度、錯誤、成功等）。

6. 觸發事件
UI 互動（如按下「下載」按鈕）時，呼叫 context.read<DownloadBloc>().add(StartDownload(...)) 來觸發事件。

## 總結流程：
建 UI → 定義 Event → 定義 State → 實作 BLoC →
UI 用 BlocProvider/BlocBuilder 綁定 →
UI 互動時 add Event

## CI/CD

This project uses GitHub Actions for continuous integration and deployment.

### CI Pipeline

The CI pipeline runs on every push and pull request to main/master/develop branches and includes:

- **Code Analysis**: Flutter analyze and format checking
- **Testing**: Unit tests with code coverage reporting
- **Build Verification**: 
  - iOS build (macOS runner)
  - macOS build
  - Web build
- **Deployment**: Automatic deployment to GitHub Pages for web version

### Build Artifacts

After successful CI/CD runs, you can download the following build artifacts from the Actions tab:

- **macOS App**: `macos-app` - macOS application bundle
- **Web Build**: `web-build` - Static web files for deployment

### Web Deployment

The web version is automatically deployed to: https://wmsing.github.io/ai_video/

**Note**: The web version provides a demo interface but requires server-side components (Python AI tools) for full functionality. For complete features, use the macOS desktop application.

### Status Badges

[![CI](https://github.com/wmsing/ai_video/workflows/CI/CD/badge.svg)](https://github.com/wmsing/ai_video/actions)
[![codecov](https://codecov.io/gh/wmsing/ai_video/branch/main/graph/badge.svg)](https://codecov.io/gh/wmsing/ai_video)

### Local Development

Before pushing code, run these commands locally:

```bash
# Install dependencies
flutter pub get

# Run analysis
flutter analyze

# Run tests
flutter test --coverage

# Check formatting
flutter format --set-exit-if-changed .

# Build for your platform
flutter build macos --release  # or ios, web
```

### CI/CD Monitoring

- **Actions Tab**: Monitor build status at https://github.com/wmsing/ai_video/actions
- **Coverage Reports**: View test coverage at https://codecov.io/gh/wmsing/ai_video
- **Web App**: Access deployed version at https://wmsing.github.io/ai_video/
- **Artifacts**: Download build outputs from successful workflow runs

## 功能特色

- **影片下載**：支援 YouTube 與 M3U8 串流下載
- **AI 字幕提取**：使用 Whisper AI 自動生成字幕
- **字幕壓制**：將字幕燒錄進影片檔案
- **劇情短片生成**：根據時間線 JSON 生成精華片段
- **跨平台部署**：支援在不同 Mac 電腦上安裝使用

## 系統需求

- **macOS 版本**: macOS 12.0 或以上, Python 3.8+, FFmpeg
- **Web 版本**: 現代瀏覽器 (Chrome, Firefox, Safari), 需搭配後端服務使用

## 部署到目標 Mac 電腦

### 步驟 1: 建置應用程式

在開發電腦上執行：

```bash
# 確保 Flutter 環境正確
flutter doctor

# 建置 macOS Release 版本
flutter build macos --release
```

建置完成後，應用程式會在 `build/macos/Build/Products/Release/ai_video.app` 目錄下。

### 步驟 2: 打包應用程式

#### 選項 A: 直接複製 .app 檔案

1. 找到 `build/macos/Build/Products/Release/ai_video.app`
2. 將整個 `.app` 資料夾複製到目標 Mac 的應用程式資料夾 (`/Applications/`) 或任何位置

#### 選項 B: 建立 DMG 安裝包 (推薦)

1. 安裝 `create-dmg` 工具：
   ```bash
   brew install create-dmg
   ```

2. 建立 DMG：
   ```bash
   cd build/macos/Build/Products/Release
   create-dmg --volname "AI Video App" --volicon ai_video.app/Contents/Resources/AppIcon.icns --window-pos 200 120 --window-size 800 400 --icon-size 100 --icon ai_video.app 200 190 --hide-extension ai_video.app --app-drop-link 600 185 "AI_Video_Installer.dmg" ai_video.app
   ```

3. 將產生的 `.dmg` 檔案傳送到目標 Mac 並雙擊安裝

### 步驟 3: 在目標 Mac 上設定 Python 環境

#### 下載並設定 AI 工具

1. **下載 tt_video 專案**：
   ```bash
   # 選擇一個工作目錄，例如 ~/Documents
   cd ~/Documents

   # 複製你的 tt_video 專案到此目錄
   # (從你的開發環境複製整個 tt_video 資料夾)
   git clone [你的 tt_video 倉庫] tt_video
   # 或直接複製資料夾
   ```

2. **建立 Python 虛擬環境**：
   ```bash
   cd tt_video
   python3 -m venv .venv  # 或 venv (根據你的偏好)
   ```

3. **安裝依賴套件**：
   ```bash
   source .venv/bin/activate
   pip install -r requirements.txt
   deactivate
   ```

#### 驗證環境設定

```bash
# 檢查 Python 環境
cd tt_video
source .venv/bin/python -c "import whisper; print('Whisper OK')"
source .venv/bin/python -c "import moviepy; print('MoviePy OK')"
```

### 步驟 4: 首次執行應用程式

1. **開啟應用程式**：
   - 如果是從 DMG 安裝，應用程式會自動出現在應用程式資料夾
   - 如果是直接複製，找到 `.app` 檔案並雙擊開啟

2. **設定路徑**：
   - **主資料夾**：選擇一個用來儲存下載影片的資料夾
   - **AI 工具路徑**：選擇剛才設定的 `tt_video` 資料夾路徑

3. **開始使用**：
   - 應用程式會檢查所有設定是否正確
   - 設定完成後即可開始使用所有功能

### 步驟 5: 疑難排解

#### 常見問題

**問題：應用程式顯示 "找不到 Python 環境"**
- 解決方案：確認 `tt_video` 資料夾內有 `.venv` 或 `venv` 目錄，且已正確安裝依賴

**問題：影片下載失敗**
- 解決方案：確認 FFmpeg 已安裝 (`brew install ffmpeg`)

**問題：字幕提取失敗**
- 解決方案：檢查 Python 環境是否完整，嘗試重新安裝依賴

**問題：應用程式無法開啟**
- 解決方案：檢查 macOS 安全性設定，允許從「任何來源」安裝應用程式

#### 檢查應用程式完整性

```bash
# 檢查應用程式結構
ls -la /Applications/ai_video.app/Contents/MacOS/
ls -la /Applications/ai_video.app/Contents/Resources/
```

### 檔案結構說明

```
ai_video.app/
├── Contents/
│   ├── MacOS/          # 可執行檔案
│   ├── Resources/      # 資源檔案
│   ├── Frameworks/     # Flutter 框架
│   └── Info.plist      # 應用程式資訊
```

### 更新應用程式

當有新版本時：
1. 重複步驟 1-2 建置新版本
2. 在目標 Mac 上關閉舊應用程式
3. 覆蓋安裝新版本
4. 重新開啟應用程式（設定會保留）

### 技術支援

如果遇到問題，請檢查：
- 終端機輸出訊息
- Python 環境是否正確設定
- 檔案權限設定
- macOS 版本相容性

---

**注意**：請確保在部署前測試所有功能正常運作。
