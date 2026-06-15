// Copyright (C) 2026 LayerTwo Labs and contributors
// Licensed under the GNU General Public License v2.0 or later
// SPDX-License-Identifier: GPL-2.0-or-later

import SwiftUI
import WalletService

/// The one interstitial in the create flow (Welcome → here → generate → Home). Sets the
/// self-custody expectation ("your keys, we can't recover them"), then generates the seed.
/// Backing up the phrase is deferred to the Backup flow — a nudge waits on Home (Slice 3).
///
/// All visuals are `Theme` tokens + shared components, so this is easy to restyle.
struct CreateConfirmView: View {
    let defaultName: String
    @State var vm: CreateViewModel   // not `private` — Fuse bridges @State to Compose (skip-fuse rule)
    @State var wordCount = 12        // recovery-phrase length (12 default; 24 offered)
    @State var network: WalletNetwork = .signet   // default to a testnet-class net; mainnet is deliberate

    init(viewModel: CreateViewModel, defaultName: String) {
        self.defaultName = defaultName
        _vm = State(initialValue: viewModel)
    }

    var body: some View {
        ZStack {
            Theme.Colors.bg0.ignoresSafeArea()

            VStack(alignment: .leading, spacing: Theme.Space.x5) {
                Spacer()

                // Network is chosen up front (it fixes the address set) and unmistakable (Golden Rule §4/§6).
                NetworkSelector(network: $network)

                Text("Your keys, your coins", bundle: .module, comment: "create wallet heading")
                    .textStyle(.h1)
                    .foregroundStyle(Theme.Colors.text0)

                Text("This wallet lives only on this device. Your recovery phrase is the only way to restore it — not even we can recover it for you. You'll back it up right after.",
                     bundle: .module, comment: "create wallet self-custody explainer")
                    .textStyle(.body)
                    .foregroundStyle(Theme.Colors.text1)

                // Recovery-phrase length. 12 is plenty for most wallets; 24 adds entropy.
                VStack(alignment: .leading, spacing: Theme.Space.x2) {
                    Text("Recovery phrase length", bundle: .module, comment: "create: seed length label")
                        .textStyle(.overline)
                        .foregroundStyle(Theme.Colors.text2)
                    Picker("Recovery phrase length", selection: $wordCount) {
                        Text("12 words", bundle: .module, comment: "create: 12-word seed").tag(12)
                        Text("24 words", bundle: .module, comment: "create: 24-word seed").tag(24)
                    }
                    .pickerStyle(.segmented)
                    Text("12 words is plenty for most wallets. 24 adds extra entropy — more to write down.",
                         bundle: .module, comment: "create: seed length explainer")
                        .textStyle(.xs)
                        .foregroundStyle(Theme.Colors.text2)
                }

                if let error = vm.errorMessage {
                    Text(error)
                        .textStyle(.sm)
                        .foregroundStyle(Theme.Colors.negative)
                        .padding(.top, Theme.Space.x1)
                }

                Spacer()

                WalletButton(title: vm.isCreating
                                ? "Creating…"
                                : "Continue") {
                    vm.submit(label: defaultName, network: network, wordCount: wordCount)
                }
                .disabled(vm.isCreating)
                .opacity(vm.isCreating ? 0.6 : 1)
            }
            .padding(Theme.Space.gutter)
        }
        .navigationTitle(Text("New wallet", bundle: .module, comment: "create wallet screen title"))
    }
}
