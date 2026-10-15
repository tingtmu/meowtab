# 喵塔布（MeowTab）

**Windows 11 風格的 Alt+Tab，多了一隻從邊緣探頭的貓。**

[English](README.md) | 繁體中文

喵塔布用即時視窗預覽取代 Alt+Tab，搭配隨淺色和深色模式切換的磨砂壓克力窗格。預設的 Velvet 外觀乍看很有 Windows 原生的感覺，細看則更柔和溫暖；Windows 11 外觀則忠實呈現 Windows 原本的樣子。一張圖片從左上緣探出頭來，隨著開啟的視窗數量改變。視窗少時，是一隻打瞌睡的貓；視窗多了，就變成肚皮朝上、攤平的貓。換上自己的圖片，讓你的寵物、吉祥物，甚至老闆來評斷你開了多少視窗。

![喵塔布](docs/meowtab.png)
*Velvet（預設）*

![Windows 11 外觀的喵塔布](docs/meowtab-windows11.png)
*Windows 11*

![動畫貓咪從窗格上方探頭的喵塔布](docs/meowtab-gif.gif)

每種心情都能選用 GIF，並在探頭圖中播放。
喵塔布的 `images` 資料夾附了一張 `chill.gif`（預設仍使用 PNG 貓咪圖片）。

> **狀態：早期預覽版。** 喵塔布源自 [peek-alttab](https://github.com/tingtmu/peek-alttab)，目前正逐步打磨成完整的程式；詳見[開發藍圖](ROADMAP.md)。

## 功能

- **兩種外觀。** 壓克力窗格上有即時縮圖、程式圖示與標題。**Velvet** 加入溫暖的玻璃質感、更圓潤的方塊、柔和的選取外框，以及窗格邊緣逐漸淡出的列；**Windows 11** 則使用 Windows 的輔色選取環。兩者都會配合 Windows 的淺色和深色模式與輔色。
- **探頭圖。** 心情圖片從窗格左上緣向上滑出，開的視窗越多，就探得越高：

  | 心情 | 視窗數量（預設） | 預設圖片 |
  | --- | --- | --- |
  | few | 1-2 | 蜷成一團睡覺的貓 |
  | some | 3-7 | 悠閒躺著的貓 |
  | many | 8+ | 肚皮朝上攤平的貓，累到懶得管了…… |

- **自己的圖片。** 在設定面板中選取或拖放圖片；**Clean background**（去背）能去除單純的淺色背景，並裁切成正方形。
- **鍵盤與滑鼠。** 在格狀排列中移動、關閉視窗，或點選方塊切換到該視窗。
- **所有螢幕。** 視窗依最近使用的順序排列；窗格會出現在作用中視窗所在的螢幕上（若沒有，則在游標所在的螢幕）。只列出目前虛擬桌面和視窗管理器中可見工作區的視窗。重新排列視窗不會打亂清單順序。勾選 **Only this monitor's windows** 可將範圍限於窗格所在的螢幕。
- **清楚易讀的標題。** 有安裝 Noto Sans TC 時就使用它，否則使用 Segoe UI；也能在面板中選用任何已安裝的字型。

![深色模式的喵塔布](docs/meowtab-dark.png)
*Velvet（預設）*

![深色模式下 Windows 11 外觀的喵塔布](docs/meowtab-windows11-dark.png)
*Windows 11*

## 快速開始

需要 64 位元的 Windows 11。壓克力窗格需要 22H2 或更新版本；較舊版本會顯示不透明窗格。發行版的執行檔不需要 AutoHotkey。更新或移除前，請先從系統匣結束喵塔布；移除前也請先在系統匣選單中取消勾選 **Start at login**。設定與圖片會保留在 `%APPDATA%\MeowTab`，除非你[一併刪除](#移除喵塔布)。

**PowerShell**（5.1 或 7）：安裝並啟動最新發行版，不需要系統管理員權限或套件管理器。[安裝輔助程式的原始碼](https://github.com/tingtmu/meowtab/blob/main/tools/install.ps1)可直接閱讀；它會從同一個發行版下載 ZIP 及其雜湊值，確認檔案無誤後才安裝。

```powershell
& ([scriptblock]::Create((Invoke-WebRequest -UseBasicParsing 'https://raw.githubusercontent.com/tingtmu/meowtab/main/tools/install.ps1').Content))
```

程式會安裝到 `%LOCALAPPDATA%\Programs\MeowTab`。再次執行相同指令即可更新；刪除該資料夾即可移除。日後可用 `& "$env:LOCALAPPDATA\Programs\MeowTab\meowtab.exe"` 啟動。已安裝的版本標籤記錄在該資料夾的 `.zip-install.json` 中，也能從執行檔的檔案版本查看。

AI 代理：請閱讀精簡的[安裝與更新指南](https://raw.githubusercontent.com/tingtmu/meowtab/main/llms.txt)。

**WinGet**（Windows 11 內建；目前等待 Microsoft 核准，在此之前請使用 Scoop 或 ZIP）：

```
winget install tingtmu.MeowTab
```

開啟新的終端機，執行 `meowtab`（或 `meowtab-classic`）。WinGet 不會新增開始功能表項目。使用 `winget upgrade tingtmu.MeowTab` 更新；使用 `winget uninstall tingtmu.MeowTab` 解除安裝。

**Scoop**（套件庫需要 git：`scoop install git`）：

```
scoop bucket add meowtab https://github.com/tingtmu/meowtab
scoop install meowtab/meowtab
```

安裝及每次更新後都會啟動；日後可從開始功能表的 **Scoop Apps > MeowTab**（或 **MeowTab Classic**）啟動。使用 `scoop update`，接著執行 `scoop update meowtab` 更新；使用 `scoop uninstall meowtab` 解除安裝。

**可攜式 ZIP：** 從[最新發行版](https://github.com/tingtmu/meowtab/releases/latest)或[直接下載連結](https://github.com/tingtmu/meowtab/releases/latest/download/meowtab.zip)下載 `meowtab.zip`，[檢查下載檔案](#檢查下載檔案)，解壓縮到自己的資料夾，並將資料夾中的檔案保留在一起。按兩下 `meowtab.exe`。重新下載並解壓縮最新發行版即可更新；刪除程式資料夾即可移除。

**首次啟動：** 喵塔布第一次啟動時，會設定為登入時自動啟動，並詢問是否要在桌面放置一個可開啟設定面板的圖示；無論選哪個答案，都會記住。接著按住 **Alt** 再按 **Tab**。按兩下系統匣中打瞌睡的貓咪圖示即可開啟面板；按右鍵可重新載入、結束、勾選 **Desktop icon**，或取消勾選 **Start at login**，讓它不再於登入時啟動。

`meowtab-classic.exe`（經典版）是原本的版面：標題清單旁有一個大型預覽，圖片則在窗格內的左下角。兩個程式一次只能執行其中一個。從原始碼執行的方法請見 [CONTRIBUTING.md](CONTRIBUTING.md)。

## 使用方式

按住 **Alt**，然後：

| 按鍵 | 動作 |
| --- | --- |
| `Tab` / `Shift+Tab` | 下一個／上一個視窗 |
| `Right` / `Left` | 下一個／上一個視窗 |
| `Down` / `Up` | 下方／上方的方塊 |
| 放開 `Alt` | 切換到選取的視窗 |
| `Esc` | 取消，不切換視窗 |
| `Delete` | 關閉選取的視窗，並保持切換器開啟 |

按住 **Alt** 時，點選方塊即可切換視窗，或將滑鼠移到方塊上，點選 **×** 關閉視窗。使用滑鼠滾輪或拖曳窗格右側的捲軸捲動。第一次按 Tab 會選取你先前使用的視窗；詢問「是否儲存變更？」的程式會留在清單中，直到你回應。

**Ctrl+Alt+Tab** 會開啟放開按鍵後仍保持開啟的切換器。相同的按鍵與滑鼠操作都能使用；**Enter** 切換視窗，**Esc** 取消。點選切換器外側會關閉它，並讓點擊穿透，因此點選某個視窗就會切換到該視窗。開啟期間，其他按鍵不會有作用。

兩組快速鍵都能在[設定面板](#設定面板)中變更，例如改成 Win+Q。經典版保留 Alt+Tab，沒有保持開啟的切換器，面板中也沒有 **Look**、**Background** 或 **Shortcuts** 區段。

## 設定面板

按兩下系統匣圖示，或按右鍵選擇 **Settings…**。桌面圖示也能開啟面板。

![設定面板](docs/settings.png)

- **Mood images**（心情圖片）：點選心情卡片來選擇 PNG、JPG、BMP 或 GIF，也能直接拖放圖片。檔案選擇視窗會開在內附的 `images` 資料夾（`chill.gif` 和 `chill_*.png`）。GIF 會在卡片與探頭圖中播放；數值調整按鈕用來設定「some」與「many」從幾個視窗開始。
- **Clean background**（去背）：圖片卡片上的 **✧ Clean** 會去除單純的淺色背景，並裁切成正方形。GIF 會逐格去背，再裁切成同一個正方形；因為 GIF 沒有半透明效果，邊緣會較生硬。
- **Peek height**（探頭高度）：設定只有一個視窗和達到「many」時，要露出多少圖片；兩個情境預覽會顯示你的圖片。
- **Look**（外觀）：點選 **Velvet** 或 **Windows 11**，也能在卡片上按 Space。勾選記號表示你的選擇，**in use** 表示目前使用的外觀；情境預覽與標題範例會預覽選擇的效果，按 **Save** 才會套用。
- **Background**（背景）：點選卡片或將圖片拖放到卡片上；**Remove** 會恢復單純的玻璃背景，按 **Save** 套用。22H2 之前的版本沒有 Background 區段。
- **Title font**（標題字型）：可選用任何已安裝的字型，大小為 10 到 24 pt。
- **Windows**（視窗）：勾選 **Only this monitor's windows**，只列出窗格所在螢幕的視窗；未勾選時（預設），會列出所有螢幕的視窗。
- **Shortcuts**（快速鍵）：點選 **Switch windows** 或 **Stay open**，再按下按鍵組合；**Esc** 會保留原本的快速鍵。切換視窗的快速鍵使用 Alt、Ctrl 或 Win 搭配一個按鍵；加上 Shift 可往回切換。無法使用或已被使用的組合會遭拒，並顯示原因。**Defaults** 會恢復 Alt+Tab 和 Ctrl+Alt+Tab。

Velvet 的動態效果，以及兩種外觀和面板中的 GIF，都會配合 Windows 的**動畫效果**設定（設定 > 協助工具 > 視覺效果）。關閉時，所有動態效果都會停止，GIF 只顯示第一個影格。在小螢幕上，可用滾輪或右側捲軸捲動面板；按鈕會留在底部，以 Tab 移到的欄位也會自動捲入可見範圍。

**Save**（或 Enter）會寫入 `%APPDATA%\MeowTab\settings.ini` 並重新載入。**Cancel**（或 Esc）不會變更任何設定。**Reset to defaults** 會移除面板的設定，保留圖片與你自行加入的設定行（例如 `WM_PROCESS`），並關閉背景圖片。

### 自己的圖片

你的圖片會複製到 `%APPDATA%\MeowTab\images\`，存為 `custom_few.png`、`custom_some.png` 和 `custom_many.png`；不會覆寫內附的貓咪圖片。照片會調整成正確方向，大型圖片會縮小至 1024 px。GIF 會存為 `custom_<mood>.gif`，大於 512 px 時會縮小至 512 px；超過 100 個影格的 GIF 則不接受。背景圖片會存為 `pane.png`，調整方向並縮小至最多 2560 px，柔和地融入玻璃背景；GIF 只使用第一個影格。

手動設定：將 `<prefix>_few.png`、`<prefix>_some.png` 和 `<prefix>_many.png`（或 `.gif`）放進 `%APPDATA%\MeowTab\images\`，在 `settings.ini` 中設定 `IMG_PREFIX=<prefix>`，再從系統匣選擇 **Reload Script**。同名 GIF 會優先於 PNG 使用，最多播放前 100 個影格。

小提示：透明背景的正方形 PNG 效果最好；解析度不限，非正方形圖片也會保留原本的比例。圖片周圍的透明留白不影響探頭高度。找不到檔案時，該心情就不會顯示圖片。

## 設定參考

面板會寫入 `%APPDATA%\MeowTab\settings.ini`，覆蓋程式內建的預設值。標為 *ini* 的設定鍵可在 `[settings]` 下以 `NAME=value` 加入。無效的值會退回預設值，超出範圍的值會限制在有效範圍內，並由系統匣通知指出是哪項設定。較舊版本放在指令碼旁的設定檔已不再讀取：請將它移到 `%APPDATA%\MeowTab`，並將 `custom_*.png` 移到其中的 `images\` 資料夾。

<details><summary>settings.ini 設定鍵</summary>

| 設定 | 預設值 | 適用於 | 設定方式 | 用途 |
| --- | --- | --- | --- | --- |
| `FONT_NAME` | Noto Sans TC（否則 Segoe UI） | 兩者 | 面板 | 標題字型（經典版：清單字型）。 |
| `FONT_SIZE` | `10` / `16` | 主程式 / 經典版 | 面板 | 文字大小，單位為點（10-24）。 |
| `IMG_PREFIX` | `chill` | 兩者 | 面板 | 圖片為 `<prefix>_few.png`、`_some.png`、`_many.png`，也都能使用 `.gif`。面板使用 `custom`。 |
| `SOME_FROM` | `3` | 兩者 | 面板 | 開始算為「some」的最少視窗數量。 |
| `MANY_FROM` | `8` | 兩者 | 面板 | 開始算為「many」的最少視窗數量（2 ≤ `SOME_FROM` < `MANY_FROM` ≤ 30）。 |
| `PEEK_MIN` | `0.80` | 主程式 | 面板 | 只有 1 個視窗時，圖片露出窗格上方的比例。 |
| `PEEK_MAX` | `0.95` | 主程式 | 面板 | 視窗數量達 `MANY_FROM + 4` 以上時露出的比例（0.30-1.00，須大於 `PEEK_MIN`）。 |
| `SWITCH_KEYS` | `Alt+Tab` | 主程式 | 面板 | 切換器的快速鍵：按住 Alt、Ctrl 或 Win，搭配一個按鍵；加上 Shift 可往回切換。 |
| `STAY_KEYS` | `Ctrl+Alt+Tab` | 主程式 | 面板 | 開啟放開按鍵後仍保持開啟的切換器。 |
| `PANE_LOOK` | `velvet` | 主程式 | 面板 | 切換器的外觀：`velvet` 或 `windows11`。 |
| `MONITORS` | `all` | 兩者 | 面板 | 列出哪些螢幕的視窗：`all`，或 `current` 表示只列出窗格所在螢幕的視窗（不分大小寫；對應面板的 **Only this monitor's windows**）。 |
| `PANE_PICTURE` | 空白 | 主程式 | 面板 | 窗格的背景圖片：位於 `%APPDATA%\MeowTab\images` 的檔名（面板會設為 `pane.png`）。空白表示不使用圖片，只顯示玻璃。找不到檔案時會退回無圖片，並顯示通知。 |
| `IMG_SIZE` | `250` / `100` | 主程式 / 經典版 | ini | 圖片大小，單位為像素。GIF 的每個影格都會保留解碼結果，因此每種心情都使用長 GIF 時，預設大小 250 約占 75 MB，最大大小 600 約占 430 MB（三張各有 100 個影格的 GIF）。 |
| `WM_PROCESS` | 空白 | 兩者 | ini | 此處指定的程式結束時，也結束喵塔布，例如 `glazewm.exe`。 |
| `LIST_WIDTH` | `700` | 經典版 | ini | 清單寬度，單位為像素。 |
| `MAX_ROWS` | `15` | 經典版 | ini | 清單超過此列數時可捲動。 |
| `PREVIEW_W` | `800` | 經典版 | ini | 預覽寬度，單位為像素；`0` 表示關閉。 |
| `IMG_ROWS` | `12` | 經典版 | ini | 清單超過此視窗數量時，才會蓋住圖片。 |

</details>

## 檢查下載檔案

每個發行版都有 `SHA256SUMS.txt`；發行說明也列出 ZIP 與兩個執行檔的 SHA-256 雜湊值，以及 [VirusTotal](https://www.virustotal.com) 連結。將 `meowtab.zip` 和 `SHA256SUMS.txt` 放在同一個資料夾，再於該資料夾中用 PowerShell 執行以下指令（`True` 表示相符）：

```
(Get-FileHash .\meowtab.zip).Hash -eq (Select-String -Path .\SHA256SUMS.txt -Pattern ' meowtab\.zip$').Line.Split(' ')[0]
```

這些雜湊值來自帶有版本標籤的原始碼經 [GitHub Actions 建置](.github/workflows/build.yml)產生的檔案。相符表示下載的是當時建置並掃描的檔案；不相符表示下載檔案損壞或遭到修改，請不要執行。VirusTotal 使用啟發式掃描：報告沒有偵測到問題不代表保證安全，有些引擎也會對沒有問題的 AutoHotkey 執行檔發出警示。原始碼就在這裡，可自行閱讀。執行檔沒有程式碼簽章；如果 SmartScreen 顯示「Windows 已保護您的電腦」，請在確認雜湊值後，選擇 **其他資訊**，再選 **仍要執行**。

## 移除喵塔布

在系統匣選單中取消勾選 **Start at login**；如果曾勾選 **Desktop icon**，也請取消勾選（各自會移除其捷徑）。從系統匣結束程式，再刪除程式資料夾，或使用[快速開始](#快速開始)中的解除安裝指令。設定與圖片會保留在 `%APPDATA%\MeowTab`，供日後安裝使用；若要一併刪除：

```
Remove-Item "$env:APPDATA\MeowTab" -Recurse
```

## 使用須知

- **系統管理員視窗。** 當以系統管理員權限執行的視窗取得焦點時，Windows 會阻擋一般程式的快速鍵，因此會出現 Windows 內建的 Alt+Tab。以系統管理員身分執行喵塔布，即可在這些視窗中使用。
- **不連線。** 喵塔布不會連上網路；設定與圖片都留在你的電腦上，位於 `%APPDATA%\MeowTab`。
- **已知問題。** 預覽的下方角落是直角。勾選 **Only this monitor's windows**（`MONITORS=current`）時，在沒有視窗的螢幕上按 Alt+Tab 不會有作用。

**GlazeWM（選用）：** 將喵塔布加入其 `config.yaml` 的 `startup_commands`：

```yaml
general:
  startup_commands: ['shell-exec C:\path\to\meowtab\meowtab.ahk']
```

若要在 GlazeWM 結束時一併結束喵塔布，請將以下內容加入 `%APPDATA%\MeowTab\settings.ini`（面板儲存時會保留）：

```ini
[settings]
WM_PROCESS=glazewm.exe
```

## 更多

[開發藍圖](ROADMAP.md) · [問題回報](https://github.com/tingtmu/meowtab/issues) · [參與貢獻](CONTRIBUTING.md) · MIT 授權：[LICENSE](LICENSE)。

預設的貓咪圖片，以及用其中一張製作的圖示，都是 AI 生成的暫用圖片，採用相同的授權條款。
