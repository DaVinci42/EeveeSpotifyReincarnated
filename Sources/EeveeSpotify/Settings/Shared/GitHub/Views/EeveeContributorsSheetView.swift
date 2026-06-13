import SwiftUI

struct ContributorRow: View {
    let contributor: EeveeContributor

    var body: some View {
        HStack(alignment: .center, spacing: 6) {
            if contributor.usernames.count > 1 {
                ForEach(Array(contributor.usernames.enumerated()), id: \.offset) { index, username in
                    if index > 0 {
                        Text("&")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    HStack(spacing: 4) {
                        ImageView(urlString: "https://github.com/\(username).png")
                            .frame(width: 20, height: 20)
                            .clipShape(Circle())
                        Text(nameFor(index: index, username: username))
                            .font(.headline)
                    }
                }
            } else {
                ImageView(urlString: "https://github.com/\(contributor.usernames[0]).png")
                    .frame(width: 40, height: 40)
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 4) {
                    Text(contributor.displayName ?? contributor.usernames[0])
                        .font(.headline)

                    Text(contributor.roles.joined(separator: ", "))
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
            }

            Spacer()
        }
        .if(contributor.usernames.count > 1) { view in
            view.overlay(
                Text(contributor.roles.joined(separator: ", "))
                    .font(.subheadline)
                    .foregroundColor(.gray),
                alignment: .bottomLeading
            )
            .padding(.bottom, 14)
        }
        .padding(.vertical, 4)
    }

    private func nameFor(index: Int, username: String) -> String {
        guard let displayName = contributor.displayName else {
            return username
        }
        if contributor.usernames.count == 1 {
            return displayName
        }
        let parts = displayName.components(separatedBy: " & ")
        if index < parts.count {
            return parts[index]
        }
        return username
    }
}

extension View {
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

struct EeveeContributorsSheetView: View {
    @State private var sections: [EeveeContributorSection] = []
    @State private var isLoading = true
    @State private var errorMessage: String? = nil

    var body: some View {
        NavigationView {
            contentView
                .navigationTitle("contributors".localized)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    Button {
                        WindowHelper.shared.dismissCurrentViewController()
                    } label: {
                        Text("Done".uiKitLocalized)
                            .font(.headline)
                    }
                }
                .onAppear {
                    loadContributors()
                }
        }
    }

    @ViewBuilder
    private var contentView: some View {
        if isLoading {
            ProgressView("Loading".uiKitLocalized)
        } else if let error = errorMessage {
            VStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.largeTitle)
                    .foregroundColor(.orange)
                Text("Failed to load contributors")
                    .font(.headline)
                Text(error)
                    .font(.caption)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                Button("Retry") {
                    isLoading = true
                    errorMessage = nil
                    loadContributors()
                }
            }
        } else if sections.isEmpty {
            Text("No contributors found")
                .foregroundColor(.gray)
        } else {
            contributorsList
        }
    }

    private var contributorsList: some View {
        List {
            ForEach(sections, id: \.title) { section in
                Section(header: Text(section.title)) {
                    let contributors = section.shuffled ? section.contributors.shuffled() : section.contributors
                    ForEach(contributors, id: \.usernames) { contributor in
                        ContributorRow(contributor: contributor)
                    }
                }
            }
        }
    }

    private func loadContributors() {
        Task {
            do {
                sections = try await GitHubHelper.shared.getEeveeContributorSections()
            } catch {
                print("Failed to load contributors: \(error)")
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }
}
