import SwiftUI

/// The Writing Tools panel (design: Design/mockups/writing-tools.html).
struct WritingToolsView: View {
    static let width: CGFloat = 392
    /// Transparent border around the card, for its shadow.
    static let margin: CGFloat = 44
    private static let maxBodyHeight: CGFloat = 560

    @Bindable var controller: WritingToolsController
    /// Reports the size the content wants; the panel is resized from it asynchronously (see `OverlayView`).
    var onContentSizeChange: (CGSize) -> Void = { _ in }

    @State private var bodyHeight: CGFloat = 0
    @FocusState private var focus: Field?

    enum Field: Hashable { case instruction, composePrompt, refine }
    private struct FocusKey: Hashable { var screen: WritingToolsController.Screen; var openCount: Int }

    private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: 26, style: .continuous) }

    var body: some View {
        card
            .padding(Self.margin)
            .focusEffectDisabled()
            .fixedSize(horizontal: false, vertical: true)
            .onGeometryChange(for: CGSize.self) { $0.size } action: { onContentSizeChange($0) }
            .background { shortcuts }
            .task(id: FocusKey(screen: controller.screen, openCount: controller.openCount)) {
                try? await Task.sleep(for: .milliseconds(60)) // the panel has to be key first
                switch controller.screen {
                case .menu: focus = .instruction
                case .compose: focus = .composePrompt
                case .result: focus = .refine
                default: focus = nil
                }
            }
    }

    private var card: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                screenContent
                    .padding(.horizontal, 16)
                    .padding(.top, 4)
                    .padding(.bottom, 14)
                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { bodyHeight = $0 }
            }
            .scrollBounceBehavior(.basedOnSize)
            .frame(height: min(max(bodyHeight, 1), Self.maxBodyHeight))
        }
        .frame(width: Self.width)
        .clipShape(shape) // nothing may poke out of the rounded corners
        // Empty parts of the card drag the window (controls on top still get their clicks).
        .background { Color.clear.contentShape(Rectangle()).gesture(WindowDragGesture()) }
        .modifier(PanelBackground(material: controller.settingsStore.writingToolsMaterial, shape: shape))
        .background { CardShadow(shape: shape, radius: 16, y: 6, opacity: 0.16) }
    }

    /// ⌘↩ replaces / inserts from anywhere on the result page (even while the refine field has the keyboard).
    private var shortcuts: some View {
        Button("") { Task { await controller.apply() } }
            .keyboardShortcut(.return, modifiers: .command)
            .disabled(!controller.canApply)
            .opacity(0)
            .accessibilityHidden(true)
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 10) {
            if controller.showsBackButton {
                RoundIconButton(systemName: "chevron.left", help: "返回") { controller.back() }
            }
            Text(controller.resultTitle)
                .font(.system(size: controller.showsBackButton ? 16 : 20, weight: .bold))
                .lineLimit(1)
            Spacer(minLength: 0)
            RoundIconButton(systemName: "xmark", help: "关闭") { controller.close() }
        }
        .padding(.leading, controller.showsBackButton ? 14 : 20)
        .padding(.trailing, 16)
        .padding(.top, 16)
        .padding(.bottom, 8)
    }

    @ViewBuilder private var screenContent: some View {
        switch controller.screen {
        case .menu: menu
        case .compose: composeScreen
        case .loading: loading
        case .result: resultScreen
        case .error: errorScreen
        }
    }

    // MARK: Menu (text selected)

    private var menu: some View {
        VStack(spacing: 12) {
            commandField
            Divider()
            HStack(spacing: 10) {
                ToolTile(tool: .proofread, systemName: "text.badge.checkmark", height: 88, action: controller.run)
                ToolTile(tool: .rewrite, systemName: "pencil.line", height: 88, action: controller.run)
            }
            HStack(spacing: 10) {
                ToolTile(tool: .friendly, systemName: "face.smiling", height: 68, action: controller.run)
                ToolTile(tool: .professional, systemName: "briefcase", height: 68, action: controller.run)
                ToolTile(tool: .concise, systemName: "arrow.down.right.and.arrow.up.left", height: 68, action: controller.run)
            }
            HStack(alignment: .top, spacing: 8) {
                FormatCard(tool: .summarize, action: controller.run)
                FormatCard(tool: .keyPoints, action: controller.run)
                Rectangle().fill(.separator).frame(width: 1, height: 72).padding(.top, 6)
                FormatCard(tool: .list, action: controller.run)
                FormatCard(tool: .table, action: controller.run)
            }
            Divider()
            VStack(spacing: 8) {
                Button { controller.openCompose() } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "square.and.pencil").frame(width: 22)
                        Text("创作")
                        Spacer()
                        Image(systemName: "chevron.right").foregroundStyle(.secondary)
                    }
                    .tileRow()
                }
                .buttonStyle(.plain)
                translateRow
            }
        }
    }

    private var commandField: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                TextField("描述你想要的修改", text: $controller.instruction, axis: .vertical)
                    .textFieldStyle(.plain)
                    .focusEffectDisabled()
                    .font(.system(size: 14))
                    .lineLimit(1...4)
                    .focused($focus, equals: .instruction)
                    .onSubmit { controller.submitInstruction() }
                MicButton(controller: controller, field: .instruction)
                if controller.canSubmitInstruction {
                    SendButton { controller.submitInstruction() }
                }
            }
            .padding(.vertical, 9)
            .padding(.leading, 18)
            .padding(.trailing, 9)
            .background(.primary.opacity(0.08), in: Capsule())
            voiceError
        }
    }

    @ViewBuilder private var voiceError: some View {
        if let message = controller.voiceError {
            Text(message).font(.caption).foregroundStyle(.red).padding(.horizontal, 6)
        }
    }

    private var translateRow: some View {
        HStack(spacing: 12) {
            Image(systemName: "translate").frame(width: 22)
            Text("翻译成")
            Spacer()
            Picker("翻译成", selection: $controller.translationTarget) {
                ForEach(TranslationLanguage.allCases) { Text($0.displayName).tag($0) }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .fixedSize()
            SendButton { controller.run(.translate) }
        }
        .tileRow()
    }

    // MARK: Compose

    private var composeScreen: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(spacing: 6) {
                TextField("想写什么？例如：写一封向主管请两天假的邮件", text: $controller.composePrompt, axis: .vertical)
                    .textFieldStyle(.plain)
                    .focusEffectDisabled()
                    .font(.system(size: 14))
                    .lineLimit(3...8)
                    .focused($focus, equals: .composePrompt)
                    .onSubmit { controller.submitCompose() }
                HStack {
                    MicButton(controller: controller, field: .composePrompt)
                    Spacer()
                    Button { controller.submitCompose() } label: {
                        Label("生成", systemImage: "sparkles").font(.system(size: 13, weight: .medium))
                    }
                    .buttonStyle(PillButtonStyle(prominent: true))
                    .disabled(!controller.canSubmitCompose)
                }
            }
            .padding(.top, 12).padding(.leading, 14).padding(.trailing, 10).padding(.bottom, 8)
            .background(.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            voiceError
            if !controller.canSubmitCompose {
                FlowLayout(spacing: 6) {
                    ForEach(Self.starters, id: \.self) { starter in
                        Chip(title: starter, selected: false) { controller.composePrompt = starter }
                    }
                }
            }
            Divider()
            optionRow(title: "类型") {
                ForEach(ComposeOptions.Kind.allCases) { kind in
                    Chip(title: kind.displayName, selected: !controller.compose.usesCustomKind && controller.compose.kind == kind) {
                        controller.compose.kind = kind
                        controller.compose.customKind = ""
                    }
                }
                CustomChipField(placeholder: "自定义，如周报", text: $controller.compose.customKind, onSubmit: controller.submitCompose)
            }
            optionRow(title: "语气") {
                ForEach(ComposeOptions.Tone.allCases) { tone in
                    Chip(title: tone.displayName, selected: !controller.compose.usesCustomTone && controller.compose.tone == tone) {
                        controller.compose.tone = tone
                        controller.compose.customTone = ""
                    }
                }
                CustomChipField(placeholder: "自定义，如幽默", text: $controller.compose.customTone, onSubmit: controller.submitCompose)
            }
            optionRow(title: "长度") {
                ForEach(ComposeOptions.Length.allCases) { length in
                    Chip(title: length.displayName, selected: !controller.compose.usesCustomLength && controller.compose.length == length) {
                        controller.compose.length = length
                        controller.compose.customLength = ""
                    }
                }
                CustomChipField(placeholder: "自定义，如约 200 字", text: $controller.compose.customLength, onSubmit: controller.submitCompose)
            }
        }
    }

    private static var starters: [String] {
        [String(localized: "向主管请两天假的邮件"), String(localized: "新功能上线的社交贴文"), String(localized: "婉拒合作邀约的消息")]
    }

    private func optionRow(title: LocalizedStringKey, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary).padding(.horizontal, 6)
            FlowLayout(spacing: 6) { content() }
        }
    }

    // MARK: Loading

    private var loading: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Text(controller.tool?.loadingText ?? "").font(.system(size: 13, weight: .semibold))
            }
            .padding(.horizontal, 6)
            SkeletonLines()
                .padding(16)
                .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            HStack {
                Spacer()
                Button("取消") { controller.back() }.buttonStyle(PillButtonStyle(prominent: false))
            }
        }
    }

    // MARK: Result

    private var resultScreen: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let result = controller.result {
                resultBox(result)
                if controller.tool == .proofread {
                    HStack(spacing: 10) {
                        Toggle("显示修改", isOn: $controller.showDiff).toggleStyle(.switch).controlSize(.small)
                        Spacer()
                        Text("\(result.changeCount) 处修改")
                    }
                    .font(.system(size: 12)).foregroundStyle(.secondary).padding(.horizontal, 6)
                } else if controller.tool != .compose, let source = controller.selection {
                    Toggle("对照原文", isOn: $controller.showOriginal).toggleStyle(.switch).controlSize(.small)
                        .font(.system(size: 12)).foregroundStyle(.secondary).padding(.horizontal, 6)
                    if controller.showOriginal {
                        CappedScrollView(maxHeight: 130) {
                            Text(source)
                                .font(.system(size: 12.5)).foregroundStyle(.secondary)
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 13).padding(.vertical, 10)
                        }
                        .background(.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                    }
                }
            }
            refineField
            voiceError
            actions
        }
    }

    /// The answer in its own scroll area (capped), so a long text never pushes "refine" and the buttons out of reach.
    @ViewBuilder private func resultBox(_ result: WritingResult) -> some View {
        CappedScrollView(maxHeight: 300) {
            Group {
                if let rows = result.table {
                    Grid(alignment: .topLeading, horizontalSpacing: 0, verticalSpacing: 0) {
                        ForEach(rows.indices, id: \.self) { r in
                            GridRow {
                                ForEach(rows[r].indices, id: \.self) { c in
                                    Text(rows[r][c])
                                        .font(.system(size: 12.5, weight: r == 0 ? .semibold : .regular))
                                        .padding(.horizontal, 8).padding(.vertical, 6)
                                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                                        .background(r == 0 ? Color.primary.opacity(0.06) : .clear)
                                        .overlay(Rectangle().strokeBorder(Color.primary.opacity(0.18), lineWidth: 0.5))
                                }
                            }
                        }
                    }
                } else if let diff = result.diff {
                    Text(Self.attributed(diff, showChanges: controller.showDiff))
                        .font(.system(size: 14)).lineSpacing(4)
                } else {
                    Text(result.text).font(.system(size: 14)).lineSpacing(4)
                }
            }
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 15).padding(.vertical, 13)
        }
        .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(.separator, lineWidth: 0.5))
    }

    /// Red strike-through for removed text, green background for added text.
    static func attributed(_ segments: [DiffSegment], showChanges: Bool) -> AttributedString {
        guard showChanges else { return AttributedString(TextDiff.newText(segments)) }
        var result = AttributedString()
        for segment in segments {
            switch segment {
            case .equal(let text):
                result += AttributedString(text)
            case .delete(let text):
                var part = AttributedString(text)
                part.strikethroughStyle = .single
                part.foregroundColor = .red
                part.backgroundColor = Color.red.opacity(0.18)
                result += part
            case .insert(let text):
                var part = AttributedString(text)
                part.backgroundColor = Color.green.opacity(0.22)
                result += part
            }
        }
        return result
    }

    private var refineField: some View {
        HStack(spacing: 8) {
            TextField("继续调整，例如：再短一点", text: $controller.refineText, axis: .vertical)
                .textFieldStyle(.plain)
                    .focusEffectDisabled()
                .font(.system(size: 13))
                .lineLimit(1...3)
                .focused($focus, equals: .refine)
                .onSubmit { controller.submitRefine() }
            MicButton(controller: controller, field: .refine)
            SendButton { controller.submitRefine() }
                .disabled(!controller.canSubmitRefine)
        }
        .padding(.vertical, 8).padding(.leading, 14).padding(.trailing, 8)
        .background(.primary.opacity(0.08), in: Capsule())
    }

    private var actions: some View {
        HStack(spacing: 8) {
            Button { controller.copyResult() } label: {
                Label {
                    if controller.copied { Text("已复制") } else { Text("复制") }
                } icon: {
                    Image(systemName: controller.copied ? "checkmark" : "doc.on.doc")
                }
            }
            .buttonStyle(PillButtonStyle(prominent: false))
            Button { controller.regenerate() } label: { Label("重新生成", systemImage: "arrow.clockwise") }
                .buttonStyle(PillButtonStyle(prominent: false))
            Spacer(minLength: 0)
            Button { Task { await controller.apply() } } label: {
                HStack(spacing: 6) {
                    if controller.replacesSelection { Text("替换") } else { Text("插入") }
                    Text("⌘↩").font(.system(size: 11, design: .monospaced)).opacity(0.75)
                }
            }
            .buttonStyle(PillButtonStyle(prominent: true))
            .disabled(!controller.canApply)
        }
        .font(.system(size: 13, weight: .medium))
        .lineLimit(1)
    }

    // MARK: Error

    private var errorScreen: some View {
        VStack(spacing: 12) {
            VStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 20)).foregroundStyle(.orange)
                    .frame(width: 44, height: 44)
                    .background(Color.orange.opacity(0.15), in: Circle())
                switch controller.failure {
                case .failed(let message)?:
                    Text("无法完成请求").font(.system(size: 14, weight: .semibold))
                    Text(message).font(.system(size: 12.5)).foregroundStyle(.secondary).multilineTextAlignment(.center)
                default:
                    Text("没有可用的 AI 服务").font(.system(size: 14, weight: .semibold))
                    Text("请先在设置中添加 API Key，或检查网络连接后再试一次。")
                        .font(.system(size: 12.5)).foregroundStyle(.secondary).multilineTextAlignment(.center)
                }
            }
            .padding(.top, 10).padding(.horizontal, 12)
            HStack(spacing: 8) {
                Button("重试") { controller.regenerate() }.buttonStyle(PillButtonStyle(prominent: false))
                Button("打开设置") { controller.openSettings() }.buttonStyle(PillButtonStyle(prominent: true))
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Pieces

/// A soft shadow that follows `shape` exactly and is cut out underneath it, so the translucent material above shows
/// the desktop and not a dark shape. (A window shadow would not match the rounded corners.)
struct CardShadow<S: Shape>: View {
    let shape: S
    var radius: CGFloat
    var y: CGFloat
    var opacity: Double

    var body: some View {
        shape.fill(Color.black)
            .shadow(color: .black.opacity(opacity), radius: radius, y: y)
            .shadow(color: .black.opacity(opacity * 0.5), radius: 2, y: 1)
            .mask {
                // The padding comes first so the cut-out below is sized like the card, not like the larger rectangle.
                Rectangle()
                    .padding(-60)
                    .overlay { shape.blendMode(.destinationOut) }
                    .compositingGroup()
            }
    }
}

private struct PanelBackground: ViewModifier {
    let material: OverlayMaterial
    let shape: RoundedRectangle

    func body(content: Content) -> some View {
        switch material {
        case .blur:
            content.background(.regularMaterial, in: shape).overlay(shape.strokeBorder(.separator.opacity(0.5)))
        case .liquidGlass:
            content.glassEffect(.regular, in: shape)
        }
    }
}

private extension View {
    /// A grey rounded row (Compose / Translate).
    func tileRow() -> some View {
        font(.system(size: 14, weight: .medium))
            .padding(.horizontal, 14).padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
    }
}

/// A scroll view that is as tall as its content up to `maxHeight`, then scrolls.
private struct CappedScrollView<Content: View>: View {
    let maxHeight: CGFloat
    @ViewBuilder let content: Content
    @State private var contentHeight: CGFloat = 0

    var body: some View {
        ScrollView {
            content.onGeometryChange(for: CGFloat.self) { $0.size.height } action: { contentHeight = $0 }
        }
        .scrollBounceBehavior(.basedOnSize)
        .frame(height: min(max(contentHeight, 1), maxHeight))
    }
}

private struct RoundIconButton: View {
    let systemName: String
    let help: LocalizedStringKey
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName).font(.system(size: 12, weight: .semibold))
                .foregroundStyle(hovering ? .primary : .secondary)
                .frame(width: 30, height: 30)
                .background(.primary.opacity(hovering ? 0.16 : 0.08), in: Circle())
        }
        .buttonStyle(.plain)
        .help(help)
        .onHover { hovering = $0 }
    }
}

private struct SendButton: View {
    let action: () -> Void
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button(action: action) {
            Image(systemName: "arrow.up").font(.system(size: 12, weight: .bold))
                .foregroundStyle(isEnabled ? Color.white : Color.secondary)
                .frame(width: 26, height: 26)
                .background(isEnabled ? Color.accentColor : Color.primary.opacity(0.1), in: Circle())
        }
        .buttonStyle(.plain)
    }
}

/// Microphone button next to a text field: tap to speak, tap again to stop; the text is typed into the field.
private struct MicButton: View {
    let controller: WritingToolsController
    let field: WritingToolsController.VoiceField

    private var isMine: Bool { controller.voiceField == field }

    var body: some View {
        Button { controller.toggleVoice(field) } label: {
            Group {
                if isMine, controller.voiceState == .transcribing {
                    ProgressView().controlSize(.small)
                } else if isMine, controller.voiceState == .recording {
                    Image(systemName: "stop.circle.fill").foregroundStyle(.red).symbolEffect(.pulse)
                } else {
                    Image(systemName: "mic").foregroundStyle(.secondary)
                }
            }
            .font(.system(size: 14))
            .frame(width: 26, height: 26)
        }
        .buttonStyle(.plain)
        .disabled(!controller.voiceInputAvailable || (controller.voiceState != .idle && !isMine))
        .help(isMine && controller.voiceState == .recording ? LocalizedStringKey("停止") : LocalizedStringKey("用语音下指令"))
    }
}

private struct ToolTile: View {
    let tool: WritingTool
    let systemName: String
    let height: CGFloat
    let action: (WritingTool) -> Void
    @State private var hovering = false

    var body: some View {
        Button { action(tool) } label: {
            VStack(spacing: 7) {
                Image(systemName: systemName).font(.system(size: height > 80 ? 22 : 19))
                Text(tool.displayName).font(.system(size: height > 80 ? 14 : 13, weight: .medium))
            }
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .background(.primary.opacity(hovering ? 0.15 : 0.08), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}

/// Summary / key points / list / table: a small "original → result" sketch above the name.
private struct FormatCard: View {
    let tool: WritingTool
    let action: (WritingTool) -> Void
    @State private var hovering = false

    var body: some View {
        Button { action(tool) } label: {
            VStack(spacing: 7) {
                sketch
                    .frame(maxWidth: .infinity)
                    .frame(height: 78)
                    .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Color.primary.opacity(hovering ? 0.3 : 0.1), lineWidth: 0.5))
                Text(tool.displayName).font(.system(size: 12.5, weight: .medium))
            }
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }

    private func line(_ width: CGFloat) -> some View {
        Capsule().fill(Color.primary.opacity(0.28)).frame(width: width, height: 2.6)
    }

    private var sketch: some View {
        VStack(spacing: 5) {
            VStack(alignment: .leading, spacing: 4) { line(40); line(40); line(28) }
            Image(systemName: "arrow.down").font(.system(size: 9, weight: .semibold)).foregroundStyle(Color.primary.opacity(0.7))
            result.frame(height: 20, alignment: .top) // the same height for every card
        }
        .frame(maxHeight: .infinity, alignment: .center)
    }

    @ViewBuilder private var result: some View {
        switch tool {
        case .summarize:
            VStack(alignment: .leading, spacing: 4) { line(40); line(22) }
        case .keyPoints:
            VStack(alignment: .leading, spacing: 4) {
                line(40)
                HStack(spacing: 3) { Circle().fill(Color.primary.opacity(0.28)).frame(width: 3, height: 3); line(34) }
            }
        case .list:
            VStack(alignment: .leading, spacing: 3) {
                ForEach([30, 22, 26], id: \.self) { w in
                    HStack(spacing: 3) { Circle().fill(Color.primary.opacity(0.28)).frame(width: 3, height: 3); line(CGFloat(w)) }
                }
            }
        default:
            RoundedRectangle(cornerRadius: 2).strokeBorder(Color.primary.opacity(0.28), lineWidth: 1.5)
                .frame(width: 42, height: 16)
                .overlay { Rectangle().fill(Color.primary.opacity(0.28)).frame(height: 1.2) }
                .overlay { HStack(spacing: 13) { Rectangle().fill(Color.primary.opacity(0.28)).frame(width: 1.2); Rectangle().fill(Color.primary.opacity(0.28)).frame(width: 1.2) } }
        }
    }
}

private struct Chip: View {
    let title: String
    let selected: Bool
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Text(title).font(.system(size: 12.5))
                .foregroundStyle(selected ? Color.white : Color.primary)
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(selected ? Color.accentColor : Color.primary.opacity(hovering ? 0.15 : 0.08), in: Capsule())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}

/// The last chip of a row: typing here replaces the chosen option.
private struct CustomChipField: View {
    let placeholder: LocalizedStringKey
    @Binding var text: String
    let onSubmit: () -> Void
    @FocusState private var focused: Bool

    private var active: Bool { !text.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        TextField(placeholder, text: $text)
            .textFieldStyle(.plain)
                    .focusEffectDisabled()
            .font(.system(size: 12.5))
            .focused($focused)
            .onSubmit(onSubmit)
            .padding(.horizontal, 12).padding(.vertical, 6)
            .frame(minWidth: 104, maxWidth: 200)
            .background(active ? Color.accentColor.opacity(0.16) : Color.primary.opacity(focused ? 0.14 : 0.08), in: Capsule())
            .onChange(of: text) { _, new in if new.count > 40 { text = String(new.prefix(40)) } }
    }
}

private struct PillButtonStyle: ButtonStyle {
    let prominent: Bool
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(prominent ? Color.white : Color.primary)
            .padding(.horizontal, 13).padding(.vertical, 8)
            .background(
                prominent ? Color.accentColor : Color.primary.opacity(configuration.isPressed ? 0.16 : 0.08),
                in: Capsule()
            )
            .opacity(isEnabled ? 1 : 0.4)
    }
}

private struct SkeletonLines: View {
    @State private var phase = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach([0.96, 0.88, 0.92, 0.54], id: \.self) { fraction in
                GeometryReader { proxy in
                    Capsule().fill(.quaternary)
                        .frame(width: proxy.size.width * fraction, height: 11)
                        .opacity(phase ? 0.45 : 1)
                }
                .frame(height: 11)
            }
        }
        .onAppear { withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) { phase = true } }
    }
}

/// Wraps its children onto new lines (the chip rows of Compose).
private struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrange(width: proposal.width ?? .infinity, subviews: subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let layout = arrange(width: bounds.width, subviews: subviews)
        for (index, frame) in layout.frames.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY), proposal: ProposedViewSize(frame.size))
        }
    }

    private func arrange(width: CGFloat, subviews: Subviews) -> (size: CGSize, frames: [CGRect]) {
        var frames: [CGRect] = []
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0, maxX: CGFloat = 0
        for subview in subviews {
            var size = subview.sizeThatFits(.unspecified)
            size.width = min(size.width, width)
            if x > 0, x + size.width > width {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            frames.append(CGRect(origin: CGPoint(x: x, y: y), size: size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            maxX = max(maxX, x - spacing)
        }
        return (CGSize(width: maxX, height: y + rowHeight), frames)
    }
}
