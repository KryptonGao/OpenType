import SwiftUI

/// Write-only API key field. The stored secret is never read back into the UI — only its presence is shown.
struct SecretField: View {
    let title: String
    let account: String
    let credentials: any CredentialStoring

    @State private var draft = ""
    @State private var hasValue = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                SecureField(title, text: $draft, prompt: Text(hasValue ? "已保存到 Keychain（输入新值以替换）" : "尚未设置"))
                    .onSubmit(save)
                Button("保存", action: save).disabled(draft.isEmpty)
                Button("清除", role: .destructive) {
                    do {
                        try credentials.delete(account: account)
                        refresh()
                    } catch { errorMessage = "清除失败" }
                }
                .disabled(!hasValue)
            }
            if let errorMessage { Text(errorMessage).font(.caption).foregroundStyle(.red) }
        }
        .onAppear(perform: refresh)
        .onChange(of: account) { _, _ in draft = ""; refresh() }
    }

    private func save() {
        let value = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return }
        do {
            try credentials.save(value, account: account)
            draft = ""
            errorMessage = nil
            refresh()
        } catch {
            errorMessage = "保存到 Keychain 失败"
        }
    }

    private func refresh() { hasValue = credentials.hasValue(account: account) }
}
