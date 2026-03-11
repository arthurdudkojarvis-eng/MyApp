import SwiftUI

// MARK: - FlowBandShape

private struct FlowBandShape: Shape {
    let fromY: CGFloat
    let fromHeight: CGFloat
    let toY: CGFloat
    let toHeight: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let cp = rect.width * 0.5

        path.move(to: CGPoint(x: 0, y: fromY))
        path.addCurve(
            to: CGPoint(x: rect.width, y: toY),
            control1: CGPoint(x: cp, y: fromY),
            control2: CGPoint(x: rect.width - cp, y: toY)
        )
        path.addLine(to: CGPoint(x: rect.width, y: toY + toHeight))
        path.addCurve(
            to: CGPoint(x: 0, y: fromY + fromHeight),
            control1: CGPoint(x: rect.width - cp, y: toY + toHeight),
            control2: CGPoint(x: cp, y: fromY + fromHeight)
        )
        path.closeSubpath()
        return path
    }
}

// MARK: - PortfolioFlowView

struct PortfolioFlowView: View {
    let portfolios: [Portfolio]
    let totalValue: Decimal

    @Environment(\.dismiss) private var dismiss
    @Environment(\.massiveService) private var massive
    @State private var selectedPortfolio: String?
    @State private var appeared = false

    private static let palette: [Color] = [
        Color(red: 0.40, green: 0.72, blue: 1.0),   // sky blue
        Color(red: 0.35, green: 0.85, blue: 0.55),   // emerald
        Color(red: 1.0,  green: 0.70, blue: 0.28),   // amber
        Color(red: 0.72, green: 0.52, blue: 0.95),   // lavender
        Color(red: 1.0,  green: 0.48, blue: 0.52),   // coral
        Color(red: 0.28, green: 0.82, blue: 0.82),   // teal
    ]

    private static let maxHoldingsPerPortfolio = 8
    private static let bar: CGFloat = 10
    private static let nodeGap: CGFloat = 3

    var body: some View {
        NavigationStack {
            ZStack {
                // Gradient background
                LinearGradient(
                    colors: [Color(white: 0.06), Color(white: 0.10), Color(white: 0.07)],
                    startPoint: .top, endPoint: .bottom
                )
                .ignoresSafeArea()

                if totalValue > 0 {
                    GeometryReader { geo in
                        let W = geo.size.width - 32
                        let screenH = geo.size.height
                        let layout = buildLayout(W: W, H: screenH)
                        let contentH = layout.contentHeight

                        if contentH > screenH {
                            ScrollView(.vertical, showsIndicators: false) {
                                flowContent(layout: layout, W: W, H: contentH)
                            }
                        } else {
                            flowContent(layout: layout, W: W, H: screenH)
                        }
                    }
                } else {
                    ContentUnavailableView(
                        "No Holdings",
                        systemImage: "chart.bar.xaxis",
                        description: Text("Add holdings to see your portfolio flow.")
                    )
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }
            }
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .preferredColorScheme(.dark)
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) { appeared = true }
        }
    }

    // MARK: - Canvas

    @ViewBuilder
    private func flowContent(layout: FullLayout, W: CGFloat, H: CGFloat) -> some View {
        let insetH: CGFloat = 16

        ZStack {
            Canvas { ctx, _ in
                for band in layout.bands {
                    drawBand(ctx: &ctx, band: band, H: H)
                }
                for node in layout.nodes {
                    drawNode(ctx: &ctx, node: node)
                }
            }
            .frame(width: W, height: H)
            .opacity(appeared ? 1 : 0)

            // Invisible tap targets for node bars
            ForEach(layout.nodes.filter { $0.kind != .root }) { node in
                Color.clear
                    .frame(width: max(Self.bar + 20, 44), height: max(node.h, 44))
                    .contentShape(Rectangle())
                    .position(x: node.x + Self.bar / 2, y: node.y + node.h / 2)
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            let pid = node.portfolioId
                            selectedPortfolio = selectedPortfolio == pid ? nil : pid
                        }
                    }
            }

            // Labels overlay
            ZStack(alignment: .topLeading) {
                ForEach(layout.labels) { lbl in
                    labelPill(lbl)
                }
            }
            .frame(width: W, height: H, alignment: .topLeading)
            .allowsHitTesting(false)

        }
        .frame(height: H)
        .padding(.horizontal, insetH)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.25)) { selectedPortfolio = nil }
        }
    }

    // MARK: - Canvas Drawing

    private func drawBand(ctx: inout GraphicsContext, band: BandInfo, H: CGFloat) {
        let highlight = bandHighlight(band)
        let bandRect = CGRect(x: band.fromX, y: 0, width: band.toX - band.fromX, height: H)
        let shape = FlowBandShape(
            fromY: band.fromY, fromHeight: band.fromH,
            toY: band.toY, toHeight: band.toH
        ).path(in: bandRect)

        ctx.fill(shape, with: .linearGradient(
            Gradient(colors: [
                band.color.opacity(highlight),
                band.color.opacity(highlight * 0.55)
            ]),
            startPoint: CGPoint(x: band.fromX, y: 0),
            endPoint: CGPoint(x: band.toX, y: 0)
        ))
    }

    private func drawNode(ctx: inout GraphicsContext, node: NodeInfo) {
        let dimmed = isNodeDimmed(node)
        let barRect = CGRect(x: node.x, y: node.y, width: Self.bar, height: node.h)

        // Glow behind bar
        if !dimmed {
            var glowCtx = ctx
            glowCtx.addFilter(.blur(radius: 6))
            let glowRect = barRect.insetBy(dx: -3, dy: -2)
            let glowPath = RoundedRectangle(cornerRadius: 5, style: .continuous).path(in: glowRect)
            glowCtx.fill(glowPath, with: .color(node.color.opacity(0.3)))
        }

        // Bar
        let barPath = RoundedRectangle(cornerRadius: 4, style: .continuous).path(in: barRect)
        ctx.fill(barPath, with: .color(node.color.opacity(dimmed ? 0.2 : 0.85)))
    }

    // MARK: - Label View

    private static let pillH: CGFloat = 24  // estimated pill height for de-overlap

    @ViewBuilder
    private func labelPill(_ lbl: LabelData) -> some View {
        let isRight = lbl.anchor == .rightOfBar
        let gap: CGFloat = 6
        let halfPill = Self.pillH / 2
        let isSelected = selectedPortfolio != nil && lbl.portfolioId == selectedPortfolio
        let dimmed = selectedPortfolio != nil && !isSelected

        // Holdings: only show when their portfolio is selected
        let isHolding = lbl.ticker != nil || lbl.holdingTickers.isEmpty && !isRight
        if isHolding && !isSelected && selectedPortfolio != nil {
            EmptyView()
        } else {
            let pill = HStack(spacing: 5) {
                if let ticker = lbl.ticker {
                    CompanyLogoView(
                        branding: nil,
                        ticker: ticker,
                        service: massive.service,
                        size: 14
                    )
                }
                Text(lbl.name)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text("\(lbl.pct)%")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(lbl.color)
                Text(lbl.compact)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.5))
            }
            .fixedSize()
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color(white: 0.10).opacity(0.92))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .strokeBorder(lbl.color.opacity(0.25), lineWidth: 0.5)
                    )
            )

            if isRight {
                let startX = lbl.barX + Self.bar + gap
                HStack(spacing: 0) {
                    pill
                    Spacer(minLength: 0)
                }
                .frame(width: max(0, lbl.availableW - startX))
                .offset(x: startX, y: lbl.centerY - halfPill)
                .opacity(dimmed ? 0.15 : 1)
            } else {
                HStack(spacing: 0) {
                    Spacer(minLength: 0)
                    pill
                }
                .frame(width: max(0, lbl.barX - gap))
                .offset(y: lbl.centerY - halfPill)
                .opacity(dimmed ? 0.15 : 1)
            }
        }
    }

    // MARK: - Content sizing

    // MARK: - Highlight helpers

    private func bandHighlight(_ band: BandInfo) -> Double {
        guard let sel = selectedPortfolio else { return 0.4 }
        return band.portfolioId == sel ? 0.65 : 0.04
    }

    private func isNodeDimmed(_ node: NodeInfo) -> Bool {
        guard let sel = selectedPortfolio else { return false }
        if node.kind == .root { return false }
        return node.portfolioId != sel
    }

    private func isPortfolioDimmed(_ pid: String) -> Bool {
        guard let sel = selectedPortfolio else { return false }
        return pid != sel
    }

    // MARK: - Compact formatting

    private func formatCompact(_ value: Decimal) -> String {
        let d = NSDecimalNumber(decimal: value).doubleValue
        switch d {
        case 1_000_000_000...: return String(format: "$%.1fB", d / 1_000_000_000)
        case 1_000_000...:     return String(format: "$%.1fM", d / 1_000_000)
        case 1_000...:         return String(format: "$%.1fK", d / 1_000)
        default:               return "$\(Int(d))"
        }
    }

    private func pct(_ value: Decimal) -> Int {
        guard totalValue > 0 else { return 0 }
        return Int(round(CGFloat(truncating: NSDecimalNumber(decimal: value / totalValue)) * 100))
    }

    // MARK: - Layout Data

    private enum NodeKind { case root, portfolio, holding }

    private struct NodeInfo: Identifiable {
        let id: String; let kind: NodeKind; let portfolioId: String
        let x: CGFloat; let y: CGFloat; let h: CGFloat; let color: Color
        var ticker: String? = nil
    }

    private struct BandInfo: Identifiable {
        let id: String; let portfolioId: String
        let fromX: CGFloat; let toX: CGFloat
        let fromY: CGFloat; let fromH: CGFloat
        let toY: CGFloat; let toH: CGFloat; let color: Color
    }

    private enum LabelAnchor {
        case leftOfBar   // label's trailing edge touches barX - gap
        case rightOfBar  // label's leading edge starts at barX + barWidth + gap
    }

    private struct LabelData: Identifiable {
        let id: String; let name: String; let pct: Int; let compact: String
        let color: Color; let barX: CGFloat; let centerY: CGFloat
        let anchor: LabelAnchor; let portfolioId: String?
        var availableW: CGFloat = 0
        var ticker: String? = nil
        var holdingTickers: [String] = []  // for portfolio labels: top tickers to show on select
    }

    private struct FullLayout {
        let nodes: [NodeInfo]; let bands: [BandInfo]; let labels: [LabelData]
        let contentHeight: CGFloat  // actual extent of nodes + labels
    }

    // MARK: - Layout Engine

    private func buildLayout(W: CGFloat, H: CGFloat) -> FullLayout {
        let active = portfolios.filter { $0.totalMarketValue > 0 }
        guard !active.isEmpty, totalValue > 0 else {
            return FullLayout(nodes: [], bands: [], labels: [], contentHeight: 0)
        }

        let singlePortfolio = active.count == 1

        // --- Build holding display list ---
        struct HEntry { let pid: String; let label: String; let ticker: String?; let value: Decimal; let color: Color }
        var holdingEntries: [HEntry] = []
        for (i, p) in active.enumerated() {
            let sorted = p.holdings.filter { $0.currentValue > 0 }.sorted { $0.currentValue > $1.currentValue }
            let c = Self.palette[i % Self.palette.count]
            if sorted.count > Self.maxHoldingsPerPortfolio {
                for h in sorted.prefix(Self.maxHoldingsPerPortfolio) {
                    holdingEntries.append(HEntry(pid: p.id.uuidString, label: h.stock?.ticker ?? "???", ticker: h.stock?.ticker, value: h.currentValue, color: c))
                }
                let rest = sorted.dropFirst(Self.maxHoldingsPerPortfolio)
                holdingEntries.append(HEntry(pid: p.id.uuidString, label: "+\(rest.count) others", ticker: nil, value: rest.reduce(Decimal.zero) { $0 + $1.currentValue }, color: c))
            } else {
                for h in sorted {
                    holdingEntries.append(HEntry(pid: p.id.uuidString, label: h.stock?.ticker ?? "???", ticker: h.stock?.ticker, value: h.currentValue, color: c))
                }
            }
        }

        // Y positions for holdings
        let hGap = Self.nodeGap * CGFloat(max(0, holdingEntries.count - 1))
        let hDraw = H - hGap
        struct YN { let id: String; let pid: String; let y: CGFloat; let h: CGFloat; let color: Color; let label: String; let value: Decimal; let ticker: String? }
        var hNodes: [YN] = []
        var hy: CGFloat = 0
        for (i, e) in holdingEntries.enumerated() {
            let frac = CGFloat(truncating: NSDecimalNumber(decimal: e.value / totalValue))
            let nodeH = max(12, hDraw * frac)
            hNodes.append(YN(id: "h\(i)", pid: e.pid, y: hy, h: nodeH, color: e.color, label: e.label, value: e.value, ticker: e.ticker))
            hy += nodeH + Self.nodeGap
        }

        var nodes: [NodeInfo] = []
        var bands: [BandInfo] = []
        var labels: [LabelData] = []

        if singlePortfolio {
            // ===== 2-COLUMN: Total → Holdings =====
            let col0X: CGFloat = 0
            let col1X: CGFloat = W - Self.bar

            nodes.append(NodeInfo(id: "root", kind: .root, portfolioId: "root", x: col0X, y: 0, h: H, color: .accentColor))

            for n in hNodes {
                nodes.append(NodeInfo(id: n.id, kind: .holding, portfolioId: n.pid, x: col1X, y: n.y, h: n.h, color: n.color))
                // Label to the left of holding bar
                labels.append(LabelData(id: "lbl-\(n.id)", name: n.label, pct: pct(n.value), compact: formatCompact(n.value), color: n.color, barX: col1X, centerY: n.y + n.h / 2, anchor: .leftOfBar, portfolioId: nil, availableW: W, ticker: n.ticker))
            }

            var rootOff: CGFloat = 0
            let totalNodeH = hNodes.reduce(CGFloat(0)) { $0 + $1.h }
            for n in hNodes {
                let fromH = totalNodeH > 0 ? H * (n.h / totalNodeH) : 0
                bands.append(BandInfo(id: "b-\(n.id)", portfolioId: n.pid, fromX: Self.bar, toX: col1X, fromY: rootOff, fromH: fromH, toY: n.y, toH: n.h, color: n.color))
                rootOff += fromH
            }
        } else {
            // ===== 3-COLUMN: Total → Portfolios → Holdings =====
            let col0X: CGFloat = 0
            let col1X: CGFloat = W * 0.36
            let col2X: CGFloat = W - Self.bar

            // Portfolio nodes
            let pGap = Self.nodeGap * CGFloat(max(0, active.count - 1))
            let pDraw = H - pGap
            struct PN { let id: String; let y: CGFloat; let h: CGFloat; let color: Color; let name: String; let value: Decimal }
            var pNodes: [PN] = []
            var py: CGFloat = 0
            for (i, p) in active.enumerated() {
                let frac = CGFloat(truncating: NSDecimalNumber(decimal: p.totalMarketValue / totalValue))
                let nodeH = max(4, pDraw * frac)
                let c = Self.palette[i % Self.palette.count]
                pNodes.append(PN(id: p.id.uuidString, y: py, h: nodeH, color: c, name: p.name, value: p.totalMarketValue))
                py += nodeH + Self.nodeGap
            }

            // Root node
            nodes.append(NodeInfo(id: "root", kind: .root, portfolioId: "root", x: col0X, y: 0, h: H, color: .accentColor))

            // Portfolio nodes + labels (right of bar in the band zone)
            for p in pNodes {
                nodes.append(NodeInfo(id: p.id, kind: .portfolio, portfolioId: p.id, x: col1X, y: p.y, h: p.h, color: p.color))
                let topTickers = holdingEntries
                    .filter { $0.pid == p.id }
                    .compactMap { $0.ticker }
                    .prefix(5)
                labels.append(LabelData(id: "lbl-p-\(p.id)", name: p.name, pct: pct(p.value), compact: formatCompact(p.value), color: p.color, barX: col0X, centerY: p.y + p.h / 2, anchor: .rightOfBar, portfolioId: p.id, availableW: W, holdingTickers: Array(topTickers)))
            }

            // Holding nodes + labels (to the right of bar)
            for n in hNodes {
                nodes.append(NodeInfo(id: n.id, kind: .holding, portfolioId: n.pid, x: col2X, y: n.y, h: n.h, color: n.color))
                // Label to the left of holding bar
                labels.append(LabelData(id: "lbl-h-\(n.id)", name: n.label, pct: pct(n.value), compact: formatCompact(n.value), color: n.color, barX: col2X, centerY: n.y + n.h / 2, anchor: .leftOfBar, portfolioId: n.pid, availableW: W, ticker: n.ticker))
            }

            // Bands L1: root → portfolios
            var rootOff: CGFloat = 0
            let totalPH = pNodes.reduce(CGFloat(0)) { $0 + $1.h }
            for p in pNodes {
                let fromH = totalPH > 0 ? H * (p.h / totalPH) : 0
                bands.append(BandInfo(id: "b1-\(p.id)", portfolioId: p.id, fromX: Self.bar, toX: col1X, fromY: rootOff, fromH: fromH, toY: p.y, toH: p.h, color: p.color))
                rootOff += fromH
            }

            // Bands L2: portfolios → holdings
            for p in pNodes {
                let pHoldings = hNodes.filter { $0.pid == p.id }
                let totalPHoldings = pHoldings.reduce(CGFloat(0)) { $0 + $1.h }
                var off: CGFloat = 0
                for hn in pHoldings {
                    let frac = totalPHoldings > 0 ? hn.h / totalPHoldings : 0
                    let bH = p.h * frac
                    bands.append(BandInfo(id: "b2-\(p.id)-\(hn.id)", portfolioId: p.id, fromX: col1X + Self.bar, toX: col2X, fromY: p.y + off, fromH: bH, toY: hn.y, toH: hn.h, color: hn.color))
                    off += bH
                }
            }
        }

        // Actual content extent from nodes
        let maxNodeY = nodes.map { $0.y + $0.h }.max() ?? H
        let nodeExtent = max(H, maxNodeY + Self.pillH)

        // De-overlap labels vertically within each column/anchor group
        labels = Self.deOverlapLabels(labels, totalH: nodeExtent)

        // Final content height: max of node extent and label extent
        let maxLabelY = labels.map { $0.centerY + Self.pillH / 2 }.max() ?? 0
        let actualH = max(nodeExtent, maxLabelY + Self.pillH)

        return FullLayout(nodes: nodes, bands: bands, labels: labels, contentHeight: actualH)
    }

    /// Spreads labels apart vertically so they don't overlap.
    /// Groups by (barX, anchor) then resolves collisions within each group.
    private static func deOverlapLabels(_ labels: [LabelData], totalH: CGFloat) -> [LabelData] {
        struct GroupKey: Hashable { let barX: Int; let anchor: Int }
        var groups: [GroupKey: [Int]] = [:]
        for (i, lbl) in labels.enumerated() {
            let key = GroupKey(barX: Int(lbl.barX), anchor: lbl.anchor == .leftOfBar ? 0 : 1)
            groups[key, default: []].append(i)
        }

        var result = labels
        let spacing = pillH + 2
        let halfPill = pillH / 2

        for (_, indices) in groups {
            guard indices.count > 1 else { continue }

            let sorted = indices.sorted { result[$0].centerY < result[$1].centerY }
            var positions = sorted.map { result[$0].centerY }
            let count = positions.count

            // 1) Top-down pass: ensure each label is at least `spacing` below the previous
            for j in 1..<count {
                let minY = positions[j - 1] + spacing
                if positions[j] < minY {
                    positions[j] = minY
                }
            }

            // 2) If the group overflows the bottom, shift everything up
            let bottomOverflow = positions[count - 1] - (totalH - halfPill)
            if bottomOverflow > 0 {
                for j in 0..<count {
                    positions[j] -= bottomOverflow
                }
            }

            // 3) Bottom-up pass: if shifting caused top overflow, push back down
            if positions[0] < halfPill {
                positions[0] = halfPill
                for j in 1..<count {
                    let minY = positions[j - 1] + spacing
                    if positions[j] < minY {
                        positions[j] = minY
                    }
                }
            }

            // Write back
            for (j, idx) in sorted.enumerated() {
                let lbl = result[idx]
                result[idx] = LabelData(
                    id: lbl.id, name: lbl.name, pct: lbl.pct, compact: lbl.compact,
                    color: lbl.color, barX: lbl.barX, centerY: positions[j],
                    anchor: lbl.anchor, portfolioId: lbl.portfolioId,
                    availableW: lbl.availableW, ticker: lbl.ticker,
                    holdingTickers: lbl.holdingTickers
                )
            }
        }

        return result
    }
}
