import SwiftUI

struct SettingsTextField: View {
    let label: String
    @Binding var text: String
    var placeholder: String = ""

    init(_ label: String, text: Binding<String>, placeholder: String = "") {
        self.label = label
        self._text = text
        self.placeholder = placeholder
    }

    var body: some View {
        LabeledContent(label) {
            TextField(placeholder, text: $text)
                .multilineTextAlignment(.trailing)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
        }
    }
}

#Preview {
    Form {
        SettingsTextField("Server URL", text: .constant("mqtt://localhost:1883"), placeholder: "mqtt://localhost:1883")
        SettingsTextField("Username", text: .constant(""), placeholder: "Optional")
    }
}
