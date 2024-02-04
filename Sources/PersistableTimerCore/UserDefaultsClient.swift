import Foundation

package protocol UserDefaultsClient {
    func data<T: Decodable>(
        forKey: String,
        type: T.Type
    ) -> T?

    func set(
        _ value: some Encodable,
        forKey: String
    ) async throws

    func set(_ value: Any?, forKey: String) async
}

package struct UserDefaultsClientImpl: UserDefaultsClient {
    private let userDefaults: UserDefaults
    
    package init(userDefaults: UserDefaults) {
        self.userDefaults = userDefaults
    }

    package func data<T: Decodable>(
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

    package func set(
        _ value: some Encodable,
        forKey: String
    ) async throws {
        let encoder = JSONEncoder()
        let data = try encoder.encode(value)
        userDefaults.set(data, forKey: forKey)
    }

    package func set(_ value: Any?, forKey: String) async {
        userDefaults.set(value, forKey: forKey)
    }
}

#if DEBUG
package final class MockUserDefaultsClient: UserDefaultsClient {
    var dataStore: [String: Data] = [:]

    package init() {}

    package func data<T>(
        forKey: String,
        type: T.Type
    ) -> T? where T : Decodable {
        guard let data = dataStore[forKey] else { return nil }
        let decoder = JSONDecoder()
        return try? decoder.decode(type, from: data)
    }

    package func set(
        _ value: some Encodable,
        forKey: String
    ) async throws {
        let encoder = JSONEncoder()
        let data = try encoder.encode(value)
        dataStore[forKey] = data
    }

    package func set(_ value: Any?, forKey: String) async {
        dataStore[forKey] = value as? Data
    }
}
#endif
