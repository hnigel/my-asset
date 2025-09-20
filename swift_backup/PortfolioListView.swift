import SwiftUI
import CoreData

struct PortfolioListView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var portfolioManager = PortfolioManager()
    @State private var portfolios: [Portfolio] = []
    @State private var showingCreatePortfolio = false
    @State private var newPortfolioName = ""
    
    var body: some View {
        NavigationView {
            List {
                ForEach(portfolios, id: \.portfolioID) { portfolio in
                    NavigationLink(destination: PortfolioDetailView(portfolio: portfolio)) {
                        PortfolioRowView(portfolio: portfolio, portfolioManager: portfolioManager)
                    }
                }
                .onDelete(perform: deletePortfolios)
            }
            .navigationTitle("Portfolios")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingCreatePortfolio = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingCreatePortfolio) {
                CreatePortfolioSheet(
                    portfolioName: $newPortfolioName,
                    isPresented: $showingCreatePortfolio,
                    onCreate: createPortfolio
                )
            }
            .onAppear {
                loadPortfolios()
            }
        }
    }
    
    private func loadPortfolios() {
        let fetchedPortfolios = portfolioManager.fetchPortfolios()
        DispatchQueue.main.async {
            self.portfolios = fetchedPortfolios
        }
    }
    
    private func createPortfolio() {
        guard !newPortfolioName.isEmpty else { return }
        let _ = portfolioManager.createPortfolio(name: newPortfolioName)
        newPortfolioName = ""
        loadPortfolios()
    }
    
    private func deletePortfolios(offsets: IndexSet) {
        withAnimation {
            let portfoliosToDelete = offsets.compactMap { index -> Portfolio? in
                // Ensure index is within bounds and the portfolio is valid
                guard index >= 0, 
                      index < portfolios.count,
                      let portfolio = portfolios.indices.contains(index) ? portfolios[index] : nil,
                      !portfolio.isDeleted else { 
                    return nil 
                }
                return portfolio
            }
            
            for portfolio in portfoliosToDelete {
                // Double-check the portfolio is still valid before deletion
                guard !portfolio.isDeleted, portfolio.managedObjectContext != nil else { continue }
                portfolioManager.deletePortfolio(portfolio)
            }
            
            loadPortfolios()
        }
    }
}

struct PortfolioRowView: View {
    let portfolio: Portfolio
    let portfolioManager: PortfolioManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(portfolio.name ?? "Unnamed Portfolio")
                    .font(.headline)
                Spacer()
                Text(portfolioValue, format: .currency(code: "USD"))
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            
            HStack {
                Text("\(holdingCount) holdings")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
            }
        }
        .padding(.vertical, 2)
    }
    
    private var portfolioValue: Decimal {
        portfolioManager.calculatePortfolioValue(portfolio)
    }
    
    private var holdingCount: Int {
        (portfolio.holdings as? Set<Holding>)?.count ?? 0
    }
    
}

struct CreatePortfolioSheet: View {
    @Binding var portfolioName: String
    @Binding var isPresented: Bool
    let onCreate: () -> Void
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Portfolio Details")) {
                    TextField("Portfolio Name", text: $portfolioName)
                }
            }
            .navigationTitle("New Portfolio")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create") {
                        onCreate()
                        isPresented = false
                    }
                    .disabled(portfolioName.isEmpty)
                }
            }
        }
    }
}

struct PortfolioListView_Previews: PreviewProvider {
    static var previews: some View {
        PortfolioListView()
            .environment(\.managedObjectContext, DataManager.shared.context)
    }
}