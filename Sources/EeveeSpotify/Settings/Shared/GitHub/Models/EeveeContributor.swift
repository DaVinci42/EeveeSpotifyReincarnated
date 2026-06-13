struct EeveeContributor: Decodable, Equatable {
    var usernames: [String]
    var displayName: String?
    var roles: [String]

    enum CodingKeys: String, CodingKey {
        case usernames
        case displayName
        case roles
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        usernames = try container.decode([String].self, forKey: .usernames)
        displayName = try container.decodeIfPresent(String.self, forKey: .displayName)
        roles = try container.decode([String].self, forKey: .roles)
    }
}
