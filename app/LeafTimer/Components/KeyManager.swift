import Foundation

struct KeyManager {
    private let keyFilePath = Bundle.main.path(forResource: "Keys", ofType: "plist")

    func getKeys() -> NSDictionary? {
        guard let keyFilePath else {
            return nil
        }
        return NSDictionary(contentsOfFile: keyFilePath)
    }

    func getValue(key: String) -> AnyObject? {
        guard let keys = getKeys() else {
            return nil
        }
        return keys[key] as AnyObject
    }

    /// 広告ユニット ID を環境別に返す。
    /// - Debug ビルド: Google 公式のテスト用 Banner ID (本番広告に影響しない)
    /// - Release ビルド: `Keys.plist` の `adUnitID` (本番 ID)
    func getAdUnitID() -> String {
        #if DEBUG
        return "ca-app-pub-3940256099942544/2934735716"
        #else
        return getValue(key: "adUnitID") as? String ?? ""
        #endif
    }
}
