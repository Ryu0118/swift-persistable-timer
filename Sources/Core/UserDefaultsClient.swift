import Foundation

protocol UserDefaultsClient {
    func data<T: Decodable>(
        forKey: String,
        type: T.Type
    ) -> T?

    func set(
        _ value: some Encodable,
        forKey: String
    ) throws

    func set(_ value: Any?, forKey: String)
}

struct UserDefaultsClientImpl: UserDefaultsClient {
    private let userDefaults: UserDefaults
    
    init(userDefaults: UserDefaults) {
        self.userDefaults = userDefaults
    }

    func data<T: Decodable>(
        forKey: String,
        type: T.Type
    ) -> T? {
        if let data = userDefaults.data(forKey: forKey) {
            let decoder = JSONDecoder()
            do {
                return try decoder.decode(type, from: data)
            } catch {
                return nil
            }
        }
        return nil
    }

    func set(
        _ value: some Encodable,
        forKey: String
    ) throws {
        let encoder = JSONEncoder()
        let data = try encoder.encode(value)
        userDefaults.set(data, forKey: forKey)
    }

    func set(_ value: Any?, forKey: String) {
        userDefaults.set(value, forKey: forKey)
    }
}

#if DEBUG
final class MockUserDefaultsClient: UserDefaultsClient {
    var dataStore: [String: Data] = [:]

    func data<T>(
        forKey: String,
        type: T.Type
    ) -> T? where T : Decodable {
        guard let data = dataStore[forKey] else { return nil }
        let decoder = JSONDecoder()
        return try? decoder.decode(type, from: data)
    }

    func set(
        _ value: some Encodable,
        forKey: String
    ) throws {
        let encoder = JSONEncoder()
        let data = try encoder.encode(value)
        dataStore[forKey] = data
    }

    func set(_ value: Any?, forKey: String) {
        dataStore[forKey] = value as? Data
    }
}
#endif
