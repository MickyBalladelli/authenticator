import Foundation

struct OTPParameters: Equatable {
    var label: String
    var accountName: String
    var secret: String
    var digits: Int
    var period: Int
    var algorithm: TOTPAlgorithm
}

enum OTPURIParserError: LocalizedError, Equatable {
    case invalidURL
    case unsupportedScheme
    case unsupportedType(String)
    case missingSecret
    case invalidSecret
    case invalidDigits
    case invalidPeriod

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid otpauth URI."
        case .unsupportedScheme:
            return "URI must start with otpauth://."
        case .unsupportedType(let type):
            return "Unsupported OTP type: \(type). Only TOTP is supported."
        case .missingSecret:
            return "Missing secret parameter."
        case .invalidSecret:
            return "Secret is not valid Base32."
        case .invalidDigits:
            return "Digits must be 6 or 8."
        case .invalidPeriod:
            return "Period must be a positive number of seconds."
        }
    }
}

enum OTPURIParser {
    static func parse(_ raw: String) -> Result<OTPParameters, OTPURIParserError> {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let components = URLComponents(string: trimmed) else {
            return .failure(.invalidURL)
        }

        guard components.scheme?.lowercased() == "otpauth" else {
            return .failure(.unsupportedScheme)
        }

        let type = (components.host ?? "").lowercased()
        guard type == "totp" else {
            return .failure(.unsupportedType(type.isEmpty ? "unknown" : type))
        }

        let queryItems = Dictionary(
            uniqueKeysWithValues: (components.queryItems ?? []).compactMap { item -> (String, String)? in
                guard let value = item.value else { return nil }
                return (item.name.lowercased(), value)
            }
        )

        guard let secretValue = queryItems["secret"]?.trimmingCharacters(in: .whitespacesAndNewlines),
              !secretValue.isEmpty else {
            return .failure(.missingSecret)
        }

        guard Base32.isValid(secretValue) else {
            return .failure(.invalidSecret)
        }

        let digits: Int
        if let digitsString = queryItems["digits"] {
            guard let parsed = Int(digitsString), parsed == 6 || parsed == 8 else {
                return .failure(.invalidDigits)
            }
            digits = parsed
        } else {
            digits = 6
        }

        let period: Int
        if let periodString = queryItems["period"] {
            guard let parsed = Int(periodString), parsed > 0 else {
                return .failure(.invalidPeriod)
            }
            period = parsed
        } else {
            period = 30
        }

        let algorithm = TOTPAlgorithm(uriValue: queryItems["algorithm"])

        let path = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let decodedPath = path.removingPercentEncoding ?? path
        let (pathIssuer, pathAccount) = splitLabel(decodedPath)

        let queryIssuer = queryItems["issuer"]?.removingPercentEncoding ?? queryItems["issuer"]
        let label = firstNonEmpty(queryIssuer, pathIssuer) ?? ""
        let accountName = firstNonEmpty(pathAccount, decodedPath) ?? ""

        return .success(
            OTPParameters(
                label: label,
                accountName: accountName,
                secret: secretValue,
                digits: digits,
                period: period,
                algorithm: algorithm
            )
        )
    }

    private static func splitLabel(_ label: String) -> (issuer: String?, account: String?) {
        guard !label.isEmpty else { return (nil, nil) }
        if let colon = label.firstIndex(of: ":") {
            let issuer = String(label[..<colon]).trimmingCharacters(in: .whitespacesAndNewlines)
            let account = String(label[label.index(after: colon)...]).trimmingCharacters(in: .whitespacesAndNewlines)
            return (issuer.isEmpty ? nil : issuer, account.isEmpty ? nil : account)
        }
        return (nil, label)
    }

    private static func firstNonEmpty(_ values: String?...) -> String? {
        for value in values {
            if let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return value.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        return nil
    }
}
