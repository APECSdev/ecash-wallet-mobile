// Copyright (C) 2026 LayerTwo Labs and contributors
// Licensed under the GNU General Public License v2.0 or later
// SPDX-License-Identifier: GPL-2.0-or-later

import Foundation
import Observation
import SkipFuse   // @Observable must drive the Compose UI on Android (Fuse)
import WalletService

/// Holds the user's display currency (persisted) and the latest fetched `PriceQuote`, and converts
/// sats → a fiat string. The provider is resolved **per network** via `PriceProviderRegistry`, so
/// switching networks (or, later, adding eCash) needs no change here. Pricing is best-effort and
/// never blocks the wallet: a failed fetch keeps the last quote and stays silent.
@MainActor
@Observable
final class PriceService {
    /// The latest successful quote, or `nil` when the current network has no provider / nothing
    /// fetched yet. Only set from a provider result, so a non-nil quote means "show fiat".
    private(set) var quote: PriceQuote?

    /// User's chosen display currency (the only user-facing pricing setting). Persisted; changing it
    /// drops the stale quote until the next refresh.
    var currency: FiatCurrency {
        didSet {
            UserDefaults.standard.set(currency.rawValue, forKey: Self.currencyKey)
            quote = nil
        }
    }

    private static let currencyKey = "fiatCurrency"

    /// How a network maps to its bundled provider. Defaults to `PriceProviderRegistry`; injectable so
    /// tests can supply a stub provider without hitting the network.
    private let resolveProvider: (WalletNetwork) -> PriceProvider?

    init(resolveProvider: @escaping (WalletNetwork) -> PriceProvider? = PriceProviderRegistry.provider(for:)) {
        self.resolveProvider = resolveProvider
        let saved = UserDefaults.standard.string(forKey: Self.currencyKey)
        currency = saved.flatMap(FiatCurrency.init(rawValue:)) ?? .usd
    }

    /// Fetch the price for `network`'s bundled provider in the current currency. Networks without a
    /// provider (testnets) clear the quote so no fiat is shown. Silent on failure.
    func refresh(for network: WalletNetwork) async {
        guard let provider = resolveProvider(network) else {
            quote = nil
            return
        }
        do {
            let price = try await provider.spotPrice(in: currency)
            quote = PriceQuote(currency: currency, pricePerCoin: price, providerName: provider.displayName)
        } catch {
            // Non-critical: keep any previous quote and don't surface an error.
        }
    }

    /// Format `sats` in the current quote's currency, or `nil` if there's no quote.
    func fiatString(forSats sats: Int64) -> String? {
        guard let quote else { return nil }
        let coins = Double(sats) / 100_000_000.0
        return quote.currency.format(coins * quote.pricePerCoin)
    }
}
