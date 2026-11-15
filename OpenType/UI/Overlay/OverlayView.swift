import SwiftUI

struct OverlayView: View {
    let coordinator: DictationSessionCoordinator
    /// Reports the size the content wants. The panel is resized from this callback (asynchronously) instead of letting
    /// the hosting view drive the window size, which could loop forever between window layout and SwiftUI layout.
    var onContentSizeChange: (CGSize) -> Void = { _ in }

    var body: some View {
        content
            .onGeometryChange(for: CGSize.self) { $0.size } action: { onContentSizeChange($0) }
    }

    @ViewBuilder private var content: some View {
        if usesMinimalLayout {
            minimalBody
        } else {
            fullBody
        }
    }

    /// The full window follows the full-window setting, except in minimal mode, where it is the expanded form of the
    /// capsule (error / manual copy) and keeps the capsule's material.
    private var fullMaterial: OverlayMaterial {
        coordinator.settingsStore.overlayMinimalMode
            ? coordinator.settingsStore.overlayMinimalMaterial
            : coordinator.settingsStore.overlayMaterial
    }

    private var minimalMaterial: OverlayMaterial { coordinator.settingsStore.overlayMinimalMaterial }

    // MARK: Minimal layout

    /// Minimal mode shows capsules only. Errors and manual-copy results need the full card (message / copy button).
    private var usesMinimalLayout: Bool {
        guard coordinator.settingsStore.overlayMinimalMode else { return false }
        switch coordinator.state {
        case .manualCopy, .error: return false
        default: return true
        }
    }

    /// Main capsule plus optional translation / web-search capsules. The extras sit on the side facing the screen centre
    /// (above the main capsule at the bottom of the screen, below it at the top) so the main capsule never moves.
    private var minimalBody: some View {
        let extras = VStack(spacing: 6) {
            if let status = coordinator.webSearchStatus, coordinator.state == .processing {
                webSearchCapsule(status)
            }
            if let target = coordinator.translationTarget {
                translationCapsule(target)
            } else if showsMinimalPresetCapsule {
                presetCapsule
            }
        }
        return VStack(spacing: 6) {
            if coordinator.settingsStore.overlayPosition == .topCenter {
                mainCapsule
                extras
            } else {
                extras
                mainCapsule
            }
        }
        .padding(8) // room for the window shadow
    }

    private var mainCapsule: some View {
        VStack(spacing: 3) {
            if let label = coordinator.modeLabel {
                Text(label)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            Group {
                switch coordinator.state {
                case .recording, .connecting:
                    WaveformView(levels: Array(coordinator.levelHistory.suffix(12)), color: statusColor, spacing: 2)
                        .frame(width: 56, height: 14)
                default:
                    statusIcon
                }
            }
            .frame(minHeight: 16)
        }
        .frame(minWidth: 72, minHeight: coordinator.modeLabel != nil ? 46 : 28)
        .padding(.horizontal, 10)
        .padding(.vertical, coordinator.modeLabel != nil ? 4 : 0)
        .overlayBackground(minimalMaterial, in: Capsule())
    }

    private func translationCapsule(_ target: TranslationLanguage) -> some View {
        translationPicker(target)
            .fixedSize()
            .padding(.horizontal, 14)
            .frame(minHeight: 30)
            .overlayBackground(minimalMaterial, in: Capsule())
    }

    /// In minimal mode the preset only gets a capsule when it is not simply the default one (e.g. an app rule applied).
    private var showsMinimalPresetCapsule: Bool {
        guard showsPresetPicker else { return false }
        switch coordinator.state {
        case .connecting, .recording, .finalizing: return coordinator.activePreset.id != coordinator.presetStore.defaultPresetID
        default: return false
        }
    }

    private var presetCapsule: some View {
        presetPicker
            .fixedSize()
            .padding(.horizontal, 14)
            .frame(minHeight: 30)
            .overlayBackground(minimalMaterial, in: Capsule())
    }

    private func webSearchCapsule(_ status: String) -> some View {
        Label(status, systemImage: "magnifyingglass")
            .font(.callout)
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .truncationMode(.tail)
            .frame(minWidth: 300, maxWidth: 420)
            .fixedSize(horizontal: true, vertical: false)
            .padding(.horizontal, 16)
            .frame(minHeight: 30)
            .overlayBackground(minimalMaterial, in: Capsule())
    }

    // MARK: Full layout

    private var fullBody: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                statusIcon
                    .font(.title3)
                Text(statusTitle)
                    .font(.headline)
                    .lineLimit(2)
                Spacer(minLength: 0)
                trailingControl
            }

            if let status = coordinator.webSearchStatus, coordinator.state == .processing {
                Label(status, systemImage: "magnifyingglass")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if let target = coordinator.translationTarget {
                translationPicker(target)
            } else if showsPresetPicker, coordinator.presetStore.presets.count > 1 {
                presetPicker
            }

            if showsWaveform {
                WaveformView(levels: coordinator.levelHistory, color: statusColor)
                    .frame(height: 26)
            }

            if showsTranscript {
                Text("\(Text(coordinator.solidText).foregroundStyle(.primary))\(Text(coordinator.stashText).foregroundStyle(.secondary))")
                    .font(.body)
                    .lineLimit(4)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if !coordinator.pendingText.isEmpty, showsPendingText {
                Text(coordinator.pendingText)
                    .font(.body)
                    .textSelection(.enabled)
                    .lineLimit(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                HStack {
                    Button("复制文本") { coordinator.copyPendingText() }
                        .buttonStyle(.borderedProminent)
                    Button("关闭") { coordinator.cancelSession() }
                    Spacer()
                    Text("按 Esc 关闭").font(.caption).foregroundStyle(.secondary)
                }
                .controlSize(.small)
            } else if case .error = coordinator.state {
                HStack {
                    Spacer()
                    Button("关闭") { coordinator.cancelSession() }.controlSize(.small)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(width: 420)
        .overlayBackground(fullMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .padding(8) // room for the window shadow
    }

    /// A long press already made this "help me say" (its own prompt), and translation has its own prompt: no preset then.
    private var showsPresetPicker: Bool {
        coordinator.translationTarget == nil && !coordinator.isHelpMeSay && !coordinator.isVoiceRewrite
    }

    /// Popup row: the preset of this session (from the app's rule or the default), changeable until processing starts.
    private var presetPicker: some View {
        HStack(spacing: 8) {
            Image(systemName: coordinator.activePreset.symbolName).foregroundStyle(.secondary)
            Text("预设").foregroundStyle(.secondary)
            Menu {
                ForEach(coordinator.presetStore.presets) { preset in
                    Button {
                        coordinator.setPreset(preset)
                    } label: {
                        if preset.id == coordinator.activePreset.id {
                            Label(preset.displayName, systemImage: "checkmark")
                        } else {
                            Text(preset.displayName)
                        }
                    }
                }
            } label: {
                Text(coordinator.activePreset.displayName)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .disabled(!coordinator.canChangePreset)
            Spacer(minLength: 0)
        }
        .font(.callout)
    }

    /// Popup row: translation target language, pre-selected from Settings and changeable until processing starts.
    private func translationPicker(_ target: TranslationLanguage) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "character.bubble").foregroundStyle(.secondary)
            Text("翻译为").foregroundStyle(.secondary)
            Menu {
                ForEach(TranslationLanguage.allCases) { language in
                    Button {
                        coordinator.setTranslationTarget(language)
                    } label: {
                        if language == target {
                            Label(language.displayName, systemImage: "checkmark")
                        } else {
                            Text(language.displayName)
                        }
                    }
                }
            } label: {
                Text(target.displayName)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .disabled(!coordinator.canChangeTranslationTarget)
            if !target.regions.isEmpty {
                Text("用语").foregroundStyle(.secondary)
                Menu {
                    ForEach(target.regions) { region in
                        Button {
                            coordinator.setTranslationRegion(region)
                        } label: {
                            if region == coordinator.translationRegion {
                                Label(region.displayName, systemImage: "checkmark")
                            } else {
                                Text(region.displayName)
                            }
                        }
                    }
                } label: {
                    Text(coordinator.translationRegion?.displayName ?? target.regions[0].displayName)
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .disabled(!coordinator.canChangeTranslationTarget)
            }
            Spacer(minLength: 0)
        }
        .font(.callout)
    }

    // MARK: Derived state

    @ViewBuilder private var statusIcon: some View {
        switch coordinator.state {
        case .connecting, .finalizing, .processing, .inserting:
            ProgressView().controlSize(.small)
        case .success:
            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
        case .manualCopy:
            Image(systemName: "doc.on.clipboard").foregroundStyle(.orange)
        case .error:
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.yellow)
        case .recording:
            Image(systemName: "mic.fill").foregroundStyle(.red)
        case .idle:
            Image(systemName: "mic").foregroundStyle(.secondary)
        }
    }

    @ViewBuilder private var trailingControl: some View {
        if coordinator.state == .recording || coordinator.state == .connecting, coordinator.sessionMode == .toggle {
            Button("完成") { coordinator.stopRecording() }
                .controlSize(.small)
                .buttonStyle(.borderedProminent)
        }
    }

    private var showsWaveform: Bool {
        coordinator.state == .recording || coordinator.state == .connecting
    }

    private var showsTranscript: Bool {
        switch coordinator.state {
        case .recording, .connecting, .finalizing, .processing: !(coordinator.solidText + coordinator.stashText).isEmpty
        default: false
        }
    }

    private var showsPendingText: Bool {
        switch coordinator.state {
        case .manualCopy, .error: true
        default: false
        }
    }

    private var statusColor: Color {
        coordinator.state == .recording ? .blue : .secondary
    }

    private var statusTitle: String {
        switch coordinator.state {
        case .idle: String(localized: "待机")
        case .connecting: coordinator.modeLabel.map { String(localized: "\($0) · 正在连接…") } ?? String(localized: "正在连接…")
        case .recording:
            switch (coordinator.modeLabel, coordinator.sessionMode) {
            case (let label?, .hold): String(localized: "\(label) · 正在聆听…（松开结束）")
            case (let label?, .toggle): String(localized: "\(label) · 正在聆听…（再按一次结束）")
            case (nil, .hold): String(localized: "正在聆听…（松开结束）")
            case (nil, .toggle): String(localized: "正在聆听…（再按一次结束）")
            }
        case .finalizing: String(localized: "正在收尾…")
        case .processing:
            coordinator.isVoiceRewrite ? String(localized: "正在改写…") : coordinator.runsHelpMeSay ? (coordinator.translationTarget == nil ? String(localized: "正在帮你说…") : String(localized: "正在帮你说并翻译…")) : coordinator.translationTarget == nil ? (coordinator.activePreset.kind == .shellCommand ? String(localized: "正在生成命令…") : String(localized: "正在整理文本…")) : String(localized: "正在翻译…")
        case .inserting: String(localized: "正在插入…")
        case .success(let note): note.map { String(localized: "已插入 · \($0)") } ?? String(localized: "已插入")
        case .manualCopy(let reason): String(localized: "未自动插入：\(reason)")
        case .error(let message): message
        }
    }
}

private extension View {
    @ViewBuilder
    func overlayBackground(_ material: OverlayMaterial, in shape: some InsettableShape) -> some View {
        switch material {
        case .blur:
            background(.regularMaterial, in: shape)
                .overlay(shape.strokeBorder(.separator.opacity(0.5)))
        case .liquidGlass:
            glassEffect(.regular, in: shape)
        }
    }
}

private struct WaveformView: View {
    let levels: [Float]
    let color: Color
    var spacing: CGFloat = 3

    var body: some View {
        GeometryReader { proxy in
            let count = levels.count
            let barWidth = max(2, (proxy.size.width - spacing * CGFloat(count - 1)) / CGFloat(count))
            HStack(alignment: .center, spacing: spacing) {
                ForEach(levels.indices, id: \.self) { index in
                    Capsule()
                        .fill(color.opacity(0.85))
                        .frame(width: barWidth, height: max(3, CGFloat(levels[index]) * proxy.size.height))
                }
            }
            .frame(maxHeight: .infinity)
        }
        .animation(.linear(duration: 0.08), value: levels)
    }
}
