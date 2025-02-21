import Foundation
import ConcurrencyExtras

/// A protocol defining the requirements for a data source.
package protocol DataSource: Sendable {
    func data<T: Decodable>(
        forKey: String,
        type: T.Type
    ) -> T?

    func set<T: Encodable>(
        _ value: T,
        forKey: String
    ) async throws

    func setNil(
        forKey: String
    ) async


    func keys() -> [String]
}

/// An enum representing the type of data source to be used.
public enum DataSourceType {
    case userDefaults(UserDefaults)
    case inMemory
}

/// A client for interacting with UserDefaults as a data source.
package struct UserDefaultsClient: Sendable, DataSource {
    nonisolated(unsafe) private let userDefaults: UserDefaults

    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    package init(userDefaults: UserDefaults) {
        self.userDefaults = userDefaults
    }

    package func data<T: Decodable>(
        forKey: String,
        type: T.Type
    ) -> T? {
        if let data = userDefaults.object(forKey: forKey) as? Data {
            do {
                return try decoder.decode(type, from: data)
            } catch {
                return nil
            }
        }
        return nil
    }

    package func set<T: Encodable>(
        _ value: T,
        forKey: String
    ) async throws {
        let data = try encoder.encode(value)
        userDefaults.set(data, forKey: forKey)
    }

    package func setNil(forKey: String) async {
        userDefaults.set(nil, forKey: forKey)
    }

    package func keys() -> [String] {
        Array(userDefaults.dictionaryRepresentation().keys)
    }
}

/// A client for managing data in memory, mainly for testing purposes.
package final class InMemoryDataSource: Sendable, DataSource {
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    let dataStore: LockIsolated<[String: Data]> = .init([:])

    package init() {}

    package func data<T>(
        forKey: String,
        type: T.Type
    ) -> T? where T : Decodable {
        guard let data = dataStore[forKey] else { return nil }
        return try? decoder.decode(type, from: data)
    }

    package func set<T: Encodable>(
        _ value: T,
        forKey: String
    ) async throws {
        let data = try encoder.encode(value)
        dataStore.withValue {
            $0[forKey] = data
        }
    }

    package func setNil(forKey: String) async {
        dataStore.withValue {
            $0[forKey] = nil
        }
    }

    package func keys() -> [String] {
        Array(dataStore.keys)
    }
}
