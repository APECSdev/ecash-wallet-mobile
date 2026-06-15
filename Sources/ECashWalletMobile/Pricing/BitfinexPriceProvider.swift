// Copyright (C) 2026 LayerTwo Labs and contributors
// Licensed under the GNU General Public License v2.0 or later
// SPDX-License-Identifier: GPL-2.0-or-later

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking   // URLSession lives here on Android/Linux Foundation, not in Foundation
#endif

/// Bitcoin spot prices from Bitfinex's public REST API (no key required). The bundled provider for
/// Bitcoin mainnet (`PriceProviderRegistry`).
///
/// `GET /v2/ticker/tBTC<FIAT>` returns a flat JSON array of 10 numbers; the LAST_PRICE we want is at
/// index 6: `[BID, BID_SIZE, ASK, ASK_SIZE, DAILY_CHANGE, DAILY_CHANGE_REL, LAST_PRICE, VOLUME, HIGH, LOW]`.
/// The fetch is injectable so parsing is unit-tested without the network.
struct BitfinexPriceProvider: PriceProvider {
    let id = "bitfinex"
    let displayName = "Bitfinex"

    private let fetch: @Sendable (URL) async throws -> Data

    init(fetch: @escaping @Sendable (URL) async throws -> Data = BitfinexPriceProvider.defaultFetch) {
        self.fetch = fetch
    }

    static func defaultFetch(_ url: URL) async throws -> Data {
        try await URLSession.shared.data(from: url).0
    }

    func supportedCurrencies() -> [FiatCurrency] { [.usd, .eur, .gbp, .jpy] }

    func spotPrice(in currency: FiatCurrency) async throws -> Double {
        guard supportedCurrencies().contains(currency) else { throw PriceError.unsupportedCurrency }
        guard let url = URL(string: "https://api-pub.bitfinex.com/v2/ticker/tBTC\(currency.code)") else {
            throw PriceError.network
        }
        let data = try await fetch(url)
        return try Self.parseLastPrice(data)
    }

    /// Pull LAST_PRICE (index 6) out of the ticker array. Split out so tests can feed fixed payloads.
    static func parseLastPrice(_ data: Data) throws -> Double {
        guard let values = try? JSONDecoder().decode([Double].self, from: data), values.count > 6 else {
            throw PriceError.badResponse
        }
        let last = values[6]
        guard last > 0 else { throw PriceError.badResponse }
        return last
    }
}
