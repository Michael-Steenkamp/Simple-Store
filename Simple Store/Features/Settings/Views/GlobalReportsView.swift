//
//  GlobalReportsView.swift
//  Simple Store
//

import SwiftUI
import SwiftData
import Charts
import UIKit

// MARK: - Models & Data Structures

/// Defines time scoping intervals for reporting queries.
public enum ReportTimeframe: String, CaseIterable, Identifiable, Sendable {
    case today = "Today"
    case thisWeek = "This Week"
    case thisMonth = "This Month"
    case thisYear = "This Year"
    case allTime = "All Time"
    case custom = "Custom Range"
    
    public var id: String { self.rawValue }
}

/// Defines presentation modes for analytical reporting.
public enum ReportDisplayMode: String, CaseIterable, Identifiable, Sendable {
    case analytics = "Analytics"
    case ledger = "Ledger"
    case itemized = "Items"
    
    public var id: String { self.rawValue }
}

/// A thread-safe criteria container for multi-variable sales filtering.
public struct ReportFilterCriteria: Equatable {
    public var timeframe: ReportTimeframe = .allTime
    public var startDate: Date = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
    public var endDate: Date = Date()
    public var selectedItemIDs: Set<String> = []
    public var selectedCustomerIDs: Set<String> = []
    public var includeWalkInCustomers: Bool = true
    public var selectedPaymentMethods: Set<String> = []
    public var searchQuery: String = ""
    
    public var isFiltered: Bool {
        timeframe != .allTime ||
        !selectedItemIDs.isEmpty ||
        !selectedCustomerIDs.isEmpty ||
        !includeWalkInCustomers ||
        !selectedPaymentMethods.isEmpty ||
        !searchQuery.trimmingCharacters(in: .whitespaces).isEmpty
    }
    
    public var activeFilterCount: Int {
        var count = 0
        if timeframe != .allTime { count += 1 }
        if !selectedItemIDs.isEmpty { count += selectedItemIDs.count }
        if !selectedCustomerIDs.isEmpty { count += selectedCustomerIDs.count }
        if !includeWalkInCustomers { count += 1 }
        if !selectedPaymentMethods.isEmpty { count += selectedPaymentMethods.count }
        if !searchQuery.trimmingCharacters(in: .whitespaces).isEmpty { count += 1 }
        return count
    }
    
    public mutating func reset() {
        timeframe = .allTime
        startDate = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
        endDate = Date()
        selectedItemIDs.removeAll()
        selectedCustomerIDs.removeAll()
        includeWalkInCustomers = true
        selectedPaymentMethods.removeAll()
        searchQuery = ""
    }
}

/// Encapsulates consolidated, single-pass aggregated reporting metrics.
public struct ReportMetrics: Sendable {
    public struct TimeSeriesPoint: Identifiable, Sendable {
        public let id = UUID()
        public let date: Date
        public let amount: Double
    }
    
    public struct ItemSalesSummary: Identifiable, Sendable {
        public var id: String { itemName }
        public let itemName: String
        public let quantitySold: Int
        public let totalRevenue: Double
        public let averagePrice: Double
    }
    
    public struct PaymentMethodSummary: Identifiable, Sendable {
        public var id: String { method }
        public let method: String
        public let totalAmount: Double
        public let transactionCount: Int
    }
    
    public let grossRevenue: Double
    public let totalUnitsSold: Int
    public let totalOrderCount: Int
    public let averageOrderValue: Double
    public let timeSeries: [TimeSeriesPoint]
    public let topItems: [ItemSalesSummary]
    public let allItemSummaries: [ItemSalesSummary]
    public let paymentSummaries: [PaymentMethodSummary]
    
    public static var empty: ReportMetrics {
        ReportMetrics(
            grossRevenue: 0,
            totalUnitsSold: 0,
            totalOrderCount: 0,
            averageOrderValue: 0,
            timeSeries: [],
            topItems: [],
            allItemSummaries: [],
            paymentSummaries: []
        )
    }
}

// MARK: - View Model

/// Orchestrates asynchronous filtering, single-pass metric calculations, and report generation.
@MainActor
@Observable
final class GlobalReportsViewModel {
    var criteria = ReportFilterCriteria()
    var displayMode: ReportDisplayMode = .analytics
    
    var isShowingFilterSheet = false
    var isExporting = false
    var exportSuccess = false
    var exportErrorMessage: String?
    
    /// Executes optimized in-memory filtering across the localized SwiftData transaction graph.
    func filterTransactions(_ transactions: [Transaction]) -> [Transaction] {
        let calendar = Calendar.current
        let now = Date()
        let query = criteria.searchQuery.trimmingCharacters(in: .whitespaces).lowercased()
        
        let hasItemFilter = !criteria.selectedItemIDs.isEmpty
        let hasCustFilter = !criteria.selectedCustomerIDs.isEmpty
        let hasPayFilter = !criteria.selectedPaymentMethods.isEmpty
        
        return transactions.filter { tx in
            // 1. Date Range Boundary Evaluation
            switch criteria.timeframe {
            case .today:
                guard calendar.isDateInToday(tx.date) else { return false }
            case .thisWeek:
                guard let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: now)?.start,
                      tx.date >= startOfWeek else { return false }
            case .thisMonth:
                guard let startOfMonth = calendar.dateInterval(of: .month, for: now)?.start,
                      tx.date >= startOfMonth else { return false }
            case .thisYear:
                guard let startOfYear = calendar.dateInterval(of: .year, for: now)?.start,
                      tx.date >= startOfYear else { return false }
            case .custom:
                let startOfDay = calendar.startOfDay(for: criteria.startDate)
                guard let endOfDay = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: criteria.endDate),
                      tx.date >= startOfDay && tx.date <= endOfDay else { return false }
            case .allTime:
                break
            }
            
            // 2. Customer Identity Filter
            if let customer = tx.customer {
                if hasCustFilter && !criteria.selectedCustomerIDs.contains(customer.id.uuidString) {
                    return false
                }
            } else if let buyerId = tx.buyerEmployeeId {
                if hasCustFilter && !criteria.selectedCustomerIDs.contains(buyerId) {
                    return false
                }
            } else {
                if !criteria.includeWalkInCustomers { return false }
            }
            
            // 3. Payment Method Match
            if hasPayFilter {
                let txMethods = Set((tx.payments ?? []).map { $0.method })
                guard !txMethods.isDisjoint(with: criteria.selectedPaymentMethods) else { return false }
            }
            
            // 4. Line Item Specific Match
            if hasItemFilter {
                let itemIds = Set((tx.lineItems ?? []).map { $0.itemID })
                guard !itemIds.isDisjoint(with: criteria.selectedItemIDs) else { return false }
            }
            
            // 5. Broad Search Query Match
            if !query.isEmpty {
                let customerName = tx.customer?.fullName.lowercased() ?? "walk-in customer"
                let employeeName = tx.employeeName?.lowercased() ?? ""
                let buyerName = tx.buyerEmployeeName?.lowercased() ?? ""
                let containsItem = tx.lineItems?.contains { $0.itemName.lowercased().contains(query) } ?? false
                let matchesId = tx.id.uuidString.lowercased().contains(query)
                
                guard customerName.contains(query) ||
                      employeeName.contains(query) ||
                      buyerName.contains(query) ||
                      containsItem ||
                      matchesId else { return false }
            }
            
            return true
        }
    }
    
    /// Computes high-performance analytics in a single unified linear pass over the filtered transaction array.
    func computeMetrics(from transactions: [Transaction]) -> ReportMetrics {
        guard !transactions.isEmpty else { return .empty }
        
        let calendar = Calendar.current
        var gross: Double = 0.0
        var totalUnits: Int = 0
        
        var timeSeriesMap: [Date: Double] = [:]
        var itemMap: [String: (quantity: Int, revenue: Double)] = [:]
        var paymentMap: [String: (amount: Double, count: Int)] = [:]
        
        let hasItemFilter = !criteria.selectedItemIDs.isEmpty
        
        for tx in transactions {
            gross += tx.totalAmount
            
            // Time Series Binning
            let dateKey: Date
            switch criteria.timeframe {
            case .today:
                dateKey = calendar.date(bySetting: .minute, value: 0, of: tx.date) ?? tx.date
            case .thisWeek, .thisMonth, .custom:
                dateKey = calendar.startOfDay(for: tx.date)
            case .thisYear, .allTime:
                let comps = calendar.dateComponents([.year, .month], from: tx.date)
                dateKey = calendar.date(from: comps) ?? tx.date
            }
            timeSeriesMap[dateKey, default: 0.0] += tx.totalAmount
            
            // Line Item Aggregation
            if let lineItems = tx.lineItems {
                for item in lineItems {
                    if hasItemFilter && !criteria.selectedItemIDs.contains(item.itemID) { continue }
                    totalUnits += item.quantity
                    let itemRevenue = Double(item.quantity) * item.pricePerUnit
                    let current = itemMap[item.itemName] ?? (quantity: 0, revenue: 0.0)
                    itemMap[item.itemName] = (
                        quantity: current.quantity + item.quantity,
                        revenue: current.revenue + itemRevenue
                    )
                }
            }
            
            // Payment Method Breakdown
            if let payments = tx.payments {
                for payment in payments {
                    let current = paymentMap[payment.method] ?? (amount: 0.0, count: 0)
                    paymentMap[payment.method] = (
                        amount: current.amount + payment.amount,
                        count: current.count + 1
                    )
                }
            }
        }
        
        let seriesPoints = timeSeriesMap.map {
            ReportMetrics.TimeSeriesPoint(date: $0.key, amount: $0.value)
        }.sorted { $0.date < $1.date }
        
        let allItems = itemMap.map { name, stats in
            ReportMetrics.ItemSalesSummary(
                itemName: name,
                quantitySold: stats.quantity,
                totalRevenue: stats.revenue,
                averagePrice: stats.quantity > 0 ? stats.revenue / Double(stats.quantity) : 0.0
            )
        }.sorted { $0.totalRevenue > $1.totalRevenue }
        
        let paymentSummaries = paymentMap.map { method, stats in
            ReportMetrics.PaymentMethodSummary(
                method: method,
                totalAmount: stats.amount,
                transactionCount: stats.count
            )
        }.sorted { $0.totalAmount > $1.totalAmount }
        
        return ReportMetrics(
            grossRevenue: gross,
            totalUnitsSold: totalUnits,
            totalOrderCount: transactions.count,
            averageOrderValue: transactions.isEmpty ? 0.0 : gross / Double(transactions.count),
            timeSeries: seriesPoints,
            topItems: Array(allItems.prefix(5)),
            allItemSummaries: allItems,
            paymentSummaries: paymentSummaries
        )
    }
    
    func chartUnit() -> Calendar.Component {
        switch criteria.timeframe {
        case .today: return .hour
        case .thisWeek, .thisMonth, .custom: return .day
        case .thisYear, .allTime: return .month
        }
    }
    
    func xAxisFormat() -> Date.FormatStyle {
        switch criteria.timeframe {
        case .today: return .dateTime.hour()
        case .thisWeek: return .dateTime.weekday(.abbreviated)
        case .thisMonth, .custom: return .dateTime.month(.abbreviated).day()
        case .thisYear, .allTime: return .dateTime.month(.abbreviated).year()
        }
    }
    
    /// Dispatches asynchronous CSV generation and triggers native system distribution sheets.
    func exportData(transactions: [Transaction]) async {
        guard !transactions.isEmpty else { return }
        isExporting = true
        exportErrorMessage = nil
        
        defer { isExporting = false }
        
        do {
            let label = criteria.timeframe == .custom
                ? "Custom (\(criteria.startDate.formatted(date: .numeric, time: .omitted)) - \(criteria.endDate.formatted(date: .numeric, time: .omitted)))"
                : criteria.timeframe.rawValue
            
            let url = try await CSVEngine.generate(from: transactions, timeframeLabel: label)
            exportSuccess.toggle()
            presentShareSheet(for: url)
        } catch {
            exportErrorMessage = error.localizedDescription
        }
    }
    
    private func presentShareSheet(for url: URL) {
        let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        
        if let windowScene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
           let window = windowScene.windows.first(where: \.isKeyWindow),
           let rootVC = window.rootViewController {
            
            activityVC.popoverPresentationController?.sourceView = window
            activityVC.popoverPresentationController?.sourceRect = CGRect(x: window.bounds.midX, y: window.bounds.midY, width: 0, height: 0)
            rootVC.present(activityVC, animated: true)
        }
    }
}

// MARK: - Primary View

/// The administrative reporting dashboard featuring multi-variable filtering, real-time analytics, and data exfiltration.
struct GlobalReportsView: View {
    @Query(sort: \Transaction.date, order: .reverse) private var allTransactions: [Transaction]
    @Query(sort: \StoreItem.name) private var allItems: [StoreItem]
    @Query(sort: \Customer.lastName) private var allCustomers: [Customer]
    @Query(sort: \Employee.name) private var allEmployees: [Employee]
    
    @State private var viewModel = GlobalReportsViewModel()
    
    var body: some View {
        let filteredTransactions = viewModel.filterTransactions(allTransactions)
        let metrics = viewModel.computeMetrics(from: filteredTransactions)
        
        VStack(spacing: 0) {
            topControlBar(filteredCount: filteredTransactions.count)
            
            Group {
                switch viewModel.displayMode {
                case .analytics:
                    analyticsOverview(metrics: metrics, filteredTransactions: filteredTransactions)
                case .ledger:
                    transactionLedger(transactions: filteredTransactions)
                case .itemized:
                    itemizedSalesBreakdown(items: metrics.allItemSummaries)
                }
            }
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("Global Reports")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                HStack(spacing: 12) {
                    Button {
                        viewModel.isShowingFilterSheet = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: viewModel.criteria.isFiltered ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                            if viewModel.criteria.activeFilterCount > 0 {
                                Text("\(viewModel.criteria.activeFilterCount)")
                                    .font(.caption2.weight(.bold))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.accentColor)
                                    .foregroundStyle(.white)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                    
                    Button {
                        Task { await viewModel.exportData(transactions: filteredTransactions) }
                    } label: {
                        ZStack {
                            if viewModel.isExporting {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Image(systemName: "square.and.arrow.up")
                            }
                        }
                        .frame(width: 24, height: 24)
                    }
                    .disabled(filteredTransactions.isEmpty || viewModel.isExporting)
                }
            }
        }
        .sheet(isPresented: $viewModel.isShowingFilterSheet) {
            ReportFilterSheet(
                criteria: $viewModel.criteria,
                allItems: allItems,
                allCustomers: allCustomers,
                allEmployees: allEmployees,
                allTransactions: allTransactions
            )
        }
        .sensoryFeedback(.success, trigger: viewModel.exportSuccess)
        .sensoryFeedback(.selection, trigger: viewModel.displayMode)
    }
    
    // MARK: - Subviews & Controls
    
    private func topControlBar(filteredCount: Int) -> some View {
        VStack(spacing: 12) {
            Picker("Display Mode", selection: $viewModel.displayMode.animation(.snappy)) {
                ForEach(ReportDisplayMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(ReportTimeframe.allCases) { tf in
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                viewModel.criteria.timeframe = tf
                            }
                        } label: {
                            Text(tf.rawValue)
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 6)
                                .background(viewModel.criteria.timeframe == tf ? Color.accentColor : Color(uiColor: .secondarySystemBackground))
                                .foregroundStyle(viewModel.criteria.timeframe == tf ? .white : .primary)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
            }
            
            if viewModel.criteria.isFiltered {
                HStack {
                    Text("\(filteredCount) transactions matched")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Spacer()
                    
                    Button("Clear Filters") {
                        withAnimation { viewModel.criteria.reset() }
                    }
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.red)
                }
                .padding(.horizontal)
                .padding(.bottom, 4)
            }
        }
        .padding(.vertical, 8)
        .background(Color(uiColor: .systemBackground))
        .overlay(Divider(), alignment: .bottom)
    }
    
    private func analyticsOverview(metrics: ReportMetrics, filteredTransactions: [Transaction]) -> some View {
        ScrollView {
            VStack(spacing: 20) {
                kpiGrid(metrics: metrics)
                    .padding(.horizontal)
                    .padding(.top, 12)
                
                revenueChartSection(metrics: metrics)
                    .padding(.horizontal)
                
                if !metrics.paymentSummaries.isEmpty {
                    paymentBreakdownSection(summaries: metrics.paymentSummaries)
                        .padding(.horizontal)
                }
                
                topItemsSection(topItems: metrics.topItems)
                    .padding(.horizontal)
            }
            .padding(.bottom, 40)
        }
    }
    
    private func kpiGrid(metrics: ReportMetrics) -> some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                KPICard(
                    title: "Gross Revenue",
                    value: metrics.grossRevenue.formatted(.currency(code: "CAD")),
                    icon: "dollarsign.circle.fill",
                    color: .green
                )
                KPICard(
                    title: "Units Sold",
                    value: "\(metrics.totalUnitsSold)",
                    icon: "shippingbox.fill",
                    color: .blue
                )
            }
            
            HStack(spacing: 12) {
                KPICard(
                    title: "Total Orders",
                    value: "\(metrics.totalOrderCount)",
                    icon: "receipt.fill",
                    color: .orange
                )
                KPICard(
                    title: "Avg. Order Value",
                    value: metrics.averageOrderValue.formatted(.currency(code: "CAD")),
                    icon: "chart.line.uptrend.xyaxis.circle.fill",
                    color: .purple
                )
            }
        }
    }
    
    private func revenueChartSection(metrics: ReportMetrics) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Revenue Trend")
                .font(.headline)
                .foregroundStyle(.primary)
            
            if metrics.timeSeries.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "chart.bar.xaxis")
                        .font(.largeTitle)
                        .foregroundStyle(.tertiary)
                    Text("No revenue recorded in this period.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 180)
            } else {
                Chart {
                    ForEach(metrics.timeSeries) { point in
                        BarMark(
                            x: .value("Date", point.date, unit: viewModel.chartUnit()),
                            y: .value("Revenue", point.amount)
                        )
                        .foregroundStyle(Color.accentColor.gradient)
                        .cornerRadius(4)
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: viewModel.chartUnit())) { _ in
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel(format: viewModel.xAxisFormat())
                    }
                }
                .chartYAxis {
                    AxisMarks { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let doubleValue = value.as(Double.self) {
                                Text("$\(Int(doubleValue))")
                                    .font(.caption2)
                            }
                        }
                    }
                }
                .frame(height: 200)
            }
        }
        .padding(16)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
    
    private func paymentBreakdownSection(summaries: [ReportMetrics.PaymentMethodSummary]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Payment Method Distribution")
                .font(.headline)
                .foregroundStyle(.primary)
            
            VStack(spacing: 8) {
                ForEach(summaries) { summary in
                    HStack {
                        Text(summary.method.capitalized)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Spacer()
                        
                        Text("\(summary.transactionCount) txs")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        Text(summary.totalAmount.formatted(.currency(code: "CAD")))
                            .font(.subheadline.weight(.bold))
                    }
                    .padding(.vertical, 4)
                    
                    if summary.id != summaries.last?.id {
                        Divider()
                    }
                }
            }
        }
        .padding(16)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
    
    private func topItemsSection(topItems: [ReportMetrics.ItemSalesSummary]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Top Performing Items")
                .font(.headline)
                .foregroundStyle(.primary)
            
            if topItems.isEmpty {
                Text("No item sales data for this period.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 16)
            } else {
                VStack(spacing: 10) {
                    ForEach(Array(topItems.enumerated()), id: \.element.id) { index, item in
                        HStack(spacing: 12) {
                            Text("\(index + 1)")
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(.secondary)
                                .frame(width: 20, alignment: .leading)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.itemName)
                                    .font(.subheadline.weight(.semibold))
                                    .lineLimit(1)
                                Text("\(item.quantitySold) units sold")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            
                            Spacer()
                            
                            Text(item.totalRevenue.formatted(.currency(code: "CAD")))
                                .font(.subheadline.weight(.bold))
                        }
                        
                        if index < topItems.count - 1 {
                            Divider()
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
    
    private func transactionLedger(transactions: [Transaction]) -> some View {
        List {
            if transactions.isEmpty {
                ContentUnavailableView(
                    "No Matching Orders",
                    systemImage: "doc.text.magnifyingglass",
                    description: Text("Adjust your filters to inspect transactions.")
                )
                .listRowBackground(Color.clear)
            } else {
                ForEach(transactions) { tx in
                    NavigationLink(destination: TransactionDetailView(transaction: tx)) {
                        ledgerRow(for: tx)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }
    
    private func ledgerRow(for tx: Transaction) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(tx.date.formatted(date: .abbreviated, time: .shortened))
                    .font(.subheadline.weight(.bold))
                Spacer()
                Text(tx.totalAmount, format: .currency(code: "CAD"))
                    .font(.headline)
            }
            
            HStack {
                if let customer = tx.customer {
                    Label(customer.fullName, systemImage: "person.fill")
                        .font(.caption)
                        .foregroundStyle(.blue)
                } else if let buyer = tx.buyerEmployeeName {
                    Label(buyer, systemImage: "person.badge.shield.checkmark.fill")
                        .font(.caption)
                        .foregroundStyle(.purple)
                } else {
                    Label("Walk-in", systemImage: "person.crop.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                let itemCount = tx.lineItems?.reduce(0) { $0 + $1.quantity } ?? 0
                Text("\(itemCount) items")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
    
    private func itemizedSalesBreakdown(items: [ReportMetrics.ItemSalesSummary]) -> some View {
        List {
            if items.isEmpty {
                ContentUnavailableView(
                    "No Items Sold",
                    systemImage: "shippingbox",
                    description: Text("No item breakdown available for the current filter.")
                )
                .listRowBackground(Color.clear)
            } else {
                ForEach(items) { item in
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.itemName)
                                .font(.headline)
                            HStack(spacing: 8) {
                                Text("\(item.quantitySold) units")
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(.secondary)
                                Text("•")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                                Text("Avg: \(item.averagePrice.formatted(.currency(code: "CAD")))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        
                        Spacer()
                        
                        Text(item.totalRevenue.formatted(.currency(code: "CAD")))
                            .font(.headline.weight(.bold))
                            .foregroundStyle(Color.accentColor)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .listStyle(.insetGrouped)
    }
}

// MARK: - Precision Filter Sheet

/// A granular administrative filtering panel for item, customer, employee, payment, and date scoping.
struct ReportFilterSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var criteria: ReportFilterCriteria
    
    let allItems: [StoreItem]
    let allCustomers: [Customer]
    let allEmployees: [Employee]
    let allTransactions: [Transaction]
    
    @State private var itemSearch = ""
    @State private var customerSearch = ""
    
    var availablePaymentMethods: [String] {
        let set = Set(allTransactions.flatMap { $0.payments ?? [] }.map { $0.method })
        return Array(set).sorted()
    }
    
    var filteredItems: [StoreItem] {
        if itemSearch.isEmpty { return allItems }
        return allItems.filter { $0.name.localizedCaseInsensitiveContains(itemSearch) }
    }
    
    var filteredCustomers: [Customer] {
        let active = allCustomers.filter { $0.isActive }
        if customerSearch.isEmpty { return active }
        return active.filter { $0.fullName.localizedCaseInsensitiveContains(customerSearch) }
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Timeframe & Scope")) {
                    Picker("Period", selection: $criteria.timeframe) {
                        ForEach(ReportTimeframe.allCases) { tf in
                            Text(tf.rawValue).tag(tf)
                        }
                    }
                    
                    if criteria.timeframe == .custom {
                        DatePicker("Start Date", selection: $criteria.startDate, displayedComponents: .date)
                        DatePicker("End Date", selection: $criteria.endDate, displayedComponents: .date)
                    }
                }
                
                Section(header: Text("Search Filter")) {
                    TextField("Customer, staff, item, or ID...", text: $criteria.searchQuery)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }
                
                Section(header: Text("Payment Methods")) {
                    if availablePaymentMethods.isEmpty {
                        Text("No recorded payment methods.")
                            .foregroundStyle(.secondary)
                            .italic()
                    } else {
                        ForEach(availablePaymentMethods, id: \.self) { method in
                            let isSelected = criteria.selectedPaymentMethods.contains(method)
                            Button {
                                if isSelected {
                                    criteria.selectedPaymentMethods.remove(method)
                                } else {
                                    criteria.selectedPaymentMethods.insert(method)
                                }
                            } label: {
                                HStack {
                                    Text(method.capitalized)
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    if isSelected {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(Color.accentColor)
                                            .fontWeight(.bold)
                                    }
                                }
                            }
                        }
                    }
                }
                
                Section(header: Text("Filter By Items (\(criteria.selectedItemIDs.count) selected)")) {
                    TextField("Search items...", text: $itemSearch)
                    
                    HStack {
                        Button("Select All") {
                            criteria.selectedItemIDs = Set(allItems.map { $0.id.uuidString })
                        }
                        .font(.caption.weight(.bold))
                        
                        Spacer()
                        
                        Button("Clear Selection") {
                            criteria.selectedItemIDs.removeAll()
                        }
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)
                    
                    ForEach(filteredItems.prefix(20)) { item in
                        let id = item.id.uuidString
                        let isSelected = criteria.selectedItemIDs.contains(id)
                        Button {
                            if isSelected {
                                criteria.selectedItemIDs.remove(id)
                            } else {
                                criteria.selectedItemIDs.insert(id)
                            }
                        } label: {
                            HStack {
                                Text(item.name)
                                    .foregroundStyle(.primary)
                                Spacer()
                                if isSelected {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(Color.accentColor)
                                }
                            }
                        }
                    }
                }
                
                Section(header: Text("Filter By Customer (\(criteria.selectedCustomerIDs.count) selected)")) {
                    Toggle("Include Walk-in Sales", isOn: $criteria.includeWalkInCustomers)
                    
                    TextField("Search customers...", text: $customerSearch)
                    
                    if !criteria.selectedCustomerIDs.isEmpty {
                        Button("Clear Selected Customers") {
                            criteria.selectedCustomerIDs.removeAll()
                        }
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.red)
                        .buttonStyle(.plain)
                    }
                    
                    ForEach(filteredCustomers.prefix(20)) { cust in
                        let id = cust.id.uuidString
                        let isSelected = criteria.selectedCustomerIDs.contains(id)
                        Button {
                            if isSelected {
                                criteria.selectedCustomerIDs.remove(id)
                            } else {
                                criteria.selectedCustomerIDs.insert(id)
                            }
                        } label: {
                            HStack {
                                Text(cust.fullName)
                                    .foregroundStyle(.primary)
                                Spacer()
                                if isSelected {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(Color.accentColor)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Precision Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Reset") {
                        criteria.reset()
                    }
                    .foregroundStyle(.red)
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.bold)
                }
            }
        }
    }
}

// MARK: - Component View

/// A modular tile for displaying top-line metrics and performance indicators.
struct KPICard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                    .font(.title3)
                Spacer()
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(value)
                    .font(.title2)
                    .fontWeight(.bold)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fontWeight(.medium)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
