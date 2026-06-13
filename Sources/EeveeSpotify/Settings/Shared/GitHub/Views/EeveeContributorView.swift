import SwiftUI

struct EeveeContributorView: View {
    var contributor: EeveeContributor
    var githubUser: GitHubUser
    
    var body: some View {
        VStack {
            Link(destination: URL(string: githubUser.htmlUrl)!) {
                HStack(spacing: 10) {
                    HStack(spacing: -8) {
                        ForEach(contributor.usernames, id: \.self) { username in
                            ImageView(urlString: "https://github.com/\(username).png")
                                .frame(width: 48, height: 48)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Color(uiColor: .systemBackground), lineWidth: 2))
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 0) {
                        Text(contributor.usernames.joined(separator: " & "))
                            .foregroundColor(.white)
                            .font(.headline)
                        
                        ForEach(contributor.roles, id: \.self) { role in
                            Text(role)
                        }
                        .foregroundColor(.gray)
                    }
                    
                    Spacer()
                    
                    ChevronRightView()
                }
            }
        }
    }
}
