import SwiftUI

struct GroupScenesSection: View {
    @Environment(AppEnvironment.self) private var environment
    let group: Group
    let viewModel: GroupDetailViewModel

    var body: some View {
        Section("Scenes") {
            if group.scenes.isEmpty {
                Text("No scenes yet. Use the + menu to save the current light state.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(group.scenes) { scene in
                    HStack {
                        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                            Text(scene.name)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text("ID \(scene.id)")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        Spacer()
                        Button("Recall") {
                            viewModel.recallScene(scene, in: group, environment: environment)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .tint(.accentColor)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            viewModel.removeScene(scene, from: group, environment: environment)
                        } label: {
                            Label("Remove", systemImage: "trash")
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    List {
        GroupScenesSection(group: .preview, viewModel: GroupDetailViewModel())
    }
    .environment(AppEnvironment())
}
