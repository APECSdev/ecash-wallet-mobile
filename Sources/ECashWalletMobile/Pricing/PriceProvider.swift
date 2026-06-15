// Copyright (C) 2026 LayerTwo Labs and contributors
// Licensed under the GNU General Public License v2.0 or later
// SPDX-License-Identifier: GPL-2.0-or-later

import Foundation

/// A source of spot prices for one coin (e.g. Bitcoin). Implementations hit a specific exchange or
/// aggregator API. Providers are **bundled per network** (`PriceProviderRegistry`) — picking one is
/// a code/registry decision, never a user setting. Adding a new exchange = a new conformer; adding a
/// network's price = one registry entry.
protocol PriceProvider: Sendable {
    /// Stable identifier ("bitfinex").
    var id: String { get }
    /// Human label for diagnostics / attribution ("Bitfinex").
    var displayName: String { get }
    /// The fiat currencies this provider can quote.
    func supportedCurrencies() -> [FiatCurrency]
    /// Fetch the latest spot price of one coin in `currency`. Throws on network/parse failure.
    func spotPrice(in currency: FiatCurrency) async throws -> Double
}

/// The last successfully-fetched price, tagged with the currency + provider it came from.
struct PriceQuote: Equatable, Sendable {
    let currency: FiatCurrency
    let pricePerCoin: Double
    let providerName: String
}

enum PriceError: Error, Equatable {
    case unsupportedCurrency
    case badResponse
    case network
}
