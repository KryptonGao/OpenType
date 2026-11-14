(() => {
  const SUPPORTED_LANGS = ["zh-Hans", "zh-Hant", "en", "ja", "ko"];
  const STORAGE_KEY = "opentype.website.lang";

  const LANG_META = {
    "zh-Hans": {
      label: "简体中文",
      short: "简中",
      htmlLang: "zh-Hans",
      readmeUrl: "https://github.com/KryptonGao/OpenType/blob/main/README.zh-Hans.md"
    },
    "zh-Hant": {
      label: "繁體中文",
      short: "繁中",
      htmlLang: "zh-Hant",
      readmeUrl: "https://github.com/KryptonGao/OpenType/blob/main/README.zh-Hant.md"
    },
    en: {
      label: "English",
      short: "EN",
      htmlLang: "en",
      readmeUrl: "https://github.com/KryptonGao/OpenType/blob/main/README.md"
    },
    ja: {
      label: "日本語",
      short: "日本語",
      htmlLang: "ja",
      readmeUrl: "https://github.com/KryptonGao/OpenType/blob/main/README.ja.md"
    },
    ko: {
      label: "한국어",
      short: "한국어",
      htmlLang: "ko",
      readmeUrl: "https://github.com/KryptonGao/OpenType/blob/main/README.ko.md"
    }
  };

  const TRANSLATIONS = {
    "zh-Hans": {
      pageTitle: "OpenType — 面向 macOS 的全局 AI 语音输入工具",
      pageDescription: "在任意输入框里说话，文字经整理后直接落在当前光标处；支持听写、15 种语言语音翻译与「帮我说」联网润色。macOS 26.0+ · Apple Silicon。",
      navModes: "三种用法",
      navWorkflow: "工作流",
      navSurfaces: "应用界面",
      navScenarios: "实际示例",
      langSwitcherAria: "选择页面语言",
      langMenuAria: "语言列表",
      headerDownload: "下载 macOS 版",

      heroTitle: "用 OpenType 在任何地方说话成文",
      heroSub: "面向 macOS 的全局 AI 语音输入工具。在任意输入框里说话，文字经整理后直接落在当前光标处；支持听写、语音翻译与「帮我说」。",
      heroDownload: "下载 macOS 版",
      heroGithub: "查看 GitHub",
      trustLabel: "原生兼容主流语音识别与大模型协议",
      trustBailian: "阿里云百炼",
      windowTitle: "OpenType · 主界面 / 悬浮窗演示",
      heroImgAlt: "OpenType 桌面语音输入与悬浮窗实际效果截图",
      heroPlaceholderTitle: "主展示屏幕截图占位",
      heroPlaceholderDesc: "放置：在任意输入场景下唤起 OpenType Liquid Glass 悬浮窗进行语音输入时的真实桌面截图",

      modesTitle: "开始使用",
      modesSub: "三种语音会话模式共用一条流水线，按你的表达意图选择触发方式。",
      mode1Title: "听写",
      mode1Desc: "说完自动去除口头禅、补全标点符号，并直接插入原来的输入位置。支持「原始 / 标准 / 深度整理」三档处理等级。",
      mode1Shortcut: "默认 ⌃⌥ Space",
      mode1Hint: "短按开始，再短按一次结束（可在设置中自定义）",
      mode1Btn: "了解听写流程",

      mode2Title: "语音翻译",
      mode2Desc: "先理顺口语再翻译成目标语言，支持 15 种语言；录音过程中可在悬浮窗里临时切换语种与地区用语（台湾/港澳、巴西/葡萄牙）。",
      mode2Shortcut: "默认 ⌃⌥ T",
      mode2Hint: "短按开始，再按一次结束（支持自定义或清除）",
      mode2Btn: "查看支持语种",

      mode3Title: "帮我说",
      mode3Desc: "模型不只是纠错，而是将你的随口念头细化、补全为可直接发出的成品。不编造未提及的人名、数字或日期，可开启联网搜索。",
      mode3Shortcut: "长按约 0.45s",
      mode3Hint: "按住你的听写键或翻译键（翻译帮我说），松开结束",
      mode3Btn: "查看成稿示例",
      modesFootnote: "听写与翻译快捷键均可完全自定义，支持单键、组合键、左右独立修饰键（如右 ⌥）或 fn 键；Esc 保留为取消键，取消时不插入文字。",

      workflowTitle: "为顺滑的日常表达而打造",
      row1Title: "不抢焦点的非激活式悬浮窗",
      row1Desc: "悬浮窗采用非激活式 NSPanel，弹出与识别期间原应用的光标焦点始终保持不变。实时呈现音量波形以及「已确认文字 + 浅色未稳定部分」，并可按模式单独选择 Liquid Glass 或毛玻璃材质。",
      row1Pill2: "毛玻璃",
      row1Pill3: "不抢焦点",
      row1ImgAlt: "OpenType 非激活式悬浮窗实时波形与中间转写截图",
      row1PlaceholderTitle: "悬浮窗材质与实时波形截图占位",
      row1PlaceholderDesc: "放置：Liquid Glass 完整悬浮窗实机截图（显示音量波形、已确认与浅色未稳定文字）",

      row2Title: "ASR 与 LLM 完全解耦",
      row2Desc: "语音识别可选阿里云百炼实时流式（qwen3-asr-flash-realtime / qwen-audio-3.1-asr-flash-message）或 DeepSeek 整段上传；文本处理内置 OpenAI Responses、Chat Completions 与 Anthropic Messages 三种协议适配器，支持多套 Profile 随时切换。",
      row2Pill1: "阿里云百炼 WebSocket",
      row2Pill2: "DeepSeek ASR",
      row2Pill3: "多 Profile",
      row2ImgAlt: "OpenType 设置中的语音识别与 AI 处理配置界面",
      row2PlaceholderTitle: "「设置 → 语音识别 / AI 处理」截图占位",
      row2PlaceholderDesc: "放置：AI 处理多协议 Profile 配置页面（或语音识别设置页）截图",

      row3Title: "「帮我说」支持联网搜索",
      row3Desc: "在「设置 → 帮我说」中开启 DeepSeek 联网搜索后，可通过 0–100% 滑块调节搜索积极度。搜索与网页读取在服务端完成，悬浮窗实时展示“正在搜索 · 已搜到 N 条结果 · 已读取 M 个网页”。",
      row3Pill2: "积极度 0–100%",
      row3ImgAlt: "OpenType 帮我说联网搜索设置或搜索状态悬浮窗截图",
      row3PlaceholderTitle: "联网搜索进度与结果反馈截图占位",
      row3PlaceholderDesc: "放置：「帮我说」联网搜索进行中提示条或「设置 → 帮我说」页面截图",

      row4Title: "三级安全插入与本地隐私",
      row4Desc: "依次尝试 Accessibility 直写、自动备份恢复剪贴板的模拟粘贴与悬浮窗手动复制，绝不向密码框、安全输入模式或已切换的应用误写。不落盘原始音频，API Key 以 0600 权限存于 ~/.opentype/credentials.json。",
      row4Pill1: "失败不丢字",
      row4Pill2: "0600 本地凭证",
      row4ImgAlt: "OpenType 设置中的隐私与权限管理界面",
      row4PlaceholderTitle: "「设置 → 隐私与权限」截图占位",
      row4PlaceholderDesc: "放置：麦克风 / 辅助功能 / 输入监控授权状态与本地隐私面板截图",

      surfacesTitle: "原生打磨的每一处界面",
      surfacesSub: "从后台静默驻留到统计与历史检索，完全遵循 SwiftUI 与 AppKit 原生体验。",
      surfacesCta: "阅读完整使用说明 ↗",
      surface1ImgAlt: "OpenType 首页输入统计与 Token 用量看板",
      surface1PlaceholderDesc: "首页统计看板",
      surface1Title: "首页统计",
      surface1Desc: "直观记录输入次数、累计字数、录音时长与 Token 用量。",
      surface1Link: "SwiftUI 原生主窗口",

      surface2ImgAlt: "OpenType 本地历史记录检索界面",
      surface2PlaceholderDesc: "本地历史记录",
      surface2Title: "历史记录",
      surface2Desc: "识别与整理文本仅存本机，支持全文搜索、一键复制与随时清空。",

      surface3ImgAlt: "OpenType 菜单栏下拉控制面板",
      surface3PlaceholderDesc: "菜单栏下拉面板",
      surface3Title: "菜单栏控制",
      surface3Desc: "快速查看听写与翻译快捷键、暂停全局监听、检查三项系统权限状态。",

      surface4ImgAlt: "OpenType 设置通用中的五语本地化设置",
      surface4PlaceholderDesc: "五语本地化设置",
      surface4Title: "五语界面",
      surface4Desc: "支持简中、繁中、English、日本語、한국어，跟随系统或手动切换。",
      surface4Link: "设置 → 通用 → 界面语言",

      scenariosTitle: "从随口一句到得体成品",
      prevBtnAria: "向左滚动",
      nextBtnAria: "向右滚动",
      quote1Spoken: "口述：“跟老师说我明天发烧了想请一天假”",
      quote1Typed: "落字：“老师您好，我明天发烧了，想请一天假，给您添麻烦了，谢谢老师。”",
      quote1Title: "帮我说 · 长按听写快捷键（默认 ⌃⌥ Space）",
      quote1Meta: "自动理顺语气，不编造未提及信息",

      quote2Spoken: "口述：“帮我问下这个报错怎么解决”",
      quote2Typed: "落字：自动组织成包含当前现象、触发条件与期望结果的清晰技术提问。",
      quote2Title: "帮我说 · 深度细化",
      quote2Meta: "适合 IM、Issue 与论坛提问",

      quote3Spoken: "口述：“下周二之前我们会把新版发到 GitHub 上”",
      quote3Typed: "落字：“We will publish the new release on GitHub before next Tuesday.”",
      quote3Title: "语音翻译 · 翻译快捷键（默认 ⌃⌥ T）",
      quote3Meta: "支持 15 种目标语言及地区用语",

      quote4Body: "设为仅修饰键（如 fn 或右 ⌥）时，轻点松开即触发；按住期间若同时按下 ⌘C 或 ⌥ + 点击，自动取消触发，避免日常操作冲突。",
      quote4Title: "CGEventTap 状态机",
      quote4Meta: "极低误触的全局快捷键",

      closingTitle: "开始使用 OpenType",
      closingSub: "macOS 26.0+ · Apple Silicon (arm64) · 开源免费、自备 API Key",
      closingLatest: "下载最新 Release ↗",
      closingAll: "查看全部版本",
      gatekeeperTip: "首次打开如遇 Gatekeeper 拦截，可拖入「应用程序」后执行：",
      copyBtn: "复制",
      copiedBtn: "已复制",

      lightboxAria: "截图放大预览",
      lightboxCloseAria: "关闭预览"
    },

    "zh-Hant": {
      pageTitle: "OpenType — 適用於 macOS 的全域 AI 語音輸入工具",
      pageDescription: "在任何輸入框裡說話，文字經整理後直接落在目前游標處；支援聽寫、15 種語言的語音翻譯與「幫我說」網路搜尋潤飾。macOS 26.0+ · Apple Silicon。",
      navModes: "三種用法",
      navWorkflow: "工作流程",
      navSurfaces: "應用介面",
      navScenarios: "實際範例",
      langSwitcherAria: "選擇頁面語言",
      langMenuAria: "語言列表",
      headerDownload: "下載 macOS 版",

      heroTitle: "用 OpenType 在任何地方說話成文",
      heroSub: "適用於 macOS 的全域 AI 語音輸入工具。在任何輸入框裡說話，文字經整理後直接落在目前游標處；支援聽寫、語音翻譯與「幫我說」。",
      heroDownload: "下載 macOS 版",
      heroGithub: "查看 GitHub",
      trustLabel: "原生相容主流語音辨識與大型語言模型協定",
      trustBailian: "阿里雲百鍊",
      windowTitle: "OpenType · 主視窗 / 懸浮視窗示範",
      heroImgAlt: "OpenType 桌面語音輸入與懸浮視窗實際效果截圖",
      heroPlaceholderTitle: "主展示畫面截圖預留位置",
      heroPlaceholderDesc: "放置：在任何輸入情境下喚起 OpenType Liquid Glass 懸浮視窗進行語音輸入的真實桌面截圖",

      modesTitle: "開始使用",
      modesSub: "三種語音工作階段共用同一條處理流程，依你的表達意圖選擇觸發方式。",
      mode1Title: "聽寫",
      mode1Desc: "說完自動去除贅詞、補上標點符號，並直接插入原本的輸入位置。支援「原始 / 標準 / 深度整理」三檔處理等級。",
      mode1Shortcut: "預設 ⌃⌥ Space",
      mode1Hint: "短按開始，再短按一次結束（可在設定中自訂）",
      mode1Btn: "了解聽寫流程",

      mode2Title: "語音翻譯",
      mode2Desc: "先理順口語再翻譯成目標語言，支援 15 種語言；錄音過程中可在懸浮視窗裡暫時切換語種與地區用語（台灣/港澳、巴西/葡萄牙）。",
      mode2Shortcut: "預設 ⌃⌥ T",
      mode2Hint: "短按開始，再按一次結束（支援自訂或清除）",
      mode2Btn: "查看支援語種",

      mode3Title: "幫我說",
      mode3Desc: "模型不只是修正文字，還會將你的隨口念頭細化、補全為可直接發出的成品。不會編造未提及的人名、數字或日期，並可開啟網路搜尋。",
      mode3Shortcut: "長按約 0.45s",
      mode3Hint: "按住聽寫或翻譯快速鍵（翻譯幫我說），放開結束",
      mode3Btn: "查看成稿範例",
      modesFootnote: "聽寫與翻譯快速鍵皆可完全自訂，支援單一按鍵、組合鍵、左右獨立修飾鍵（如右 ⌥）或 fn 鍵；Esc 保留為取消鍵，取消時不插入文字。",

      workflowTitle: "為流暢的日常表達而打造",
      row1Title: "不搶焦點的非啟用式懸浮視窗",
      row1Desc: "懸浮視窗採用非啟用式 NSPanel，彈出與辨識期間原應用的游標焦點始終保持不變。即時呈現音量波形與「已確認文字 + 淡色未穩定部分」，並可依模式單獨選擇 Liquid Glass 或毛玻璃材質。",
      row1Pill2: "毛玻璃",
      row1Pill3: "不搶焦點",
      row1ImgAlt: "OpenType 非啟用式懸浮視窗即時波形與中間轉寫截圖",
      row1PlaceholderTitle: "懸浮視窗材質與即時波形截圖預留位置",
      row1PlaceholderDesc: "放置：Liquid Glass 完整懸浮視窗實機截圖（顯示音量波形、已確認與淡色未穩定文字）",

      row2Title: "ASR 與 LLM 完全解耦",
      row2Desc: "語音辨識可選阿里雲百鍊即時串流（qwen3-asr-flash-realtime / qwen-audio-3.1-asr-flash-message）或 DeepSeek 整段上傳；文字處理內建 OpenAI Responses、Chat Completions 與 Anthropic Messages 三種協定轉接器，支援多組設定檔隨時切換。",
      row2Pill1: "阿里雲百鍊 WebSocket",
      row2Pill2: "DeepSeek ASR",
      row2Pill3: "多組設定檔",
      row2ImgAlt: "OpenType 設定中的語音辨識與 AI 處理設定介面",
      row2PlaceholderTitle: "「設定 → 語音辨識 / AI 處理」截圖預留位置",
      row2PlaceholderDesc: "放置：AI 處理多協定設定檔頁面（或語音辨識設定頁）截圖",

      row3Title: "「幫我說」支援網路搜尋",
      row3Desc: "在「設定 → 幫我說」中開啟 DeepSeek 網路搜尋後，可透過 0–100% 滑桿調整搜尋積極度。搜尋與網頁讀取在伺服器端完成，懸浮視窗即時顯示「正在搜尋 · 已搜尋到 N 筆結果 · 已讀取 M 個網頁」。",
      row3Pill2: "積極度 0–100%",
      row3ImgAlt: "OpenType 幫我說網路搜尋設定或搜尋狀態懸浮視窗截圖",
      row3PlaceholderTitle: "網路搜尋進度與結果回饋截圖預留位置",
      row3PlaceholderDesc: "放置：「幫我說」網路搜尋進行中提示條或「設定 → 幫我說」頁面截圖",

      row4Title: "三級安全插入與本機隱私",
      row4Desc: "依序嘗試輔助使用直接寫入、自動備份並還原剪貼簿的模擬貼上，以及懸浮視窗手動複製，絕不向密碼欄位、安全輸入模式或已切換的 App 誤寫。不儲存原始音訊，API Key 以 0600 權限存於 ~/.opentype/credentials.json。",
      row4Pill1: "失敗不丟字",
      row4Pill2: "0600 本機憑證",
      row4ImgAlt: "OpenType 設定中的隱私與權限管理介面",
      row4PlaceholderTitle: "「設定 → 隱私與權限」截圖預留位置",
      row4PlaceholderDesc: "放置：麥克風 / 輔助使用 / 輸入監控授權狀態與本機隱私面板截圖",

      surfacesTitle: "原生打磨的每一處介面",
      surfacesSub: "從背景靜默駐留到統計與歷史搜尋，完全遵循 SwiftUI 與 AppKit 原生體驗。",
      surfacesCta: "閱讀完整使用說明 ↗",
      surface1ImgAlt: "OpenType 首頁輸入統計與 Token 用量看板",
      surface1PlaceholderDesc: "首頁統計看板",
      surface1Title: "首頁統計",
      surface1Desc: "直覺記錄輸入次數、累計字數、錄音時長與 Token 用量。",
      surface1Link: "SwiftUI 原生主視窗",

      surface2ImgAlt: "OpenType 本機歷史記錄搜尋介面",
      surface2PlaceholderDesc: "本機歷史記錄",
      surface2Title: "歷史記錄",
      surface2Desc: "辨識與整理文字僅存於本機，支援全文搜尋、一鍵複製與隨時清除。",

      surface3ImgAlt: "OpenType 選單列下拉控制面板",
      surface3PlaceholderDesc: "選單列下拉面板",
      surface3Title: "選單列控制",
      surface3Desc: "快速查看聽寫與翻譯快速鍵、暫停全域監聽、檢查三項系統權限狀態。",

      surface4ImgAlt: "OpenType 設定一般中的五語在地化設定",
      surface4PlaceholderDesc: "五語在地化設定",
      surface4Title: "五語介面",
      surface4Desc: "支援簡中、繁中、English、日本語、한국어，跟隨系統或手動切換。",
      surface4Link: "設定 → 一般 → 介面語言",

      scenariosTitle: "從隨口一句到得體成品",
      prevBtnAria: "向左捲動",
      nextBtnAria: "向右捲動",
      quote1Spoken: "口述：「跟老師說我明天發燒了想請一天假」",
      quote1Typed: "落字：「老師您好，我明天發燒了，想請一天假，給您添麻煩了，謝謝老師。」",
      quote1Title: "幫我說 · 長按聽寫快速鍵（預設 ⌃⌥ Space）",
      quote1Meta: "自動理順語氣，不編造未提及資訊",

      quote2Spoken: "口述：「幫我問一下這個錯誤訊息怎麼解決」",
      quote2Typed: "落字：自動整理成包含目前現象、觸發條件與預期結果的清晰技術提問。",
      quote2Title: "幫我說 · 深度細化",
      quote2Meta: "適合即時通訊、Issue 與論壇提問",

      quote3Spoken: "口述：「下週二之前我們會把新版發到 GitHub 上」",
      quote3Typed: "落字：“We will publish the new release on GitHub before next Tuesday.”",
      quote3Title: "語音翻譯 · 翻譯快速鍵（預設 ⌃⌥ T）",
      quote3Meta: "支援 15 種目標語言與地區用語",

      quote4Body: "設為僅修飾鍵（如 fn 或右 ⌥）時，輕點放開即觸發；按住期間若同時按下 ⌘C 或 ⌥ + 點擊，自動取消觸發，避免日常操作衝突。",
      quote4Title: "CGEventTap 狀態機",
      quote4Meta: "極低誤觸的全域快速鍵",

      closingTitle: "開始使用 OpenType",
      closingSub: "macOS 26.0+ · Apple Silicon (arm64) · 開源免費、自備 API Key",
      closingLatest: "下載最新 Release ↗",
      closingAll: "查看全部版本",
      gatekeeperTip: "首次開啟如遇 Gatekeeper 攔截，可拖入「應用程式」後執行：",
      copyBtn: "複製",
      copiedBtn: "已複製",

      lightboxAria: "截圖放大預覽",
      lightboxCloseAria: "關閉預覽"
    },

    en: {
      pageTitle: "OpenType — Global AI Voice Input for macOS",
      pageDescription: "Speak in any text field on macOS and cleaned-up text lands right at your cursor. Supports dictation, 15-language voice translation, and Say It for Me with web search. macOS 26.0+ · Apple Silicon.",
      navModes: "Modes",
      navWorkflow: "Workflow",
      navSurfaces: "Interface",
      navScenarios: "Examples",
      langSwitcherAria: "Choose language",
      langMenuAria: "Language list",
      headerDownload: "Download for macOS",

      heroTitle: "Speak anywhere, land clean text with OpenType",
      heroSub: "A global AI voice input tool for macOS. Speak into any text field and polished text lands directly at the cursor — with Dictation, Voice Translation, and Say It for Me.",
      heroDownload: "Download for macOS",
      heroGithub: "View on GitHub",
      trustLabel: "Native support for leading speech recognition & LLM protocols",
      trustBailian: "Alibaba Bailian",
      windowTitle: "OpenType · Main Window & Overlay Preview",
      heroImgAlt: "Screenshot of OpenType desktop voice input and Liquid Glass overlay",
      heroPlaceholderTitle: "Main Hero Screenshot Placeholder",
      heroPlaceholderDesc: "Drop in a real desktop screenshot showing the OpenType Liquid Glass overlay summoned over an active text field",

      modesTitle: "Three ways to use it",
      modesSub: "All three voice session modes share one reliable pipeline — trigger the one that fits your intent.",
      mode1Title: "Dictation",
      mode1Desc: "Removes filler words, restores punctuation, and inserts text right back at the cursor. Choose from Raw, Standard, or Deep cleanup.",
      mode1Shortcut: "Default ⌃⌥ Space",
      mode1Hint: "Tap to start, tap again to finish (fully customizable)",
      mode1Btn: "See dictation flow",

      mode2Title: "Voice Translation",
      mode2Desc: "Tidies spoken phrasing first, then translates into 15 target languages. Switch languages and regional wording (TW/HK, BR/PT) right inside the overlay.",
      mode2Shortcut: "Default ⌃⌥ T",
      mode2Hint: "Tap to start, tap again to finish (customizable or optional)",
      mode2Btn: "See supported modes",

      mode3Title: "Say It for Me",
      mode3Desc: "Goes beyond fixing typos: elaborates rough thoughts into ready-to-send messages without inventing names, numbers, or dates. Optional web search.",
      mode3Shortcut: "Hold ~0.45s",
      mode3Hint: "Hold your dictation or translation key (Translate & Say It for Me), release to finish",
      mode3Btn: "See real examples",
      modesFootnote: "Both dictation and translation shortcuts can be a single key, a combo, a lone left/right modifier (like right ⌥), or fn. Esc cancels anytime without inserting text.",

      workflowTitle: "Crafted for effortless everyday expression",
      row1Title: "Non-activating overlay that never steals focus",
      row1Desc: "Built as a non-activating NSPanel so cursor focus in your target app stays untouched. Displays a live waveform alongside confirmed text and a lighter interim tail, with per-mode Liquid Glass or Frosted glass styling.",
      row1Pill2: "Frosted glass",
      row1Pill3: "Focus-safe",
      row1ImgAlt: "Screenshot of OpenType non-activating overlay with live waveform and interim transcript",
      row1PlaceholderTitle: "Overlay Material & Live Waveform Placeholder",
      row1PlaceholderDesc: "Drop in a live screenshot of the full Liquid Glass overlay showing waveform, confirmed text, and interim tail",

      row2Title: "Decoupled ASR and LLM pipeline",
      row2Desc: "Pick Alibaba Cloud Bailian streaming (qwen3-asr-flash-realtime / qwen-audio-3.1-asr-flash-message) or DeepSeek whole-recording ASR. On the LLM side, built-in OpenAI Responses, Chat Completions, and Anthropic Messages adapters support multiple switchable profiles.",
      row2Pill1: "Bailian WebSocket",
      row2Pill2: "DeepSeek ASR",
      row2Pill3: "Multi-Profile",
      row2ImgAlt: "Screenshot of Speech Recognition and AI Processing settings in OpenType",
      row2PlaceholderTitle: "Settings → Speech Recognition / AI Processing Placeholder",
      row2PlaceholderDesc: "Drop in a screenshot of the multi-protocol AI Processing profile or Speech Recognition settings view",

      row3Title: "Say It for Me with live web search",
      row3Desc: "Enable DeepSeek web search in Settings → Say It for Me and tune search eagerness from 0–100%. Search and page reading run server-side while the overlay reports “Searching · Found N results · Read M web pages” in real time.",
      row3Pill2: "Eagerness 0–100%",
      row3ImgAlt: "Screenshot of Say It for Me web search settings or live search progress capsule",
      row3PlaceholderTitle: "Web Search Progress & Settings Placeholder",
      row3PlaceholderDesc: "Drop in a screenshot of the live web search progress capsule or Settings → Say It for Me",

      row4Title: "Three-tier safe insertion & local privacy",
      row4Desc: "Tries direct Accessibility writing first, then clipboard-backed simulated paste, then manual overlay copy — never writing into password fields, secure input mode, or switched apps. Audio is never saved to disk, and API keys live in ~/.opentype/credentials.json (0600).",
      row4Pill1: "Never loses words",
      row4Pill2: "0600 local keys",
      row4ImgAlt: "Screenshot of Privacy & Permissions settings in OpenType",
      row4PlaceholderTitle: "Settings → Privacy & Permissions Placeholder",
      row4PlaceholderDesc: "Drop in a screenshot showing Microphone, Accessibility, and Input Monitoring permission status",

      surfacesTitle: "Native macOS polish in every surface",
      surfacesSub: "From silent menu bar presence to typing stats and local search, crafted purely with SwiftUI and AppKit.",
      surfacesCta: "Read the full guide ↗",
      surface1ImgAlt: "OpenType Home view with typing statistics and token usage",
      surface1PlaceholderDesc: "Home stats dashboard",
      surface1Title: "Home Stats",
      surface1Desc: "Track sessions, character counts, recording duration, and token usage at a glance.",
      surface1Link: "Native SwiftUI Window",

      surface2ImgAlt: "OpenType local History search view",
      surface2PlaceholderDesc: "Local history",
      surface2Title: "History",
      surface2Desc: "Transcripts and polished outputs stay on your Mac — search, copy, or clear anytime.",

      surface3ImgAlt: "OpenType menu bar popover controls",
      surface3PlaceholderDesc: "Menu bar popover",
      surface3Title: "Menu Bar Control",
      surface3Desc: "Check shortcuts at a glance, pause global listening, and verify all three system permissions.",

      surface4ImgAlt: "Five-language localization picker in OpenType General settings",
      surface4PlaceholderDesc: "Five-language settings",
      surface4Title: "5-Language UI",
      surface4Desc: "Supports 简体中文, 繁體中文, English, 日本語, and 한국어 — follows macOS or switches manually.",
      surface4Link: "Settings → General → Language",

      scenariosTitle: "From rough thought to ready-to-send",
      prevBtnAria: "Scroll left",
      nextBtnAria: "Scroll right",
      quote1Spoken: "Spoken: “Tell my teacher I have a fever and need a day off tomorrow”",
      quote1Typed: "Typed: “Hello Professor, I came down with a fever and need to take tomorrow off. Sorry for the inconvenience, and thank you.”",
      quote1Title: "Say It for Me · Hold dictation key (default ⌃⌥ Space)",
      quote1Meta: "Refines tone naturally without inventing unmentioned details",

      quote2Spoken: "Spoken: “Ask how to fix this error”",
      quote2Typed: "Typed: Automatically structured into a clear technical question with symptoms, trigger conditions, and expected outcome.",
      quote2Title: "Say It for Me · Deep elaboration",
      quote2Meta: "Ideal for Slack, GitHub Issues, and forums",

      quote3Spoken: "Spoken: “下周二之前我们会把新版发到 GitHub 上”",
      quote3Typed: "Typed: “We will publish the new release on GitHub before next Tuesday.”",
      quote3Title: "Voice Translation · Shortcut (default ⌃⌥ T)",
      quote3Meta: "15 target languages with regional wording options",

      quote4Body: "When bound to a lone modifier key (like fn or right ⌥), tapping and releasing fires once; pressing ⌘C or ⌥-clicking while held automatically cancels it to prevent accidental triggers.",
      quote4Title: "CGEventTap State Machine",
      quote4Meta: "Near-zero false-trigger global hotkeys",

      closingTitle: "Start using OpenType",
      closingSub: "macOS 26.0+ · Apple Silicon (arm64) · Open source, bring your own API keys",
      closingLatest: "Download Latest Release ↗",
      closingAll: "Browse All Releases",
      gatekeeperTip: "If Gatekeeper blocks first launch, move to Applications and run:",
      copyBtn: "Copy",
      copiedBtn: "Copied",

      lightboxAria: "Expanded screenshot preview",
      lightboxCloseAria: "Close preview"
    },

    ja: {
      pageTitle: "OpenType — macOS 向けグローバル AI 音声入力ツール",
      pageDescription: "どの入力欄でも話すだけで、整えられたテキストがカーソル位置に入ります。音声入力、15 言語の音声翻訳、ウェブ検索対応の「代わりに話す」を搭載。macOS 26.0+ · Apple Silicon。",
      navModes: "3 つの使い方",
      navWorkflow: "処理の流れ",
      navSurfaces: "アプリ画面",
      navScenarios: "実例",
      langSwitcherAria: "表示言語を選択",
      langMenuAria: "言語一覧",
      headerDownload: "macOS 版をダウンロード",

      heroTitle: "OpenType で、どこでも話してそのまま文章に",
      heroSub: "macOS 向けのグローバル AI 音声入力ツール。どの入力欄でも話すだけで、整った文章がカーソル位置に直接入ります。音声入力・音声翻訳・「代わりに話す」に対応。",
      heroDownload: "macOS 版をダウンロード",
      heroGithub: "GitHub を見る",
      trustLabel: "主要な音声認識・LLM プロトコルにネイティブ対応",
      trustBailian: "Alibaba Cloud 百煉",
      windowTitle: "OpenType · メイン画面 / オーバーレイデモ",
      heroImgAlt: "OpenType のデスクトップ音声入力と Liquid Glass オーバーレイのスクリーンショット",
      heroPlaceholderTitle: "メイン展示スクリーンショット枠",
      heroPlaceholderDesc: "配置：任意の入力場面で OpenType Liquid Glass オーバーレイを呼び出して音声入力する実機スクリーンショット",

      modesTitle: "はじめ方",
      modesSub: "3 つの音声セッションは共通のパイプラインで動作し、伝えたい目的に合わせて呼び出せます。",
      mode1Title: "音声入力",
      mode1Desc: "話し終えると自動でフィラーを除去し句読点を補完して、元の入力位置に挿入します。「生のモード / 標準モード / 詳細整形」の 3 段階に対応。",
      mode1Shortcut: "初期設定 ⌃⌥ Space",
      mode1Hint: "短く押して開始、もう一度押して終了（設定でカスタマイズ可能）",
      mode1Btn: "音声入力の流れを見る",

      mode2Title: "音声翻訳",
      mode2Desc: "話し言葉を先に整えてから 15 言語へ翻訳します。録音中でもオーバーレイ上で言語や地域表現（台湾/香港・マカオ、ブラジル/ポルトガル）を切り替え可能。",
      mode2Shortcut: "初期設定 ⌃⌥ T",
      mode2Hint: "短く押して開始、もう一度押して終了（変更や解除も可能）",
      mode2Btn: "対応言語・仕様を見る",

      mode3Title: "代わりに話す",
      mode3Desc: "単なる誤字修正にとどまらず、思いついた一言をそのまま送れる丁寧な文章へ具体化・補完します。話していない人名や数値は捏造せず、ウェブ検索も利用可能。",
      mode3Shortcut: "長押し 約 0.45 秒",
      mode3Hint: "音声入力キーまたは翻訳キー（翻訳して代わりに話す）を長押しし、離して終了",
      mode3Btn: "仕上がり例を見る",
      modesFootnote: "音声入力・翻訳のショートカットは単一キー、組み合わせ、左右を区別した修飾キー単体（右 ⌥ など）、fn に対応。Esc でキャンセルし、キャンセル時は文字を挿入しません。",

      workflowTitle: "毎日の発信を、なめらかに",
      row1Title: "フォーカスを奪わない非アクティブ型オーバーレイ",
      row1Desc: "非アクティブ型の NSPanel を採用し、表示中も認識中も元のアプリのカーソルフォーカスを維持。音量波形と「確定済みテキスト + 薄色の未確定部分」をリアルタイム表示し、モード別に Liquid Glass とすりガラスを選択できます。",
      row1Pill2: "すりガラス",
      row1Pill3: "フォーカス維持",
      row1ImgAlt: "OpenType 非アクティブ型オーバーレイのリアルタイム波形と途中認識スクリーンショット",
      row1PlaceholderTitle: "オーバーレイ質感とリアルタイム波形スクリーンショット枠",
      row1PlaceholderDesc: "配置：Liquid Glass オーバーレイの実機スクリーンショット（音量波形・確定済みと未確定テキストを表示）",

      row2Title: "ASR と LLM を完全に分離",
      row2Desc: "音声認識は Alibaba Cloud Bailian リアルタイムストリーミング（qwen3-asr-flash-realtime / qwen-audio-3.1-asr-flash-message）または DeepSeek 全体アップロードを選択可能。LLM は OpenAI Responses、Chat Completions、Anthropic Messages に対応し、複数プロファイルを切り替えられます。",
      row2Pill1: "百煉 WebSocket",
      row2Pill2: "DeepSeek ASR",
      row2Pill3: "複数プロファイル",
      row2ImgAlt: "OpenType 設定の音声認識・AI 処理構成画面",
      row2PlaceholderTitle: "「設定 → 音声認識 / AI 処理」スクリーンショット枠",
      row2PlaceholderDesc: "配置：AI 処理のマルチプロトコルプロファイル設定（または音声認識設定）画面のスクリーンショット",

      row3Title: "「代わりに話す」はウェブ検索に対応",
      row3Desc: "「設定 → 代わりに話す」で DeepSeek ウェブ検索を有効にすると、0–100% のスライダーで検索の積極度を調整できます。検索とページ読み取りはサーバー側で完結し、オーバーレイに「検索中 · N 件の結果を取得 · M 件のページを読み取り」をリアルタイム表示します。",
      row3Pill2: "積極度 0–100%",
      row3ImgAlt: "OpenType 代わりに話すのウェブ検索設定または検索進捗オーバーレイのスクリーンショット",
      row3PlaceholderTitle: "ウェブ検索進捗・設定スクリーンショット枠",
      row3PlaceholderDesc: "配置：「代わりに話す」ウェブ検索中の進行表示または「設定 → 代わりに話す」画面のスクリーンショット",

      row4Title: "3 段階の安全挿入とローカルプライバシー",
      row4Desc: "アクセシビリティ直接書き込み → クリップボード自動バックアップ復元付きの擬似貼り付け → オーバーレイでの手動コピーの順に実行。パスワード欄やセキュア入力モード、切り替えた別のアプリには誤挿入しません。音声は保存せず、API キーは 0600 権限で ~/.opentype/credentials.json に保存されます。",
      row4Pill1: "失敗しても文字を失わない",
      row4Pill2: "0600 ローカル認証情報",
      row4ImgAlt: "OpenType 設定のプライバシーと権限管理画面",
      row4PlaceholderTitle: "「設定 → プライバシーと権限」スクリーンショット枠",
      row4PlaceholderDesc: "配置：マイク / アクセシビリティ / 入力監視の許可状態とローカルプライバシー画面のスクリーンショット",

      surfacesTitle: "細部までネイティブに磨き上げた UI",
      surfacesSub: "バックグラウンド常駐から入力統計、ローカル履歴検索まで、SwiftUI と AppKit の純粋な体験を追求。",
      surfacesCta: "完全ガイドを読む ↗",
      surface1ImgAlt: "OpenType ホーム画面の入力統計とトークン使用量ボード",
      surface1PlaceholderDesc: "ホーム統計ダッシュボード",
      surface1Title: "ホーム統計",
      surface1Desc: "入力回数、累計文字数、録音時間、トークン使用量を直感的に確認。",
      surface1Link: "SwiftUI ネイティブウィンドウ",

      surface2ImgAlt: "OpenType ローカル履歴検索画面",
      surface2PlaceholderDesc: "ローカル履歴",
      surface2Title: "履歴",
      surface2Desc: "認識・整形されたテキストはこの Mac のみに保存。全文検索、ワンクリックコピー、消去に対応。",

      surface3ImgAlt: "OpenType メニューバーのドロップダウン操作パネル",
      surface3PlaceholderDesc: "メニューバーパネル",
      surface3Title: "メニューバー操作",
      surface3Desc: "音声入力・翻訳ショートカットの確認、グローバル監視の一時停止、3 つの権限状態を確認。",

      surface4ImgAlt: "OpenType 一般設定の 5 言語ローカライズ切り替え",
      surface4PlaceholderDesc: "5 言語設定",
      surface4Title: "5 言語 UI",
      surface4Desc: "简体中文、繁體中文、English、日本語、한국어 に対応。システム連動または手動切り替えが可能。",
      surface4Link: "設定 → 一般 → 表示言語",

      scenariosTitle: "思いつきの一言を、そのまま送れる文章へ",
      prevBtnAria: "左へスクロール",
      nextBtnAria: "右へスクロール",
      quote1Spoken: "発話：「先生に、明日熱が出たので一日休みたいと伝えて」",
      quote1Typed: "入力：「先生、お疲れ様です。明日発熱のため一日お休みをいただきたく存じます。ご迷惑をおかけして申し訳ございません。」",
      quote1Title: "代わりに話す · 音声入力キー長押し（初期設定 ⌃⌥ Space）",
      quote1Meta: "語調を自然に整え、言っていない情報は作り出しません",

      quote2Spoken: "発話：「このエラーの解決方法を聞いて」",
      quote2Typed: "入力：現在の現象、発生条件、期待する結果を整理した明確な技術質問文に自動でまとめます。",
      quote2Title: "代わりに話す · 詳細仕上げ",
      quote2Meta: "チャット、Issue、フォーラムでの質問に最適",

      quote3Spoken: "発話：「来週の火曜日までに新バージョンを GitHub で公開します」",
      quote3Typed: "入力：“We will publish the new release on GitHub before next Tuesday.”",
      quote3Title: "音声翻訳 · 翻訳ショートカット（初期設定 ⌃⌥ T）",
      quote3Meta: "15 の目標言語と地域表現に対応",

      quote4Body: "修飾キー単体（fn や右 ⌥ など）に設定した場合、軽くタップして離すと作動。押している間に ⌘C や ⌥ + クリックを行うと自動キャンセルされ、普段の操作と干渉しません。",
      quote4Title: "CGEventTap ステートマシン",
      quote4Meta: "誤作動を極限まで抑えたグローバルショートカット",

      closingTitle: "OpenType を使い始める",
      closingSub: "macOS 26.0+ · Apple Silicon (arm64) · オープンソース無料・API キーはご自身で用意",
      closingLatest: "最新 Release をダウンロード ↗",
      closingAll: "すべてのバージョンを見る",
      gatekeeperTip: "初回起動時に Gatekeeper でブロックされた場合、「アプリケーション」へ移動後に実行：",
      copyBtn: "コピー",
      copiedBtn: "コピー済み",

      lightboxAria: "スクリーンショット拡大プレビュー",
      lightboxCloseAria: "プレビューを閉じる"
    },

    ko: {
      pageTitle: "OpenType — macOS용 전역 AI 음성 입력 도구",
      pageDescription: "어떤 입력창에서든 말하면 다듬어진 텍스트가 현재 커서 위치에 바로 입력됩니다. 받아쓰기, 15개 언어 음성 번역, 웹 검색 지원 '대신 말하기'를 제공합니다. macOS 26.0+ · Apple Silicon.",
      navModes: "세 가지 사용법",
      navWorkflow: "작동 흐름",
      navSurfaces: "앱 화면",
      navScenarios: "실제 예시",
      langSwitcherAria: "페이지 언어 선택",
      langMenuAria: "언어 목록",
      headerDownload: "macOS용 다운로드",

      heroTitle: "OpenType으로 어디서나 말로 글쓰기",
      heroSub: "macOS용 전역 AI 음성 입력 도구. 어떤 입력창에서든 말하면 다듬어진 텍스트가 커서 위치에 바로 입력됩니다. 받아쓰기, 음성 번역, '대신 말하기'를 지원합니다.",
      heroDownload: "macOS용 다운로드",
      heroGithub: "GitHub 보기",
      trustLabel: "주요 음성 인식 및 LLM 프로토콜 기본 호환",
      trustBailian: "알리바바 클라우드 Bailian",
      windowTitle: "OpenType · 메인 화면 / 오버레이 데모",
      heroImgAlt: "OpenType 데스크톱 음성 입력 및 Liquid Glass 오버레이 스크린샷",
      heroPlaceholderTitle: "메인 스크린샷 자리 표시자",
      heroPlaceholderDesc: "배치: 실제 입력 상황에서 OpenType Liquid Glass 오버레이를 호출해 음성 입력하는 데스크톱 스크린샷",

      modesTitle: "시작하기",
      modesSub: "세 가지 음성 세션 모드가 하나의 파이프라인을 공유합니다. 표현 목적에 맞게 트리거를 선택하세요.",
      mode1Title: "받아쓰기",
      mode1Desc: "말을 마치면 군말을 없애고 문장부호를 채워 원래 입력 위치에 바로 삽입합니다. '원본 / 표준 / 심층 정리' 3단계 처리를 지원합니다.",
      mode1Shortcut: "기본값 ⌃⌥ Space",
      mode1Hint: "짧게 눌러 시작, 다시 짧게 눌러 종료(설정에서 변경 가능)",
      mode1Btn: "받아쓰기 흐름 보기",

      mode2Title: "음성 번역",
      mode2Desc: "구어를 먼저 매끄럽게 정리한 뒤 15개 대상 언어로 번역합니다. 녹음 중에도 오버레이에서 언어와 지역 표현(대만/홍콩·마카오, 브라질/포르투갈)을 전환할 수 있습니다.",
      mode2Shortcut: "기본값 ⌃⌥ T",
      mode2Hint: "짧게 눌러 시작, 다시 눌러 종료(사용자 지정 또는 해제 가능)",
      mode2Btn: "지원 언어 보기",

      mode3Title: "대신 말하기",
      mode3Desc: "단순 교정을 넘어 스치듯 말한 생각을 바로 보낼 수 있는 완성된 문장으로 구체화·보완합니다. 말하지 않은 이름·숫자·날짜는 지어내지 않으며 웹 검색도 지원합니다.",
      mode3Shortcut: "약 0.45초 길게 누름",
      mode3Hint: "받아쓰기 또는 번역 단축키(번역해서 대신 말하기)를 누른 채 말하고 손을 떼면 종료",
      mode3Btn: "완성 예시 보기",
      modesFootnote: "받아쓰기와 번역 단축키는 단일 키, 조합 키, 좌우 구분 보조 키 단독(예: 오른쪽 ⌥), fn 키로 자유롭게 설정할 수 있습니다. Esc는 취소 전용이며 텍스트를 삽입하지 않습니다.",

      workflowTitle: "매끄러운 일상 표현을 위한 설계",
      row1Title: "포커스를 빼앗지 않는 비활성 오버레이",
      row1Desc: "비활성형 NSPanel로 구현되어 팝업과 인식 중에도 원래 앱의 커서 포커스가 그대로 유지됩니다. 실시간 음량 파형과 '확정된 텍스트 + 흐린 미확정 부분'을 표시하며, 모드별로 Liquid Glass 또는 프로스트 글라스 재질을 선택할 수 있습니다.",
      row1Pill2: "프로스트 글라스",
      row1Pill3: "포커스 유지",
      row1ImgAlt: "OpenType 비활성 오버레이 실시간 파형 및 중간 전사 스크린샷",
      row1PlaceholderTitle: "오버레이 재질 및 실시간 파형 스크린샷 자리",
      row1PlaceholderDesc: "배치: 음량 파형, 확정 및 흐린 미확정 텍스트가 표시된 Liquid Glass 전체 오버레이 실기 스크린샷",

      row2Title: "ASR과 LLM의 완전한 분리",
      row2Desc: "음성 인식은 알리바바 클라우드 Bailian 실시간 스트리밍(qwen3-asr-flash-realtime / qwen-audio-3.1-asr-flash-message) 또는 DeepSeek 전체 녹음 업로드를 지원합니다. LLM은 OpenAI Responses, Chat Completions, Anthropic Messages 어댑터를 내장해 여러 프로필을 전환할 수 있습니다.",
      row2Pill1: "Bailian WebSocket",
      row2Pill2: "DeepSeek ASR",
      row2Pill3: "다중 프로필",
      row2ImgAlt: "OpenType 설정의 음성 인식 및 AI 처리 구성 화면",
      row2PlaceholderTitle: "'설정 → 음성 인식 / AI 처리' 스크린샷 자리",
      row2PlaceholderDesc: "배치: AI 처리 다중 프로토콜 프로필 설정(또는 음성 인식 설정) 화면 스크린샷",

      row3Title: "'대신 말하기' 웹 검색 지원",
      row3Desc: "'설정 → 대신 말하기'에서 DeepSeek 웹 검색을 켜면 0–100% 슬라이더로 검색 적극도를 조절할 수 있습니다. 검색과 웹페이지 읽기는 서버에서 처리되며, 오버레이에 '검색 중 · 검색 결과 N개 확인 · 웹페이지 M개 읽음'이 실시간으로 표시됩니다.",
      row3Pill2: "적극도 0–100%",
      row3ImgAlt: "OpenType 대신 말하기 웹 검색 설정 또는 검색 상태 오버레이 스크린샷",
      row3PlaceholderTitle: "웹 검색 진행률 및 결과 피드백 스크린샷 자리",
      row3PlaceholderDesc: "배치: '대신 말하기' 웹 검색 진행 바 또는 '설정 → 대신 말하기' 페이지 스크린샷",

      row4Title: "3단계 안전 삽입 및 로컬 개인정보 보호",
      row4Desc: "손쉬운 사용 직접 쓰기 → 클립보드 자동 백업·복원 붙여넣기 → 오버레이 직접 복사를 순차 시도하며, 비밀번호 입력란이나 보안 입력 모드, 전환된 앱에는 절대 오작동하지 않습니다. 오디오는 저장하지 않으며 API Key는 0600 권한으로 ~/.opentype/credentials.json에 보관됩니다.",
      row4Pill1: "실패해도 글 유지",
      row4Pill2: "0600 로컬 자격 증명",
      row4ImgAlt: "OpenType 설정의 개인정보 보호 및 권한 관리 화면",
      row4PlaceholderTitle: "'설정 → 개인정보 보호 및 권한' 스크린샷 자리",
      row4PlaceholderDesc: "배치: 마이크 / 손쉬운 사용 / 입력 모니터링 권한 상태 및 로컬 개인정보 보호 패널 스크린샷",

      surfacesTitle: "네이티브로 다듬은 모든 화면",
      surfacesSub: "백그라운드 상주부터 통계와 로컬 기록 검색까지, SwiftUI와 AppKit 네이티브 경험을 온전히 따릅니다.",
      surfacesCta: "전체 사용 설명서 보기 ↗",
      surface1ImgAlt: "OpenType 홈 입력 통계 및 토큰 사용량 대시보드",
      surface1PlaceholderDesc: "홈 통계 대시보드",
      surface1Title: "홈 통계",
      surface1Desc: "입력 횟수, 누적 글자 수, 녹음 시간, 토큰 사용량을 한눈에 확인합니다.",
      surface1Link: "SwiftUI 네이티브 메인 창",

      surface2ImgAlt: "OpenType 로컬 기록 검색 화면",
      surface2PlaceholderDesc: "로컬 기록",
      surface2Title: "기록",
      surface2Desc: "인식 및 정리된 텍스트는 이 Mac에만 저장되며, 전체 검색·원클릭 복사·언제든 삭제가 가능합니다.",

      surface3ImgAlt: "OpenType 메뉴 막대 드롭다운 제어 패널",
      surface3PlaceholderDesc: "메뉴 막대 패널",
      surface3Title: "메뉴 막대 제어",
      surface3Desc: "받아쓰기·번역 단축키 확인, 전역 감지 일시 중지, 세 가지 시스템 권한 상태를 빠르게 점검합니다.",

      surface4ImgAlt: "OpenType 일반 설정의 5개 언어 현지화 선택 화면",
      surface4PlaceholderDesc: "5개 언어 설정",
      surface4Title: "5개 언어 UI",
      surface4Desc: "简体中文, 繁體中文, English, 日本語, 한국어를 지원하며 시스템 언어 연동 또는 수동 전환이 가능합니다.",
      surface4Link: "설정 → 일반 → 인터페이스 언어",

      scenariosTitle: "스치듯 한 말에서 바로 쓰는 문장으로",
      prevBtnAria: "왼쪽으로 스크롤",
      nextBtnAria: "오른쪽으로 스크롤",
      quote1Spoken: "발화: “선생님께 내일 열이 나서 하루 쉬고 싶다고 전해줘”",
      quote1Typed: "입력: “선생님, 안녕하세요. 내일 열이 나서 하루 결석하고자 합니다. 불편을 드려 죄송하며, 양해 부탁드립니다.”",
      quote1Title: "대신 말하기 · 받아쓰기 단축키 길게 누름(기본값 ⌃⌥ Space)",
      quote1Meta: "어조를 자연스럽게 다듬고 말하지 않은 정보는 지어내지 않음",

      quote2Spoken: "발화: “이 오류 어떻게 해결하는지 물어봐 줘”",
      quote2Typed: "입력: 현재 현상, 발생 조건, 기대 결과를 갖춘 명확한 기술 질문으로 자동 구성됩니다.",
      quote2Title: "대신 말하기 · 심층 구체화",
      quote2Meta: "메신저, GitHub Issue, 포럼 질문에 적합",

      quote3Spoken: "발화: “다음 주 화요일 전까지 새 버전을 GitHub에 올릴 예정입니다”",
      quote3Typed: "입력: “We will publish the new release on GitHub before next Tuesday.”",
      quote3Title: "음성 번역 · 번역 단축키(기본값 ⌃⌥ T)",
      quote3Meta: "15개 대상 언어 및 지역별 표현 지원",

      quote4Body: "보조 키 단독(fn 또는 오른쪽 ⌥ 등)으로 설정한 경우 가볍게 눌렀다 뗄 때 작동하며, 누른 채로 ⌘C나 ⌥ + 클릭을 하면 자동 취소되어 일상 조작과 충돌하지 않습니다.",
      quote4Title: "CGEventTap 상태 머신",
      quote4Meta: "오작동을 극도로 줄인 전역 단축키",

      closingTitle: "OpenType 시작하기",
      closingSub: "macOS 26.0+ · Apple Silicon (arm64) · 오픈 소스 무료 · API Key 직접 설정",
      closingLatest: "최신 Release 다운로드 ↗",
      closingAll: "모든 버전 보기",
      gatekeeperTip: "처음 열 때 Gatekeeper가 차단하면 '응용 프로그램'으로 옮긴 뒤 실행하세요:",
      copyBtn: "복사",
      copiedBtn: "복사됨",

      lightboxAria: "스크린샷 확대 미리보기",
      lightboxCloseAria: "미리보기 닫기"
    }
  };

  function normalizeLang(raw) {
    if (!raw || typeof raw !== "string") return null;
    const cleaned = raw.trim().toLowerCase().replace(/_/g, "-");
    if (cleaned === "zh-hans" || cleaned === "zh-cn" || cleaned === "zh-sg") return "zh-Hans";
    if (
      cleaned === "zh-hant" ||
      cleaned === "zh-tw" ||
      cleaned === "zh-hk" ||
      cleaned === "zh-mo" ||
      cleaned.startsWith("zh-hant-")
    ) {
      return "zh-Hant";
    }
    if (cleaned === "zh" || cleaned.startsWith("zh-hans-")) return "zh-Hans";
    if (cleaned === "en" || cleaned.startsWith("en-")) return "en";
    if (cleaned === "ja" || cleaned.startsWith("ja-")) return "ja";
    if (cleaned === "ko" || cleaned.startsWith("ko-")) return "ko";
    return null;
  }

  function detectInitialLang() {
    try {
      const params = new URLSearchParams(window.location.search);
      const fromQuery = normalizeLang(params.get("lang"));
      if (fromQuery) return fromQuery;
    } catch {
      // Ignore URL parsing errors
    }

    try {
      const fromStorage = normalizeLang(localStorage.getItem(STORAGE_KEY));
      if (fromStorage) return fromStorage;
    } catch {
      // Ignore storage access errors
    }

    const candidates = Array.isArray(navigator.languages) && navigator.languages.length
      ? navigator.languages
      : [navigator.language];

    for (const item of candidates) {
      const matched = normalizeLang(item);
      if (matched) return matched;
    }

    return "en";
  }

  let currentLang = detectInitialLang();

  function applyLanguage(lang, { persist = false, updateUrl = false } = {}) {
    const resolved = SUPPORTED_LANGS.includes(lang) ? lang : "en";
    currentLang = resolved;
    const dict = TRANSLATIONS[resolved];
    const meta = LANG_META[resolved];

    document.documentElement.lang = meta.htmlLang;
    document.title = dict.pageTitle;

    const metaDesc = document.querySelector('meta[name="description"]');
    if (metaDesc) {
      metaDesc.setAttribute("content", dict.pageDescription);
    }

    document.querySelectorAll("[data-i18n]").forEach((el) => {
      const key = el.getAttribute("data-i18n");
      if (key && Object.prototype.hasOwnProperty.call(dict, key)) {
        el.textContent = dict[key];
      }
    });

    document.querySelectorAll("[data-i18n-alt]").forEach((el) => {
      const key = el.getAttribute("data-i18n-alt");
      if (key && Object.prototype.hasOwnProperty.call(dict, key)) {
        el.setAttribute("alt", dict[key]);
      }
    });

    document.querySelectorAll("[data-i18n-aria]").forEach((el) => {
      const key = el.getAttribute("data-i18n-aria");
      if (key && Object.prototype.hasOwnProperty.call(dict, key)) {
        el.setAttribute("aria-label", dict[key]);
      }
    });

    const readmeLink = document.getElementById("readmeLink");
    if (readmeLink) {
      readmeLink.setAttribute("href", meta.readmeUrl);
    }

    const langLabel = document.getElementById("langCurrentLabel");
    if (langLabel) {
      langLabel.textContent = meta.label;
    }

    const langShort = document.getElementById("langCurrentShort");
    if (langShort) {
      langShort.textContent = meta.short;
    }

    const footerLangLabel = document.getElementById("footerLangCurrentLabel");
    if (footerLangLabel) {
      footerLangLabel.textContent = meta.label;
    }

    document.querySelectorAll("[data-lang-option]").forEach((btn) => {
      const isSelected = btn.getAttribute("data-lang-option") === resolved;
      btn.classList.toggle("is-active", isSelected);
      btn.setAttribute("aria-checked", isSelected ? "true" : "false");
    });

    if (persist) {
      try {
        localStorage.setItem(STORAGE_KEY, resolved);
      } catch {
        // Ignore storage errors
      }
    }

    if (updateUrl) {
      try {
        const url = new URL(window.location.href);
        url.searchParams.set("lang", resolved);
        window.history.replaceState(null, "", url.toString());
      } catch {
        // Ignore history errors on restricted schemes
      }
    }
  }

  window.OpenTypeI18n = {
    getCurrentLang: () => currentLang,
    getString: (key) => {
      const dict = TRANSLATIONS[currentLang] || TRANSLATIONS.en;
      return dict[key] || "";
    },
    setLanguage: (lang) => applyLanguage(lang, { persist: true, updateUrl: true })
  };

  applyLanguage(currentLang, { persist: false, updateUrl: false });
})();
