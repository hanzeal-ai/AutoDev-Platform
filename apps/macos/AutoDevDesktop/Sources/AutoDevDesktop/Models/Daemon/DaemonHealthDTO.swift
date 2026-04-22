import Foundation

struct DaemonHealth: Decodable {
    let status: String
    let daemonVersion: String
    let protocolVersion: Int
    let appSupportRoot: String?
    let databasePath: String?
    let blobsPath: String?
    let deepseekConfigured: Bool?
    let deepseekModel: String?
    let deepseekBaseUrl: String?
}
