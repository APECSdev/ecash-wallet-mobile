// Copyright (C) 2026 LayerTwo Labs and contributors
// Licensed under the GNU General Public License v2.0 or later
// SPDX-License-Identifier: GPL-2.0-or-later

import Foundation
import Observation
import SkipFuse
import WalletService

/// Drives the story **detail** page (CoinNews): loads the comment thread, casts an up/down vote, and
/// posts a comment. Votes + comments are signed on-chain `OP_RETURN`s (via `WalletManager`), so each
/// is broadcast + indexed (~10 min) — hence the optimistic local copies (comments shown immediately,
/// your vote highlighted from the persistent ledger) reconciled by `PendingCoinNewsStore`.
@MainActor
@Observable
final class CoinNewsDetailViewModel {
    enum State: Equatable {
        case idle, loading, loaded, failed(String)
    }

    /// The story. Starts as the feed snapshot (stale points/commentCount), refreshed via `GetItem`
    /// on load so the vote score + comment count reflect the indexer.
    private(set) var item: CoinNewsItem
    let network: WalletNetwork
    let unitLabel: String

    private(set) var state: State = .idle
    private(set) var comments: [CoinNewsComment] = []
    private(set) var pendingCommentIds: Set<String> = []
    /// Your vote on this story (nil = haven't voted). Immutable once set (first-wins on-chain).
    private(set) var myVote: VoteDirection?
    private(set) var isVoting = false
    private(set) var isPosting = false
    private(set) var actionError: String?
    var commentText: String = ""

    private let fetchItem: (String) async throws -> CoinNewsItem?
    private let fetchThread: (String) async throws -> [CoinNewsComment]
    private let vote: (_ targetIdHex: String, _ up: Bool) async throws -> WalletTx
    private let comment: (_ parentIdHex: String, _ body: String) async throws -> WalletTx
    private let pending: PendingCoinNewsStore
    private let authorize: (String) async -> Bool

    init(item: CoinNewsItem,
         network: WalletNetwork,
         unitLabel: String,
         fetchItem: @escaping (String) async throws -> CoinNewsItem?,
         fetchThread: @escaping (String) async throws -> [CoinNewsComment],
         vote: @escaping (_ targetIdHex: String, _ up: Bool) async throws -> WalletTx,
         comment: @escaping (_ parentIdHex: String, _ body: String) async throws -> WalletTx,
         pending: PendingCoinNewsStore,
         authorize: @escaping (String) async -> Bool = { _ in true }) {
        self.item = item
        self.network = network
        self.unitLabel = unitLabel
        self.fetchItem = fetchItem
        self.fetchThread = fetchThread
        self.vote = vote
        self.comment = comment
        self.pending = pending
        self.authorize = authorize
        self.myVote = pending.myVote(targetId: item.id, on: network)
    }

    func isPendingComment(_ id: String) -> Bool { pendingCommentIds.contains(id) }
    // Allow re-casting: the on-chain rule is first-wins (a duplicate just costs a fee and is ignored
    // by the indexer), so we don't hard-lock on the optimistic broadcast — important while the
    // indexer's points aggregate may not reflect a vote. The ▲/▼ highlight still shows your choice.
    var canVote: Bool { !isVoting }

    func load() async {
        if case .loaded = state { return }
        await reload()
    }

    func reload() async {
        state = .loading
        do {
            // Refresh the story itself (GetItem) so points + commentCount reflect the indexer, not
            // the stale feed snapshot. Best-effort — keep the snapshot if it can't be re-fetched.
            if let fresh = try? await fetchItem(item.id) { item = fresh }
            let fetched = try await fetchThread(item.id)
            pending.reconcileComments(fetched: fetched, on: network)
            // Show our optimistic comments that belong to this thread (reply to the story or to a
            // fetched comment), on top.
            let fetchedIds = Set(fetched.map { $0.id })
            let pend = pending.comments(on: network).filter {
                $0.parentHex == item.id || fetchedIds.contains($0.parentHex)
            }
            comments = pend + fetched
            pendingCommentIds = Set(pend.map { $0.id })
            myVote = pending.myVote(targetId: item.id, on: network)
            state = .loaded
        } catch {
            state = .failed("Couldn't load the thread. Pull to retry.")
        }
    }

    func upvote() async { await castVote(.up) }
    func downvote() async { await castVote(.down) }

    private func castVote(_ dir: VoteDirection) async {
        guard canVote else { return }   // first-wins: one vote per item, no changes
        actionError = nil
        guard await authorize("Authorize this vote") else { return }
        isVoting = true
        do {
            _ = try await vote(item.id, dir == .up)
            pending.setVote(targetId: item.id, dir, on: network)
            myVote = dir
        } catch let error as WalletError {
            actionError = error.userMessage
        } catch {
            actionError = "Couldn't submit your vote. Please try again."
        }
        isVoting = false
    }

    func postComment() async {
        let body = commentText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !body.isEmpty, !isPosting else { return }
        actionError = nil
        guard await authorize("Authorize this comment") else { return }
        isPosting = true
        do {
            let tx = try await comment(item.id, body)
            // Optimistic copy (local id by txid), reconciled by content when the indexer returns it.
            let local = CoinNewsComment(id: "pending:\(tx.txid)", parentHex: item.id, body: body)
            pending.addComment(local, on: network)
            comments.insert(local, at: 0)
            pendingCommentIds.insert(local.id)
            commentText = ""
        } catch let error as WalletError {
            actionError = error.userMessage
        } catch {
            actionError = "Couldn't post your comment. Please try again."
        }
        isPosting = false
    }
}
