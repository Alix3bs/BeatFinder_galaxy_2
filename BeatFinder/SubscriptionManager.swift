import Foundation
import Combine
import StoreKit

@MainActor
final class SubscriptionManager: ObservableObject {
    enum ProductsLoadState: Equatable {
        case idle
        case loading
        case loaded
        case failed(String)
    }

    private enum ProductsLoadError: Error {
        case timedOut
    }

    @Published var products: [Product] = []
    @Published var isPro: Bool = false
    @Published var statusText: String = ""
    @Published private(set) var productsLoadState: ProductsLoadState = .idle
    @Published private(set) var isRestoring = false
    @Published private(set) var activePurchaseProductID: String?

    // Must match StoreKit configuration + App Store Connect later.
    private let productIds = [
        "com.beatfinder.pro.monthly",
        "com.beatfinder.pro.yearly"
    ]

    private var updatesTask: Task<Void, Never>?

    init() {
        updatesTask = observeTransactionUpdates()
        Task { await refreshEntitlements() }
    }

    deinit {
        updatesTask?.cancel()
    }

    func loadProducts(force: Bool = false) async {
        if case .loading = productsLoadState {
            return
        }

        if !force, !products.isEmpty {
            productsLoadState = .loaded
            await refreshEntitlements()
            return
        }

        productsLoadState = .loading
        statusText = ""

        do {
            let fetchedProducts = try await loadProductsWithTimeout(seconds: 12)
            products = fetchedProducts.sorted(by: { $0.price < $1.price })
            await refreshEntitlements()

            if products.isEmpty {
                productsLoadState = .failed("No subscription plans are available right now.")
            } else {
                productsLoadState = .loaded
            }
        } catch {
            products = []
            if let loadError = error as? ProductsLoadError, loadError == .timedOut {
                productsLoadState = .failed("Subscription details timed out. Please try again.")
                statusText = "Timed out while loading plans."
            } else {
                productsLoadState = .failed("Could not load subscriptions. Check your connection and try again.")
                statusText = "Failed to load products: \(error.localizedDescription)"
            }
        }
    }

    func buy(_ product: Product) async {
        activePurchaseProductID = product.id
        statusText = ""

        defer {
            activePurchaseProductID = nil
        }

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await transaction.finish()
                await refreshEntitlements()
                statusText = isPro ? "Purchase successful. BeatFinder Pro is active." : "Purchase successful."
            case .userCancelled:
                statusText = "Purchase cancelled."
            case .pending:
                statusText = "Purchase pending approval."
            @unknown default:
                statusText = "Purchase failed."
            }
        } catch {
            statusText = "Purchase error: \(error.localizedDescription)"
        }
    }

    func restore() async {
        isRestoring = true
        statusText = ""

        defer {
            isRestoring = false
        }

        do {
            try await AppStore.sync()
            await refreshEntitlements()
            statusText = isPro
                ? "Purchases restored. BeatFinder Pro is active."
                : "No active subscriptions found to restore."
        } catch {
            statusText = "Restore failed: \(error.localizedDescription)"
        }
    }

    func refreshEntitlements() async {
        var pro = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               productIds.contains(transaction.productID) {
                pro = true
            }
        }
        isPro = pro
    }

    private func observeTransactionUpdates() -> Task<Void, Never> {
        Task(priority: .background) { [weak self] in
            guard let self else { return }
            for await result in Transaction.updates {
                do {
                    let transaction = try self.checkVerified(result)
                    await transaction.finish()
                    await self.refreshEntitlements()
                } catch {
                    self.statusText = "Transaction verification failed."
                }
            }
        }
    }

    private func loadProductsWithTimeout(seconds: TimeInterval) async throws -> [Product] {
        let ids = productIds
        let timeoutNanoseconds = UInt64(seconds * 1_000_000_000)

        return try await withThrowingTaskGroup(of: [Product].self) { group in
            group.addTask {
                try await Product.products(for: ids)
            }

            group.addTask {
                try await Task.sleep(nanoseconds: timeoutNanoseconds)
                throw ProductsLoadError.timedOut
            }

            guard let firstFinished = try await group.next() else {
                throw ProductsLoadError.timedOut
            }

            group.cancelAll()
            return firstFinished
        }
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error):
            throw error
        case .verified(let safe):
            return safe
        }
    }
}
