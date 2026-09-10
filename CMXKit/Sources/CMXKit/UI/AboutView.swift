import SwiftUI

/// The About window. Leads with the pronunciation, because nobody guesses it.
public struct AboutView: View {
    private let version: String
    private let build: String
    private let licenses: [OpenSourceLicense]
    @State private var expanded: Set<String> = []

    public init(
        version: String = Bundle.main.shortVersion,
        build: String = Bundle.main.buildVersion,
        licenses: [OpenSourceLicense] = OpenSourceLicense.all
    ) {
        self.version = version
        self.build = build
        self.licenses = licenses
    }

    public var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            acknowledgements
        }
        .frame(width: 420, height: 460)
    }

    private var header: some View {
        VStack(spacing: 6) {
            if let icon = NSApplication.shared.applicationIconImage {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 96, height: 96)
                    .accessibilityHidden(true)
            }
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("cmx")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                Text("(see-mix)")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            Text("A minimal comic reader for macOS")
                .font(.callout)
                .foregroundStyle(.secondary)
            Text("Version \(version) (\(build))")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .textSelection(.enabled)
        }
        .padding(.vertical, 24)
        .frame(maxWidth: .infinity)
    }

    private var acknowledgements: some View {
        ScrollView {
            LicenseList(licenses: licenses, expanded: $expanded)
        }
    }
}

/// Split out of `AboutView` so it can be rendered and inspected on its own —
/// `ImageRenderer` draws nothing inside a `ScrollView`.
struct LicenseList: View {
    let licenses: [OpenSourceLicense]
    @Binding var expanded: Set<String>

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Open Source")
                .font(.headline)
            Text("cmx is built on work by others, used under the terms below.")
                .font(.caption)
                .foregroundStyle(.secondary)

            ForEach(licenses) { license in
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(license.name).font(.callout).bold()
                        Text(license.version)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                        Spacer()
                        Button(expanded.contains(license.id) ? "Hide" : "License") {
                            toggle(license.id)
                        }
                        .buttonStyle(.link)
                        .font(.caption)
                    }
                    Link(license.url, destination: URL(string: license.url)!)
                        .font(.caption)
                    Text(license.licenseName)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if expanded.contains(license.id) {
                        Text(license.licenseText)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(.quaternary.opacity(0.4),
                                        in: RoundedRectangle(cornerRadius: 6))
                    }
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.quaternary.opacity(0.2),
                            in: RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(16)
    }

    private func toggle(_ id: String) {
        if expanded.contains(id) { expanded.remove(id) } else { expanded.insert(id) }
    }
}

public extension Bundle {
    var shortVersion: String {
        object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
    }

    var buildVersion: String {
        object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
    }
}
