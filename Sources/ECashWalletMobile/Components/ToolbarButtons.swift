// Copyright (C) 2026 LayerTwo Labs and contributors
// Licensed under the GNU General Public License v2.0 or later
// SPDX-License-Identifier: GPL-2.0-or-later

import SwiftUI

/// System dismiss/confirm toolbar buttons used across every sheet and full-screen flow, so the
/// chrome is consistent app-wide: a close glyph (X) to dismiss without committing, a checkmark to
/// acknowledge/finish — never spelled-out "Cancel"/"Done".
///
/// iOS 26 renders the standard system buttons via the `.close` / `.confirm` button roles (the
/// project's iOS floor is 26). Android has no such roles, so it falls back to the Material
/// `close` / `check` `.symbolset` glyphs (skip-icons rule — never SF Symbols). Drop these inside
/// a `ToolbarItem { ... }`.

/// Dismiss-without-committing (replaces a "Cancel" button).
struct CloseToolbarButton: View {
    let action: () -> Void
    var body: some View {
        #if os(iOS)
        Button(role: .close, action: action)
        #else
        Button(action: action) { Image(icon: Icon.close) }
        #endif
    }
}

/// Acknowledge / finish (replaces a "Done" button).
struct ConfirmToolbarButton: View {
    let action: () -> Void
    var body: some View {
        #if os(iOS)
        Button(role: .confirm, action: action)
        #else
        Button(action: action) { Image(icon: Icon.check) }
        #endif
    }
}
