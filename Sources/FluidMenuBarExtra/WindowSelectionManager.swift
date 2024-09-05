//
//  MainMenuViewModel.swift
//  How Long Left Mac
//
//  Created by Ryan on 25/5/2024.
//

import Foundation
import SwiftUI
import os.log

public class WindowSelectionManager: ObservableObject, SubWindowSelectionManager {
    
    @Published public var menuSelection: String? {
        didSet {
            handleSelectionChange(oldValue: oldValue, newValue: menuSelection)
        }
    }
    
    @Published var scrollPosition: CGPoint = .zero
    
    var latestItems = [String]()
    
    private var itemsProvider: MenuSelectableItemsProvider
    
    public var scrollProxy: ScrollViewProxy?
    
    private var latestHoverDate: Date?
    private var latestKeyDate: Date?
    
    private var selectFromHoverWorkItem: DispatchWorkItem?
    private var setHoverWorkItem: DispatchWorkItem?
    
    private var actualWindowHoverID: String?
    
    let logger: Logger
    
    public weak var submenuManager: FMBEWindowProxy?
    
    @Published public var clickID: String?
    
    var lastSelectWasByKey = false
    var latestScroll: Date?
    
    private var latestMouseMovement: Date?
    
    public var latestMenuHoverId: String?
    
    public init(itemsProvider: MenuSelectableItemsProvider) {
        self.itemsProvider = itemsProvider
       
       
        self.logger = Logger(subsystem: "com.ryankontos.fluid-menu-bar-extra", category: "WindowSelectionManager-\(UUID().uuidString)")
        
        self.latestItems = itemsProvider.getItems()
        
    }
    
    /// Called when the state of a user hovering over a subwindow changes.
    
    public func setWindowHovering(_ hovering: Bool, id: String?) {
        
       // logger.debug("Set window hovering: \(hovering), id: \(id ?? "nil")")
        
        selectFromHoverWorkItem?.cancel()
        setHoverWorkItem?.cancel()
        
        let item = DispatchWorkItem { [weak self] in
            
            //self?.logger.debug("Running set hover work item, id: \(id ?? "nil")")
            
            guard let self else { return }
            
            if hovering {
                self.actualWindowHoverID = id
            } else {
                self.actualWindowHoverID = nil
            }
            
            
            if hovering {
                selectID(id)
            } else if menuSelection == id {
                menuSelection = nil
                selectID(latestMenuHoverId)
            }
        }
        
        setHoverWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.0, execute: item)
    }
    
    /// Called when the state of a user hovering over a menu item changes
    
    public func setMenuItemHovering(id: String?, hovering: Bool) {
        
       // logger.debug("Set menu item hovering: \(hovering), id: \(id ?? "nil")")
        
        
        if id == nil && actualWindowHoverID != nil {
            return
        }
        
        self.latestMenuHoverId = id
        
        selectID(id)
        
    }
    
    private func selectID(_ idToSelect: String?) {
        
        //logger.debug("Select id: \(idToSelect ?? "nil")")
        
   
        selectFromHoverWorkItem?.cancel()
        
        let item = DispatchWorkItem { [weak self] in
            
            
            guard let self else { return }
          
            if self.latestMenuHoverId != idToSelect { return }
            
            latestHoverDate = Date()
            if let latestKeyDate = latestKeyDate, Date().timeIntervalSince(latestKeyDate) < 0.5 { return }
            
            lastSelectWasByKey = false
            
            
            
            //logger.debug("Menu selection is: \(menuSelection ?? "nil"), idToSelect is: \(idToSelect ?? "nil")")
            
            if menuSelection != idToSelect {
                
                menuSelection = idToSelect
            }
        }
        
        let delay: TimeInterval = {
            if let latestScroll = latestScroll, Date().timeIntervalSince(latestScroll) < 1 {
                return 0
            } else {
                
                let prev = menuSelection
                return prev == nil ? 0 : 0
            }
        }()
        
        selectFromHoverWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: item)
    }
    
    public func mouseMoved(point: NSPoint) {
        
        latestMouseMovement = Date()
    }
    
    
    func resetHover() {
        latestKeyDate = nil
        
    }
    
    public func clickItem() {
        clickID = menuSelection
    }
    
    public func selectNextItem() {
        guard let currentID = menuSelection else {
            menuSelection = latestItems.first
            return
        }
        
        let ids = latestItems
        if let currentIndex = ids.firstIndex(of: currentID), currentIndex + 1 < ids.count {
            menuSelection = ids[currentIndex + 1]
        }
        
        lastSelectWasByKey = true
        latestKeyDate = Date()
    }
    
    
    
   public func selectPreviousItem() {
        guard let currentID = menuSelection else {
            menuSelection = latestItems.last
            return
        }
        
        let ids = latestItems
        if let currentIndex = ids.firstIndex(of: currentID), currentIndex > 0 {
            menuSelection = ids[currentIndex - 1]
        }
        
        lastSelectWasByKey = true
        latestKeyDate = Date()
    }
    
    
    
    private func handleSelectionChange(oldValue: String?, newValue: String?) {
        
        
        
        DispatchQueue.main.async { [self] in
            
            submenuManager?.window?.closeSubwindow(notify: false) // Do not notify self (Because we already know!)
            
            
            if let newValue = newValue {
                submenuManager?.window?.openSubWindow(id: newValue)
            }
            
            if lastSelectWasByKey {
                scrollProxy?.scrollTo(newValue, anchor: .bottom)
            }
            
        }
    }
}

public enum OptionsSectionButton: String, CaseIterable {
    case settings, quit
}

public protocol MenuSelectableItemsProvider {
    
    func getItems() -> [String]
    
}

