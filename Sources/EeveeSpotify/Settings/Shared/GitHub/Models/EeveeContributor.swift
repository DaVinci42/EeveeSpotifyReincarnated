struct EeveeContributor: Decodable, Equatable {
    var usernames: [String]
    var displayName: String?
    var roles: [String]

    enum CodingKeys: String, CodingKey {
        case usernames
        case displayName
        case roles
    }
}
