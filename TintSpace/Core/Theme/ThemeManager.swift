//
//  ThemeManager.swift
//  TintSpace
//
//  Created by Sai Dutt Ganduri on 3/13/25.
//

import SwiftUI
import Combine

enum Theme: String, CaseIterable, Identifiable {
    case system
    case light
    case dark
    
    var id: String { self.rawValue }
    
    var displayName: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .light: return .light
        case .dark: return .dark
        case .system: return nil
        }
    }

    // MARK: - Background Colors
    
    var backgroundColor: Color {
        switch self {
        case .light, .system: return .lightBackground
        case .dark: return .darkBackground
        }
    }

    var secondaryBackgroundColor: Color {
        switch self {
        case .light, .system: return .lightSecondaryBackground
        case .dark: return .darkSecondaryBackground
        }
    }
    
    var tertiaryBackgroundColor: Color {
        switch self {
        case .light, .system: return .lightTertiaryBackground
        case .dark: return .darkTertiaryBackground
        }
    }
    
    var cardBackgroundColor: Color {
        switch self {
        case .light, .system: return .lightCardBackground
        case .dark: return .darkCardBackground
        }
    }
    
    // MARK: - Text Colors
    
    var primaryTextColor: Color {
        switch self {
        case .light, .system: return .lightText
        case .dark: return .darkText
        }
    }

    var secondaryTextColor: Color {
        switch self {
        case .light, .system: return .lightSecondaryText
        case .dark: return .darkSecondaryText
        }
    }
    
    var tertiaryTextColor: Color {
        switch self {
        case .light, .system: return .lightTertiaryText
        case .dark: return .darkTertiaryText
        }
    }
    
    // MARK: - Brand Colors

    var primaryBrandColor: Color {
        return .tintBrush  // Our brand blue-teal
    }

    var secondaryBrandColor: Color {
        return .tintCanvas  // Our brand purple
    }
    
    var tertiaryBrandColor: Color {
        return .tintSwatch  // Our brand green
    }
    
    var accentColor: Color {
        return .tintHighlight  // Yellow accent
    }
    
    var highlightColor: Color {
        return .tintAccent  // Orange-red accent
    }

    // MARK: - Button Colors
    
    var primaryButtonBackgroundColor: Color {
        return .tintBrush
    }
    
    var primaryButtonTextColor: Color {
        return .white
    }
    
    var secondaryButtonBackgroundColor: Color {
        switch self {
        case .light, .system: return .lightSecondaryBackground
        case .dark: return .darkSecondaryBackground
        }
    }
    
    var secondaryButtonTextColor: Color {
        return .tintBrush
    }
    
    var tertiaryButtonBackgroundColor: Color {
        switch self {
        case .light, .system: return .clear
        case .dark: return .clear
        }
    }
    
    var tertiaryButtonTextColor: Color {
        switch self {
        case .light, .system: return .tintBrush
        case .dark: return .tintBrush.opacity(0.9)
        }
    }
    
    // MARK: - UI Element Colors
    
    var dividerColor: Color {
        switch self {
        case .light, .system: return Color.black.opacity(0.1)
        case .dark: return Color.white.opacity(0.1)
        }
    }
    
    var shadowColor: Color {
        switch self {
        case .light, .system: return Color.black.opacity(0.1)
        case .dark: return Color.black.opacity(0.5)
        }
    }
    
    var borderColor: Color {
        switch self {
        case .light, .system: return Color.black.opacity(0.15)
        case .dark: return Color.white.opacity(0.15)
        }
    }
    
    // MARK: - AR Colors
    
    var wallHighlightColor: Color {
        return .wallHighlight
    }
    
    var selectedWallColor: Color {
        return .selectedWallHighlight
    }
    
    var arPlacementGuideColor: Color {
        return .arPlacementGuide
    }
    
    var arControlIndicatorColor: Color {
        return .arControlIndicator
    }
    
    var arControlsBackgroundColor: Color {
        switch self {
        case .light, .system: return Color.white.opacity(0.9)
        case .dark: return Color.black.opacity(0.7)
        }
    }
    
    // MARK: - Status Colors
    
    var successColor: Color {
        return .successGreen
    }
    
    var warningColor: Color {
        return .warningYellow
    }
    
    var errorColor: Color {
        return .errorRed
    }
    
    var infoColor: Color {
        return .infoBlue
    }
}

class ThemeManager: ObservableObject {
    // MARK: - Published Properties
    
    /// Current theme selection
    @Published var themeType: Theme {
        didSet {
            // Save to UserDefaults
            userTheme = themeType.rawValue
            updateColorScheme()
            LogManager.shared.info(message: "Theme changed to \(themeType.rawValue)", category: "Theme")
        }
    }
    
    /// Current color scheme based on theme selection and system settings
    @Published var colorScheme: ColorScheme?
    
    // MARK: - Persistence
    
    /// User's theme preference stored in UserDefaults
    @AppStorage("userTheme") var userTheme: String = Theme.system.rawValue
    
    // MARK: - Private Properties
    
    /// User interface style from system
    private var userInterfaceStyle: UIUserInterfaceStyle {
        return UITraitCollection.current.userInterfaceStyle
    }
    
    /// Cancellables for Combine subscriptions
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init() {
        // Load saved theme preference or default to system
        let savedThemeValue = UserDefaults.standard.string(forKey: "userTheme") ?? Theme.system.rawValue
        self.themeType = Theme(rawValue: savedThemeValue) ?? .system
        
        // Set initial color scheme
        updateColorScheme()
        
        // Setup observers for system theme changes
        setupSystemThemeObserver()
        
        LogManager.shared.info(message: "ThemeManager initialized with theme: \(themeType.rawValue)", category: "Theme")
    }
    
    // MARK: - Private Methods
    
    /// Sets up observers for system theme changes
    private func setupSystemThemeObserver() {
        // Listen for app state changes to refresh color scheme
        NotificationCenter.default.addObserver(self, selector: #selector(updateColorSchemeFromSystem), name: UIApplication.didBecomeActiveNotification, object: nil)
        
        // Listen for significant time changes (which might indicate system theme changes)
        NotificationCenter.default.addObserver(self, selector: #selector(updateColorSchemeFromSystem), name: UIApplication.significantTimeChangeNotification, object: nil)
        
        // Listen for trait collection changes
        NotificationCenter.default.addObserver(forName: UIDevice.orientationDidChangeNotification, object: nil, queue: .main) { [weak self] _ in
            self?.updateColorSchemeFromSystem()
        }
    }
    
    /// Updates color scheme based on system settings
    @objc private func updateColorSchemeFromSystem() {
        if themeType == .system {
            colorScheme = userInterfaceStyle == .dark ? .dark : .light
            LogManager.shared.info(message: "Updated to system color scheme: \(colorScheme == .dark ? "dark" : "light")", category: "Theme")
        }
    }
    
    /// Updates color scheme based on current theme setting
    private func updateColorScheme() {
        switch themeType {
        case .system:
            colorScheme = userInterfaceStyle == .dark ? .dark : .light
        case .light:
            colorScheme = .light
        case .dark:
            colorScheme = .dark
        }
    }
    
    // MARK: - Public Methods
    
    /// The current theme resolved to light or dark (based on system if needed)
    var current: Theme {
        if themeType == .system {
            return userInterfaceStyle == .dark ? .dark : .light
        }
        return themeType
    }
    
    /// Toggle between light and dark modes
    func toggleLightDark() {
        switch themeType {
        case .system:
            // If system, switch to explicit opposite of current system
            themeType = userInterfaceStyle == .dark ? .light : .dark
        case .light:
            themeType = .dark
        case .dark:
            themeType = .light
        }
        LogManager.shared.info(message: "Toggled theme to: \(themeType.rawValue)", category: "Theme")
    }
    
    /// Reset to system theme
    func resetToSystem() {
        if themeType != .system {
            themeType = .system
            LogManager.shared.info(message: "Reset to system theme", category: "Theme")
        }
    }
    
    /// Apply a specific theme
    func applyTheme(_ theme: Theme) {
        if themeType != theme {
            themeType = theme
        }
    }
}

// MARK: - Environment Key for Theme

struct ThemeManagerKey: EnvironmentKey {
    static let defaultValue = ThemeManager()
}

extension EnvironmentValues {
    var themeManager: ThemeManager {
        get { self[ThemeManagerKey.self] }
        set { self[ThemeManagerKey.self] = newValue }
    }
}

// MARK: - View Extensions

extension View {
    /// Apply the theme manager environment object
    func withThemeManager(_ manager: ThemeManager = ThemeManager()) -> some View {
        self.environment(\.themeManager, manager)
            .environmentObject(manager)
            .preferredColorScheme(manager.colorScheme)
    }
    
    /// Apply a specific theme to a view
    func withTheme(_ theme: Theme) -> some View {
        self.modifier(ThemeModifier(theme: theme))
    }
}

struct ThemeModifier: ViewModifier {
    @Environment(\.themeManager) var themeManager
    let theme: Theme
    
    func body(content: Content) -> some View {
        content
            .onAppear {
                if themeManager.themeType != theme {
                    themeManager.themeType = theme
                }
            }
            .onChange(of: theme) { newTheme in
                if themeManager.themeType != newTheme {
                    themeManager.themeType = newTheme
                }
            }
    }
}
