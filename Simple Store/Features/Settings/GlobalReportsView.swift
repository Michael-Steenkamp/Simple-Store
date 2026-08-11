//
//  GlobalReportsView.swift
//  Simple Inventory
//
//  Created by Michael Steenkamp on 2026-07-20.
//

import SwiftUI
import SwiftData
import Charts

struct GlobalReportsView: View {
    @Query(sort: \Transaction.date, order: .reverse) private var allTransactions: [Transaction]
    
    @State private var selectedTimeframe: Timeframe = .allTime
    @State private var isExporting = false
    @State private var exportSuccess = false
    
    @State private var isShowingCustomExport = false
    @State private var customStartDate = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
    @State private var customEndDate = Date()
    
    enum Timeframe: String, CaseIterable, Identifiable {
        case today = "Today"
        case thisWeek = "This Week"
        case thisMonth = "This Month"
        case allTime = "All Time"
        var id: String { self.rawValue }
    }
    
    // MARK: - Data Computations
    var filteredTransactions: [Transaction] {
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
    
    var totalRevenue: Double {
        filteredTransactions.reduce(0) { $0 + $1.totalAmount }
    }
    
    var totalUnitsSold: Int {
        filteredTransactions.reduce(0) { sum, transaction in
            let itemsQty = transaction.lineItems?.reduce(0) { $0 + $1.quantity } ?? 0
            return sum + itemsQty
        }
    }
    
    var averageOrderValue: Double {
        guard !filteredTransactions.isEmpty else { return 0.0 }
        return totalRevenue / Double(filteredTransactions.count)
    }
    
    // MARK: - Chart Data Models
    struct RevenueData: Identifiable {
        let id = UUID()
        let date: Date
        let amount: Double
    }
    
    var revenueTimeSeries: [RevenueData] {
        let calendar = Calendar.current
        var grouped: [Date: Double] = [:]
        
        for tx in filteredTransactions {
            let dateKey: Date
            switch selectedTimeframe {
            case .today:
                // Group by hour
                dateKey = calendar.date(bySetting: .minute, value: 0, of: tx.date) ?? tx.date
            case .thisWeek, .thisMonth:
                // Group by day
                dateKey = calendar.startOfDay(for: tx.date)
            case .allTime:
                // Group by month
                let comps = calendar.dateComponents([.year, .month], from: tx.date)
                dateKey = calendar.date(from: comps) ?? tx.date
            }
            grouped[dateKey, default: 0] += tx.totalAmount
        }
        
        return grouped.map { RevenueData(date: $0.key, amount: $0.value) }
            .sorted { $0.date < $1.date }
    }
    
    var chartUnit: Calendar.Component {
        switch selectedTimeframe {
        case .today: return .hour
        case .thisWeek, .thisMonth: return .day
        case .allTime: return .month
        }
    }
    
    var topSellingItems: [(name: String, quantity: Int, revenue: Double)] {
        var itemStats: [String: (quantity: Int, revenue: Double)] = [:]
        
        for transaction in filteredTransactions {
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
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // MARK: - Timeframe Selector
                Picker("Timeframe", selection: $selectedTimeframe.animation(.easeInOut)) {
                    ForEach(Timeframe.allCases) { timeframe in
                        Text(timeframe.rawValue).tag(timeframe)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.top, 10)
                
                // MARK: - KPI Cards
                VStack(spacing: 16) {
                    HStack(spacing: 16) {
                        KPICard(title: "Gross Revenue", value: totalRevenue.formatted(.currency(code: "CAD")), icon: "dollarsign.circle.fill", color: .green)
                        KPICard(title: "Units Sold", value: "\(totalUnitsSold)", icon: "shippingbox.fill", color: .blue)
                    }
                    
                    HStack(spacing: 16) {
                        KPICard(title: "Total Orders", value: "\(filteredTransactions.count)", icon: "receipt.fill", color: .orange)
                        KPICard(title: "Avg. Order Value", value: averageOrderValue.formatted(.currency(code: "CAD")), icon: "chart.line.uptrend.xyaxis.circle.fill", color: .purple)
                    }
                }
                .padding(.horizontal)
                
                Divider().padding(.vertical, 8)
                
                // MARK: - Revenue Trend Chart
                VStack(alignment: .leading, spacing: 16) {
                    Text("Revenue Trend")
                        .font(.title3)
                        .fontWeight(.bold)
                        .padding(.horizontal)
                    
                    if revenueTimeSeries.isEmpty {
                        Text("No sales data available to chart.")
                            .foregroundColor(.secondary)
                            .italic()
                            .padding(.horizontal)
                            .frame(height: 180)
                    } else {
                        Chart {
                            ForEach(revenueTimeSeries) { data in
                                BarMark(
                                    x: .value("Date", data.date, unit: chartUnit),
                                    y: .value("Revenue", data.amount)
                                )
                                .foregroundStyle(Color.green.gradient)
                                .cornerRadius(4)
                            }
                        }
                        .chartXAxis {
                            AxisMarks(values: .stride(by: chartUnit)) { _ in
                                AxisGridLine()
                                AxisTick()
                                AxisValueLabel(format: xAxisFormat())
                            }
                        }
                        .frame(height: 200)
                        .padding(.horizontal)
                    }
                }
                
                Divider().padding(.vertical, 8)
                
                // MARK: - Top Performing Items List
                VStack(alignment: .leading, spacing: 16) {
                    Text("Top Performing Items")
                        .font(.title3)
                        .fontWeight(.bold)
                        .padding(.horizontal)
                    
                    if topSellingItems.isEmpty {
                        Text("No item data for this period.")
                            .foregroundColor(.secondary)
                            .italic()
                            .padding(.horizontal)
                    } else {
                        VStack(spacing: 12) {
                            ForEach(Array(topSellingItems.enumerated()), id: \.element.name) { index, item in
                                HStack {
                                    Text("\(index + 1)")
                                        .font(.headline)
                                        .foregroundColor(.secondary)
                                        .frame(width: 24, alignment: .leading)
                                    VStack(alignment: .leading) {
                                        Text(item.name).fontWeight(.semibold)
                                        Text("\(item.quantity) units sold").font(.caption).foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    Text(item.revenue.formatted(.currency(code: "CAD"))).fontWeight(.bold)
                                }
                                .padding()
                                .background(Color(UIColor.secondarySystemBackground))
                                .cornerRadius(12)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
            .padding(.bottom, 40)
        }
        .animation(.default, value: filteredTransactions.count)
        .navigationTitle("Global Sales")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: {
                    if selectedTimeframe == .allTime {
                        isShowingCustomExport = true
                    } else {
                        exportData(transactions: filteredTransactions, label: selectedTimeframe.rawValue)
                    }
                }) {
                    ZStack {
                        if isExporting {
                            ProgressView()
                        } else {
                            Image(systemName: "square.and.arrow.up")
                        }
                    }
                    .frame(width: 25, height: 25, alignment: .center)
                }
                .disabled(filteredTransactions.isEmpty || isExporting)
            }
        }
        .sensoryFeedback(.success, trigger: exportSuccess)
        .sheet(isPresented: $isShowingCustomExport) {
            NavigationStack {
                Form {
                    Section(header: Text("Select Date Range")) {
                        DatePicker("Start Date", selection: $customStartDate, displayedComponents: .date)
                        DatePicker("End Date", selection: $customEndDate, displayedComponents: .date)
                    }
                    
                    Section {
                        Button(action: {
                            let customTransactions = allTransactions.filter {
                                $0.date >= customStartDate && $0.date <= customEndDate
                            }
                            isShowingCustomExport = false
                            exportData(transactions: customTransactions, label: "Custom Range")
                        }) {
                            Text("Export Selected Range")
                                .frame(maxWidth: .infinity, alignment: .center)
                                .fontWeight(.bold)
                                .foregroundColor(.blue)
                        }
                    }
                }
                .navigationTitle("Custom Export")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { isShowingCustomExport = false }
                    }
                }
            }
            .presentationDetents([.medium])
        }
    }
    
    // MARK: - Helpers
    private func xAxisFormat() -> Date.FormatStyle {
        switch selectedTimeframe {
        case .today: return .dateTime.hour()
        case .thisWeek: return .dateTime.weekday(.abbreviated)
        case .thisMonth: return .dateTime.day()
        case .allTime: return .dateTime.month(.abbreviated).year()
        }
    }
    
    private func exportData(transactions: [Transaction], label: String) {
        guard !transactions.isEmpty else { return }
        isExporting = true
        
        Task {
            do {
                let url = try await CSVEngine.generate(from: transactions, timeframeLabel: label)
                
                await MainActor.run {
                    isExporting = false
                    exportSuccess.toggle()
                    presentShareSheet(for: url)
                }
            } catch {
                await MainActor.run {
                    isExporting = false
                    print("Error generating CSV: \(error)")
                }
            }
        }
    }
    
    private func presentShareSheet(for url: URL) {
        let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootVC = window.rootViewController {
            
            activityVC.popoverPresentationController?.sourceView = window
            activityVC.popoverPresentationController?.sourceRect = CGRect(x: window.bounds.midX, y: window.bounds.midY, width: 0, height: 0)
            
            rootVC.present(activityVC, animated: true)
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
                Image(systemName: icon).foregroundColor(color).font(.title3)
                Spacer()
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(value).font(.title2).fontWeight(.bold).lineLimit(1).minimumScaleFactor(0.5)
                Text(title).font(.caption).foregroundColor(.secondary).fontWeight(.medium)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(16)
    }
}
