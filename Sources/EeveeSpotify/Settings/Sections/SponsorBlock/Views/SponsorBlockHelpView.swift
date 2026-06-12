import SwiftUI

struct SponsorBlockHelpView: View {
    var body: some View {
        List {
            Section(header: Text("playerGesturesTitle".localized)) {
                row(symbol: "hand.tap",
                    title: "gesturesTitle1",
                    detail: "gesturesDeps1")
                row(symbol: "hand.point.up.left.fill",
                    title: "gesturesTitle2",
                    detail: "gesturesDeps2")
            }

            Section(header: Text("submittingTitle".localized)) {
                row(symbol: "square.and.pencil",
                    title: "submittingSectionTitle1",
                    detail: "submittingSectionDeps1")
                row(symbol: "lock.shield",
                    title: "submittingSectionTitle2",
                    detail: "submittingSectionDeps2")
            }

            Section(header: Text("skipToastTitle")) {
                row(symbol: "arrow.uturn.backward",
                    title: "skipToastSectionTitle1",
                    detail: "skipToastSectionDeps1")
                row(symbol: "hand.thumbsup.fill",
                    title: "skipToastSectionTitle2",
                    detail: "skipToastSectionDeps2")
                row(symbol: "ellipsis",
                    title: "skipToastSectionTitle3",
                    detail: "skipToastSectionDeps3")
            }

            Section(header: Text("managingSegmentsTitle")) {
                row(symbol: "list.bullet.rectangle.portrait",
                    title: "managingSegmentsSectionTitle1",
                    detail: "managingSegmentsSectionDeps1")
                row(symbol: "tray.full",
                    title: "managingSegmentsSectionTitle2",
                    detail: "managingSegmentsSectionDeps2")
            }

            Section(header: Text("categoriesTitle")) {
                row(symbol: "list.bullet.rectangle",
                    title: "categoriesSectionTitle1",
                    detail: "categoriesSectionDeps1")
            }

            Section {
                Color.clear
                    .frame(height: 90)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
            }
        }
        .listStyle(InsetGroupedListStyle())
        .navigationTitle(NSLocalizedString("howToUseTitle", comment: ""))
    }

    private func row(symbol: String, title: LocalizedStringKey, detail: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.accentColor)
                .frame(width: 28, alignment: .center)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(detail).font(.footnote).foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}
