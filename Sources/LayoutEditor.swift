import SwiftUI
import ServiceManagement

enum EditMode {
    case none
    case splitVertical
    case splitHorizontal
    case selectMerge
}

struct LayoutEditorView: View {
    @StateObject var store = LayoutStore.shared
    @State private var selectedLayoutID: UUID?
    @State private var selectedScreen: String = NSScreen.main?.localizedName ?? "Built-in Display"
    
    var connectedScreens: [String] {
        NSScreen.screens.map(\.localizedName)
    }
    
    var body: some View {
        NavigationView {
            List(selection: $selectedLayoutID) {
                Section(header: Text("Templates")) {
                    ForEach(store.templates) { layout in
                        NavigationLink(destination: LayoutDetailView(layout: layout, store: store, targetScreen: $selectedScreen)) {
                            Label(layout.name, systemImage: "squareshape.split.3x3")
                        }
                    }
                }
                
                Section(header: Text("Custom")) {
                    ForEach(store.customLayouts) { layout in
                        NavigationLink(destination: LayoutDetailView(layout: layout, store: store, targetScreen: $selectedScreen)) {
                            Label(layout.name, systemImage: "slider.horizontal.3")
                        }
                    }
                }
            }
            .listStyle(SidebarListStyle())
            .frame(minWidth: 200)
            
            Text("Select a layout to view or edit")
                .foregroundColor(.secondary)
        }
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button(action: addCustomLayout) {
                    Image(systemName: "plus")
                }
            }
            ToolbarItem(placement: .automatic) {
                HStack {
                    Picker("Target Screen", selection: $selectedScreen) {
                        ForEach(connectedScreens, id: \.self) { screen in
                            Text(screen).tag(screen)
                        }
                    }
                    .frame(width: 200)
                    .padding(.trailing, 8)
                    
                    Text("Padding:")
                        .foregroundColor(store.isPaddingEnabled ? .primary : .secondary)
                    Toggle("", isOn: $store.isPaddingEnabled)
                        .toggleStyle(SwitchToggleStyle(tint: .blue))
                        .labelsHidden()
                        
                    Divider().frame(height: 20).padding(.horizontal, 4)
                    
                    Text("Start on Login:")
                        .foregroundColor(store.startOnLogin ? .primary : .secondary)
                    Toggle("", isOn: $store.startOnLogin)
                        .toggleStyle(SwitchToggleStyle(tint: .blue))
                        .labelsHidden()
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(store.isPaddingEnabled ? Color.blue.opacity(0.1) : Color.clear)
                .cornerRadius(8)
            }
        }
        .frame(minWidth: 900, minHeight: 650)
    }
    
    private func addCustomLayout() {
        let newLayout = LayoutConfiguration(name: "New Custom Layout", isCustom: true, relativeZones: [CGRect(x: 0, y: 0, width: 1.0, height: 1.0)])
        store.customLayouts.append(newLayout)
        selectedLayoutID = newLayout.id
    }
}

struct LayoutDetailView: View {
    @State var layout: LayoutConfiguration
    @ObservedObject var store: LayoutStore
    @Binding var targetScreen: String
    
    @State private var editMode: EditMode = .none
    @State private var selectedZoneIndices: Set<Int> = []
    
    @State private var dragInitialZones: [CGRect]? = nil
    
    var body: some View {
        VStack(spacing: 20) {
            HStack {
                if layout.isCustom {
                    TextField("Layout Name", text: $layout.name)
                        .font(.title)
                        .onChange(of: layout.name) { _ in updateStore() }
                } else {
                    Text(layout.name)
                        .font(.title)
                        .bold()
                }
                Spacer()
                Button(action: applyLayout) {
                    Text(store.activeLayouts[targetScreen] == layout.id ? "Active on \(targetScreen)" : "Apply to \(targetScreen)")
                }
                .disabled(store.activeLayouts[targetScreen] == layout.id)
                .keyboardShortcut(.return, modifiers: [])
            }
            .padding(.horizontal)
            
            if layout.isCustom {
                Picker("Edit Mode", selection: $editMode) {
                    Text("Select / Merge").tag(EditMode.selectMerge)
                    Text("Split Vertically ( | )").tag(EditMode.splitVertical)
                    Text("Split Horizontally ( - )").tag(EditMode.splitHorizontal)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal)
                .onChange(of: editMode) { _ in
                    selectedZoneIndices.removeAll()
                }
            }
            
            ZStack {
                Color(NSColor.windowBackgroundColor)
                    .border(Color.gray, width: 1)
                
                GeometryReader { geo in
                    // Draw zones
                    ForEach(Array(layout.relativeZones.enumerated()), id: \.offset) { index, rect in
                        let swiftUIY = 1.0 - rect.maxY // Invert Y
                        let isSelected = selectedZoneIndices.contains(index)
                        
                        Rectangle()
                            .fill(isSelected ? Color.blue.opacity(0.4) : Color.blue.opacity(0.1))
                            .border(isSelected ? Color.blue : Color.gray, width: isSelected ? 3 : 1)
                            .overlay(Text("\(index + 1)").foregroundColor(.secondary))
                            .allowsHitTesting(false)
                            .frame(width: rect.width * geo.size.width, height: rect.height * geo.size.height)
                            .position(
                                x: (rect.minX + rect.width / 2) * geo.size.width,
                                y: (swiftUIY + rect.height / 2) * geo.size.height
                            )
                    }
                    
                    // Interaction layer for clicking
                    if layout.isCustom {
                        Color.black.opacity(0.01)
                            .onTapGesture(coordinateSpace: .local) { location in
                                print("Tap registered at: \(location)"); handleCanvasClick(at: location, in: geo.size)
                            }
                    }
                    
                    // Draggable Vertical Edges
                    if layout.isCustom && editMode == .selectMerge {
                        ForEach(verticalEdges, id: \.0) { _, edgeX in
                            Rectangle()
                                .fill(Color.black.opacity(0.01))
                                .frame(width: 16, height: geo.size.height)
                                .position(x: edgeX * geo.size.width, y: geo.size.height / 2)
                                .onHover { isHovered in
                                    if isHovered { NSCursor.resizeLeftRight.push() } else { NSCursor.pop() }
                                }
                                .gesture(
                                    DragGesture()
                                        .onChanged { value in
                                            if dragInitialZones == nil { dragInitialZones = layout.relativeZones }
                                            let deltaX = value.translation.width / geo.size.width
                                            applyDragVertical(initialEdgeX: edgeX, deltaX: deltaX, initialZones: dragInitialZones!)
                                        }
                                        .onEnded { _ in
                                            dragInitialZones = nil
                                            updateStore()
                                        }
                                )
                        }
                        
                        // Draggable Horizontal Edges
                        ForEach(horizontalEdges, id: \.0) { _, edgeY in
                            Rectangle()
                                .fill(Color.black.opacity(0.01))
                                .frame(width: geo.size.width, height: 16)
                                .position(x: geo.size.width / 2, y: (1.0 - edgeY) * geo.size.height)
                                .onHover { isHovered in
                                    if isHovered { NSCursor.resizeUpDown.push() } else { NSCursor.pop() }
                                }
                                .gesture(
                                    DragGesture()
                                        .onChanged { value in
                                            if dragInitialZones == nil { dragInitialZones = layout.relativeZones }
                                            let deltaY = -value.translation.height / geo.size.height // Inverted because SwiftUI Y is downwards
                                            applyDragHorizontal(initialEdgeY: edgeY, deltaY: deltaY, initialZones: dragInitialZones!)
                                        }
                                        .onEnded { _ in
                                            dragInitialZones = nil
                                            updateStore()
                                        }
                                )
                        }
                    }
                }
            }
            .padding()
            
            if layout.isCustom {
                HStack {
                    if editMode == .selectMerge {
                        Button("Merge Selected") {
                            mergeSelectedZones()
                        }
                        .disabled(selectedZoneIndices.count < 2)
                        .padding(8)
                        .background(selectedZoneIndices.count >= 2 ? Color.blue.opacity(0.1) : Color.gray.opacity(0.1))
                        .cornerRadius(6)
                    }
                    
                    Spacer()
                    
                    Button("Reset to Full Screen") {
                        layout.relativeZones = [CGRect(x: 0, y: 0, width: 1.0, height: 1.0)]
                        selectedZoneIndices.removeAll()
                        updateStore()
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(8)
                    .background(Color.red.opacity(0.1))
                    .foregroundColor(.red)
                    .cornerRadius(6)
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical)
    }
    
    private var verticalEdges: [(Int, CGFloat)] {
        let xs = layout.relativeZones.flatMap { [round($0.minX * 1000) / 1000, round($0.maxX * 1000) / 1000] }
        let uniqueXs = Array(Set(xs)).filter { $0 > 0.01 && $0 < 0.99 }.sorted()
        return Array(uniqueXs.enumerated())
    }
    
    private var horizontalEdges: [(Int, CGFloat)] {
        let ys = layout.relativeZones.flatMap { [round($0.minY * 1000) / 1000, round($0.maxY * 1000) / 1000] }
        let uniqueYs = Array(Set(ys)).filter { $0 > 0.01 && $0 < 0.99 }.sorted()
        return Array(uniqueYs.enumerated())
    }
    
    private func applyDragVertical(initialEdgeX: CGFloat, deltaX: CGFloat, initialZones: [CGRect]) {
        let oldXRounded = round(initialEdgeX * 1000) / 1000
        var minAllowed: CGFloat = 0.01
        var maxAllowed: CGFloat = 0.99
        
        for rect in initialZones {
            if round(rect.maxX * 1000) / 1000 == oldXRounded {
                minAllowed = max(minAllowed, rect.minX + 0.05)
            }
            if round(rect.minX * 1000) / 1000 == oldXRounded {
                maxAllowed = min(maxAllowed, rect.maxX - 0.05)
            }
        }
        
        let newX = initialEdgeX + deltaX
        let clampedNewX = max(minAllowed, min(maxAllowed, newX))
        var updated = initialZones
        
        for i in updated.indices {
            let minXRounded = round(updated[i].minX * 1000) / 1000
            let maxXRounded = round(updated[i].maxX * 1000) / 1000
            
            if minXRounded == oldXRounded {
                let diff = clampedNewX - updated[i].origin.x
                updated[i].origin.x = clampedNewX
                updated[i].size.width -= diff
            }
            if maxXRounded == oldXRounded {
                let currentMaxX = updated[i].origin.x + updated[i].size.width
                let diff = clampedNewX - currentMaxX
                updated[i].size.width += diff
            }
        }
        layout.relativeZones = updated
    }
    
    private func applyDragHorizontal(initialEdgeY: CGFloat, deltaY: CGFloat, initialZones: [CGRect]) {
        let oldYRounded = round(initialEdgeY * 1000) / 1000
        var minAllowed: CGFloat = 0.01
        var maxAllowed: CGFloat = 0.99
        
        for rect in initialZones {
            if round(rect.maxY * 1000) / 1000 == oldYRounded {
                minAllowed = max(minAllowed, rect.minY + 0.05)
            }
            if round(rect.minY * 1000) / 1000 == oldYRounded {
                maxAllowed = min(maxAllowed, rect.maxY - 0.05)
            }
        }
        
        let newY = initialEdgeY + deltaY
        let clampedNewY = max(minAllowed, min(maxAllowed, newY))
        var updated = initialZones
        
        for i in updated.indices {
            let minYRounded = round(updated[i].minY * 1000) / 1000
            let maxYRounded = round(updated[i].maxY * 1000) / 1000
            
            if minYRounded == oldYRounded {
                let diff = clampedNewY - updated[i].origin.y
                updated[i].origin.y = clampedNewY
                updated[i].size.height -= diff
            }
            if maxYRounded == oldYRounded {
                let currentMaxY = updated[i].origin.y + updated[i].size.height
                let diff = clampedNewY - currentMaxY
                updated[i].size.height += diff
            }
        }
        layout.relativeZones = updated
    }
    
    private func handleCanvasClick(at location: CGPoint, in size: CGSize) {
        // ... Split logic exactly as before ...
        let proportionalX = location.x / size.width
        let proportionalY = 1.0 - (location.y / size.height)
        let clickPoint = CGPoint(x: proportionalX, y: proportionalY)
        print("Canvas clicked! Proportional: \(clickPoint)")
        
        guard let clickedIndex = layout.relativeZones.firstIndex(where: { $0.contains(clickPoint) }) else { return }
        
        switch editMode {
        case .selectMerge:
            if selectedZoneIndices.contains(clickedIndex) {
                selectedZoneIndices.remove(clickedIndex)
            } else {
                selectedZoneIndices.insert(clickedIndex)
            }
            
        case .splitVertical:
            var updatedZones = layout.relativeZones
            let clickedZone = updatedZones[clickedIndex]
            updatedZones.remove(at: clickedIndex)
            
            let leftWidth = clickPoint.x - clickedZone.minX
            let rightWidth = clickedZone.maxX - clickPoint.x
            
            let leftZone = CGRect(x: clickedZone.minX, y: clickedZone.minY, width: leftWidth, height: clickedZone.height)
            let rightZone = CGRect(x: clickPoint.x, y: clickedZone.minY, width: rightWidth, height: clickedZone.height)
            
            updatedZones.insert(leftZone, at: clickedIndex)
            updatedZones.insert(rightZone, at: clickedIndex + 1)
            
            layout.relativeZones = updatedZones
            updateStore()
            
        case .splitHorizontal:
            var updatedZones = layout.relativeZones
            let clickedZone = updatedZones[clickedIndex]
            updatedZones.remove(at: clickedIndex)
            
            let bottomHeight = clickPoint.y - clickedZone.minY
            let topHeight = clickedZone.maxY - clickPoint.y
            
            let bottomZone = CGRect(x: clickedZone.minX, y: clickedZone.minY, width: clickedZone.width, height: bottomHeight)
            let topZone = CGRect(x: clickedZone.minX, y: clickPoint.y, width: clickedZone.width, height: topHeight)
            
            updatedZones.insert(bottomZone, at: clickedIndex)
            updatedZones.insert(topZone, at: clickedIndex + 1)
            
            layout.relativeZones = updatedZones
            updateStore()
            
        case .none:
            break
        }
    }
    
    private func mergeSelectedZones() {
        guard selectedZoneIndices.count >= 2 else { return }
        
        var updatedZones = layout.relativeZones
        let sortedIndices = selectedZoneIndices.sorted().reversed()
        var unionRect = updatedZones[sortedIndices.first!]
        
        for index in sortedIndices {
            let rectToMerge = updatedZones[index]
            unionRect = unionRect.union(rectToMerge)
            updatedZones.remove(at: index)
        }
        
        updatedZones.append(unionRect)
        selectedZoneIndices.removeAll()
        
        layout.relativeZones = updatedZones
        updateStore()
    }
    
    private func updateStore() {
        if let idx = store.customLayouts.firstIndex(where: { $0.id == layout.id }) {
            store.customLayouts[idx] = layout
            store.save()
            store.pushToZoneManager()
        }
    }
    
    private func applyLayout() {
        store.activeLayouts[targetScreen] = layout.id
        store.save()
    }
}

class LayoutStore: ObservableObject {
    static let shared = LayoutStore()
    
    @Published var templates: [LayoutConfiguration] = LayoutConfiguration.defaultTemplates
    @Published var customLayouts: [LayoutConfiguration] = []
    
    @Published var activeLayouts: [String: UUID] = [:] {
        didSet {
            pushToZoneManager()
        }
    }
    
    func pushToZoneManager() {
        var newLayoutsByScreen: [String: LayoutConfiguration] = [:]
        let allLayouts = templates + customLayouts
        for (screenName, uuid) in activeLayouts {
            if let match = allLayouts.first(where: { $0.id == uuid }) {
                newLayoutsByScreen[screenName] = match
            }
        }
        ZoneManager.shared.layoutsByScreen = newLayoutsByScreen
    }
    
    @Published var isPaddingEnabled: Bool = false {
        didSet {
            ZoneManager.shared.padding = isPaddingEnabled ? 16.0 : 0.0
            save()
        }
    }
    
    @Published var startOnLogin: Bool = false {
        didSet {
            let service = SMAppService.mainApp
            if startOnLogin {
                try? service.register()
            } else {
                try? service.unregister()
            }
        }
    }
    
    init() {
        load()
    }
    
    func save() {
        let defaults = UserDefaults.standard
        if let encoded = try? JSONEncoder().encode(activeLayouts) {
            defaults.set(encoded, forKey: "ActiveLayoutsDict")
        }
        defaults.set(isPaddingEnabled, forKey: "IsPaddingEnabled")
        
        if let encoded = try? JSONEncoder().encode(customLayouts) {
            defaults.set(encoded, forKey: "CustomLayouts")
        }
    }
    
    func load() {
        let defaults = UserDefaults.standard
        
        isPaddingEnabled = defaults.bool(forKey: "IsPaddingEnabled")
        ZoneManager.shared.padding = isPaddingEnabled ? 16.0 : 0.0
        
        if let data = defaults.data(forKey: "CustomLayouts"),
           let decoded = try? JSONDecoder().decode([LayoutConfiguration].self, from: data) {
            self.customLayouts = decoded
        }
        
        if let data = defaults.data(forKey: "ActiveLayoutsDict"),
           let dict = try? JSONDecoder().decode([String: UUID].self, from: data) {
            self.activeLayouts = dict
            pushToZoneManager()
        } else if let activeStr = defaults.string(forKey: "ActiveLayoutID"), let activeUUID = UUID(uuidString: activeStr) {
            // Migrate old global setting to current primary screen
            if let mainScreen = NSScreen.main?.localizedName {
                self.activeLayouts = [mainScreen: activeUUID]
                pushToZoneManager()
            }
        } else {
            // Default first template for primary screen
            if let mainScreen = NSScreen.main?.localizedName, let defaultTemplateId = templates.first?.id {
                self.activeLayouts = [mainScreen: defaultTemplateId]
                pushToZoneManager()
            }
        }
        
        self.startOnLogin = SMAppService.mainApp.status == .enabled
    }
}
