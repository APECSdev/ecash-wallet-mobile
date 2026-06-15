// Copyright (C) 2026 LayerTwo Labs and contributors
// Licensed under the GNU General Public License v2.0 or later
// SPDX-License-Identifier: GPL-2.0-or-later

import Foundation

/// The fiat currency a user wants prices shown in. **This is the only user-facing pricing choice**
/// (Settings → Display currency); which exchange/provider supplies the rate is bundled per network
/// (`PriceProviderRegistry`), not a setting. Add a case here + ensure providers support it.
enum FiatCurrency: String, CaseIterable, Sendable {
    case usd
    case eur
    case gbp
    case jpy

    /// Uppercased ISO-ish code used in API symbols and labels ("USD").
    var code: String { rawValue.uppercased() }

    var symbol: String {
        switch self {
        case .usd: return "$"
        case .eur: return "€"
        case .gbp: return "£"
        case .jpy: return "¥"
        }
    }

    /// JPY is conventionally shown with no minor units.
    var fractionDigits: Int { self == .jpy ? 0 : 2 }

    /// Short menu label for the Settings picker, e.g. "$ USD".
    var menuLabel: String { "\(symbol) \(code)" }

    /// Format a fiat amount with this currency's symbol, grouping, and minor-unit precision.
    /// Display-only — amounts stay Int64 sats internally; this runs at the view edge.
    func format(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        // Pin grouping/decimal style so the value reads consistently across devices/locales
        // (we already supply the currency symbol ourselves): "1,234.56".
        formatter.locale = Locale(identifier: "en_US")
        formatter.minimumFractionDigits = fractionDigits
        formatter.maximumFractionDigits = fractionDigits
        let number = formatter.string(from: NSNumber(value: value))
            ?? String(format: "%.\(fractionDigits)f", value)
        return "\(symbol)\(number)"
    }
}
