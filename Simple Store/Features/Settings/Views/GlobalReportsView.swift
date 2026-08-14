//
//  GlobalReportsView.swift
//  Simple Store
//

import SwiftUI
import SwiftData
import Charts

// MARK: - View Model

@MainActor
@Observable
final class GlobalReportsViewModel {
    enum Timeframe: String, CaseIterable, Identifiable {
        case today = "Today"
        case thisWeek = "This Week"
        case thisMonth = "This Month"
        case allTime = "All Time"
        var id: String { self.rawValue }
    }
    
    struct RevenueData: Identifiable {
        let id = UUID()
        let date: Date
        let amount: Double
    }
    
    var selectedTimeframe: Timeframe = .allTime
    var isExporting = false
    var exportSuccess = false
    
    var isShowingCustomExport = false
    var customStartDate = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
    var customEndDate = Date()
    
    func filteredTransactions(from allTransactions: [Transaction]) -> [Transaction] {
        let calendar = Calendar.current
        let now = Date()
        
        return allTransactions.filter { transaction in
            switch selectedTimeframe {
            case .today:
                return calendar.isDateInToday(transaction.date)
            case .thisWeek:
                guard let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: now)?.start else { return true }
                return transaction.date >= startOfWeek
            case .thisMonth:
                guard let startOfMonth = calendar.dateInterval(of: .month, for: now)?.start else { return true }
                return transaction.date >= startOfMonth
            case .allTime:
                return true
            }
        }
    }
    
    func totalRevenue(for transactions: [Transaction]) -> Double {
        transactions.reduce(0) { $0 + $1.totalAmount }
    }
    
    func totalUnitsSold(for transactions: [Transaction]) -> Int {
        transactions.reduce(0) { sum, transaction in
            let itemsQty = transaction.lineItems?.reduce(0) { $0 + $1.quantity } ?? 0
            return sum + itemsQty
        }
    }
    
    func averageOrderValue(for transactions: [Transaction]) -> Double {
        guard !transactions.isEmpty else { return 0.0 }
        return totalRevenue(for: transactions) / Double(transactions.count)
    }
    
    func revenueTimeSeries(for transactions: [Transaction]) -> [RevenueData] {
        let calendar = Calendar.current
        var grouped: [Date: Double] = [:]
        
        for tx in transactions {
            let dateKey: Date
            switch selectedTimeframe {
            case .today:
                dateKey = calendar.date(bySetting: .minute, value: 0, of: tx.date) ?? tx.date
            case .thisWeek, .thisMonth:
                dateKey = calendar.startOfDay(for: tx.date)
            case .allTime:
                let comps = calendar.dateComponents([.year, .month], from: tx.date)
                dateKey = calendar.date(from: comps) ?? tx.date
            }
            grouped[dateKey, default: 0] += tx.totalAmount
        }
        
        return grouped.map { RevenueData(date: $0.key, amount: $0.value) }
            .sorted { $0.date < $1.date }
    }
    
    func chartUnit() -> Calendar.Component {
        switch selectedTimeframe {
        case .today: return .hour
        case .thisWeek, .thisMonth: return .day
        case .allTime: return .month
        }
    }
    
    func xAxisFormat() -> Date.FormatStyle {
        switch selectedTimeframe {
        case .today: return .dateTime.hour()
        case .thisWeek: return .dateTime.weekday(.abbreviated)
        case .thisMonth: return .dateTime.day()
        case .allTime: return .dateTime.month(.abbreviated).year()
        }
    }
    
    func topSellingItems(for transactions: [Transaction]) -> [(name: String, quantity: Int, revenue: Double)] {
        var itemStats: [String: (quantity: Int, revenue: Double)] = [:]
        
        for transaction in transactions {
            if let items = transaction.lineItems {
                for lineItem in items {
                    let current = itemStats[lineItem.itemName] ?? (quantity: 0, revenue: 0.0)
                    itemStats[lineItem.itemName] = (
                        quantity: current.quantity + lineItem.quantity,
                        revenue: current.revenue + (Double(lineItem.quantity) * lineItem.pricePerUnit)
                    )
                }
            }
        }
        
        return itemStats.map { (name: $0.key, quantity: $0.value.quantity, revenue: $0.value.revenue) }
            .sorted { $0.revenue > $1.revenue }
            .prefix(5)
            .map { $0 }
    }
    
    func exportData(transactions: [Transaction], label: String) async {
        guard !transactions.isEmpty else { return }
        isExporting = true
        
        do {
            let url = try await CSVEngine.generate(from: transactions, timeframeLabel: label)
            isExporting = false
            exportSuccess.toggle()
            presentShareSheet(for: url)
        } catch {
            isExporting = false
            print("Error generating CSV: \(error)")
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

// MARK: - View

struct GlobalReportsView: View {
    @Query(sort: \Transaction.date, order: .reverse) private var allTransactions: [Transaction]
    @State private var viewModel = GlobalReportsViewModel()
    
    var body: some View {
        let filteredTx = viewModel.filteredTransactions(from: allTransactions)
        
        ScrollView {
            VStack(spacing: 24) {
                Picker("Timeframe", selection: $viewModel.selectedTimeframe.animation(.easeInOut)) {
                    ForEach(GlobalReportsViewModel.Timeframe.allCases) { timeframe in
                        Text(timeframe.rawValue).tag(timeframe)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.top, 10)
                
                VStack(spacing: 16) {
                    HStack(spacing: 16) {
                        KPICard(title: "Gross Revenue", value: viewModel.totalRevenue(for: filteredTx).formatted(.currency(code: "CAD")), icon: "dollarsign.circle.fill", color: .green)
                        KPICard(title: "Units Sold", value: "\(viewModel.totalUnitsSold(for: filteredTx))", icon: "shippingbox.fill", color: .blue)
                    }
                    
                    HStack(spacing: 16) {
                        KPICard(title: "Total Orders", value: "\(filteredTx.count)", icon: "receipt.fill", color: .orange)
                        KPICard(title: "Avg. Order Value", value: viewModel.averageOrderValue(for: filteredTx).formatted(.currency(code: "CAD")), icon: "chart.line.uptrend.xyaxis.circle.fill", color: .purple)
                    }
                }
                .padding(.horizontal)
                
                Divider().padding(.vertical, 8)
                
                VStack(alignment: .leading, spacing: 16) {
                    Text("Revenue Trend")
                        .font(.title3)
                        .fontWeight(.bold)
                        .padding(.horizontal)
                    
                    let chartData = viewModel.revenueTimeSeries(for: filteredTx)
                    if chartData.isEmpty {
                        Text("No sales data available to chart.")
                            .foregroundStyle(.secondary)
                            .italic()
                            .padding(.horizontal)
                            .frame(height: 180)
                    } else {
                        Chart {
                            ForEach(chartData) { data in
                                BarMark(
                                    x: .value("Date", data.date, unit: viewModel.chartUnit()),
                                    y: .value("Revenue", data.amount)
                                )
                                .foregroundStyle(Color.green.gradient)
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
                        .frame(height: 200)
                        .padding(.horizontal)
                    }
                }
                
                Divider().padding(.vertical, 8)
                
                VStack(alignment: .leading, spacing: 16) {
                    Text("Top Performing Items")
                        .font(.title3)
                        .fontWeight(.bold)
                        .padding(.horizontal)
                    
                    let topItems = viewModel.topSellingItems(for: filteredTx)
                    if topItems.isEmpty {
                        Text("No item data for this period.")
                            .foregroundStyle(.secondary)
                            .italic()
                            .padding(.horizontal)
                    } else {
                        VStack(spacing: 12) {
                            ForEach(Array(topItems.enumerated()), id: \.element.name) { index, item in
                                HStack {
                                    Text("\(index + 1)")
                                        .font(.headline)
                                        .foregroundStyle(.secondary)
                                        .frame(width: 24, alignment: .leading)
                                    VStack(alignment: .leading) {
                                        Text(item.name).fontWeight(.semibold)
                                        Text("\(item.quantity) units sold").font(.caption).foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Text(item.revenue.formatted(.currency(code: "CAD"))).fontWeight(.bold)
                                }
                                .padding()
                                .background(Color(uiColor: .secondarySystemBackground))
                                .cornerRadius(12)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
            .padding(.bottom, 40)
        }
        .animation(.default, value: filteredTx.count)
        .navigationTitle("Global Sales")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    if viewModel.selectedTimeframe == .allTime {
                        viewModel.isShowingCustomExport = true
                    } else {
                        Task { await viewModel.exportData(transactions: filteredTx, label: viewModel.selectedTimeframe.rawValue) }
                    }
                } label: {
                    ZStack {
                        if viewModel.isExporting {
                            ProgressView()
                        } else {
                            Image(systemName: "square.and.arrow.up")
                        }
                    }
                    .frame(width: 25, height: 25, alignment: .center)
                }
                .disabled(filteredTx.isEmpty || viewModel.isExporting)
            }
        }
        .sensoryFeedback(.success, trigger: viewModel.exportSuccess)
        .sheet(isPresented: $viewModel.isShowingCustomExport) {
            NavigationStack {
                Form {
                    Section(header: Text("Select Date Range")) {
                        DatePicker("Start Date", selection: $viewModel.customStartDate, displayedComponents: .date)
                        DatePicker("End Date", selection: $viewModel.customEndDate, displayedComponents: .date)
                    }
                    
                    Section {
                        Button {
                            let customTransactions = allTransactions.filter {
                                $0.date >= viewModel.customStartDate && $0.date <= viewModel.customEndDate
                            }
                            viewModel.isShowingCustomExport = false
                            Task { await viewModel.exportData(transactions: customTransactions, label: "Custom Range") }
                        } label: {
                            Text("Export Selected Range")
                                .frame(maxWidth: .infinity, alignment: .center)
                                .fontWeight(.bold)
                                .foregroundStyle(Color.accentColor)
                        }
                    }
                }
                .navigationTitle("Custom Export")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { viewModel.isShowingCustomExport = false }
                    }
                }
            }
            .presentationDetents([.medium])
        }
    }
}

// MARK: - Component View

struct KPICard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon).foregroundStyle(color).font(.title3)
                Spacer()
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(value).font(.title2).fontWeight(.bold).lineLimit(1).minimumScaleFactor(0.5)
                Text(title).font(.caption).foregroundStyle(.secondary).fontWeight(.medium)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemBackground))
        .cornerRadius(16)
    }
}
