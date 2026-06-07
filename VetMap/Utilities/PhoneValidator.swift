import Foundation

enum PhoneValidator {
    static func isValid(_ phone: String) -> Bool {
        let cleaned = phone.replacingOccurrences(of: "[^0-9+]", with: "", options: .regularExpression)
        // HK: 8 digits, may start with +852
        // TW: 9-10 digits, may start with +886
        guard cleaned.count >= 8 else { return false }
        let hkPattern = #"^(?:\+852)?[2-9]\d{7}$"#
        let twPattern = #"^(?:\+886)?0?9\d{8}$"#
        return cleaned.range(of: hkPattern, options: .regularExpression) != nil ||
               cleaned.range(of: twPattern, options: .regularExpression) != nil
    }
    
    static func format(_ phone: String) -> String {
        let cleaned = phone.replacingOccurrences(of: "[^0-9+]", with: "", options: .regularExpression)
        if cleaned.hasPrefix("+852") && cleaned.count == 12 {
            return cleaned // Already formatted
        }
        if cleaned.hasPrefix("+886") && cleaned.count == 13 {
            return cleaned
        }
        if cleaned.count == 8 {
            return "+852 " + cleaned
        }
        if cleaned.count == 10 {
            return "+886 " + cleaned
        }
        return phone
    }
}
