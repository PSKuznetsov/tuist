import Foundation
import TuistCore
import XcodeGraph

/// Defines the interface to obtain the content to generate derived Info.plist files for the targets.
protocol InfoPlistContentProviding {
    /// It returns the content that should be used to generate an Info.plist file
    /// for the given target. It uses default values that specific to the target's destinations
    /// and product, and extends them with the values provided by the user.
    ///
    /// - Parameters:
    ///   - project: The project that hosts the target for which the Info.plist content will be returned
    ///   - target: Target whose Info.plist content will be returned.
    ///   - extendedWith: Values provided by the user to extend the default ones.
    /// - Returns: Content to generate the Info.plist file.
    func content(project: Project, target: Target, extendedWith: [String: Plist.Value]) -> [String: Any]?
}

final class InfoPlistContentProvider: InfoPlistContentProviding {
    /// It returns the content that should be used to generate an Info.plist file
    /// for the given target. It uses default values that specific to the target's destinations
    /// and product, and extends them with the values provided by the user.
    ///
    /// - Parameters:
    ///   - project: The project that hosts the target for which the Info.plist content will be returned
    ///   - target: Target whose Info.plist content will be returned.
    ///   - extendedWith: Values provided by the user to extend the default ones.
    /// - Returns: Content to generate the Info.plist file.
    func content(project: Project, target: Target, extendedWith: [String: Plist.Value]) -> [String: Any]? {
        if target.product == .staticLibrary || target.product == .dynamicLibrary {
            return nil
        }

        var content = base()

        // Bundle package type
        extend(&content, with: bundlePackageType(target))

        // Bundle Executable
        extend(&content, with: bundleExecutable(target))

        // iOS app
        if target.product == .app, target.supports(.iOS) {
            let supportsIpad = target.destinations.contains(.iPad)
            extend(&content, with: iosApp(iPadSupport: supportsIpad))
        }

        // macOS app
        if target.product == .app, target.supports(.macOS) {
            extend(&content, with: macosApp())
        }

        // macOS
        if target.supports(.macOS) {
            extend(&content, with: macos())
        }

        // watchOS app
        if target.product == .watch2App {
            let host = hostTarget(for: target, in: project)
            extend(&content, with: watchosApp(
                name: target.name,
                hostAppBundleId: host?.bundleId
            ))
        }

        // watchOS app extension
        if target.product == .watch2Extension {
            let host = hostTarget(for: target, in: project)
            extend(&content, with: watchosAppExtension(
                name: target.name,
                hostAppBundleId: host?.bundleId
            ))
        }

        extend(&content, with: extendedWith.unwrappingValues())

        return content
    }

    /// Returns a dictionary that contains the base content that all Info.plist
    /// files should have regardless of the destinations or product.
    ///
    /// - Returns: Base content.
    func base() -> [String: Any] {
        [
            "CFBundleDevelopmentRegion": "$(DEVELOPMENT_LANGUAGE)",
            "CFBundleIdentifier": "$(PRODUCT_BUNDLE_IDENTIFIER)",
            "CFBundleInfoDictionaryVersion": "6.0",
            "CFBundleName": "$(PRODUCT_NAME)",
            "CFBundleShortVersionString": "1.0",
            "CFBundleVersion": "1",
        ]
    }

    /// Returns the Info.plist content that includes the CFBundlePackageType
    /// attribute depending on the target product type.
    ///
    /// - Parameter target: Target whose Info.plist's CFBundlePackageType will be returned.
    /// - Returns: Dictionary with the CFBundlePackageType attribute.
    func bundlePackageType(_ target: Target) -> [String: Any] {
        var packageType: String?

        switch target.product {
        case .app, .appClip:
            packageType = "APPL"
        case .staticLibrary, .dynamicLibrary:
            packageType = nil
        case .uiTests, .unitTests, .bundle:
            packageType = "BNDL"
        case .staticFramework, .framework:
            packageType = "FMWK"
        case .watch2App, .watch2Extension, .tvTopShelfExtension:
            packageType = "$(PRODUCT_BUNDLE_PACKAGE_TYPE)"
        case .appExtension, .stickerPackExtension, .messagesExtension, .xpc, .extensionKitExtension:
            packageType = "XPC!"
        case .commandLineTool:
            packageType = nil
        case .macro:
            packageType = nil
        case .systemExtension:
            packageType = "SYSX"
        }

        if let packageType {
            return ["CFBundlePackageType": packageType]
        } else {
            return [:]
        }
    }

    func bundleExecutable(_ target: Target) -> [String: Any] {
        if shouldIncludeBundleExecutable(for: target) {
            return [
                "CFBundleExecutable": "$(EXECUTABLE_NAME)",
            ]
        } else {
            return [:]
        }
    }

    private func shouldIncludeBundleExecutable(for target: Target) -> Bool {
        // Bundles on iOS, tvOS, and watchOS do not support sources so we exclude `CFBundleExecutable`
        if target.product != .bundle {
            return true
        }

        if !target.isExclusiveTo(.macOS) {
            return false
        }

        // For macOS, we should additionally check if there are sources in it
        let hasSources = !target.sources.isEmpty

        return hasSources
    }

    /// Returns the default Info.plist content that iOS apps should have.
    ///
    /// - Parameter iPadSupport: Wether the `iOS` application supports `iPadOS`.
    /// - Returns: Info.plist content.
    func iosApp(iPadSupport: Bool) -> [String: Any] {
        var baseInfo: [String: Any] = [
            "LSRequiresIPhoneOS": true,
            "UIRequiredDeviceCapabilities": [
                "armv7",
            ],
            "UISupportedInterfaceOrientations": [
                "UIInterfaceOrientationPortrait",
                "UIInterfaceOrientationLandscapeLeft",
                "UIInterfaceOrientationLandscapeRight",
            ],
            "UIApplicationSceneManifest": [
                "UIApplicationSupportsMultipleScenes": false,
                "UISceneConfigurations": [String: String](),
            ] as [String: Any],
        ]

        if iPadSupport {
            baseInfo["UISupportedInterfaceOrientations~ipad"] = [
                "UIInterfaceOrientationPortrait",
                "UIInterfaceOrientationPortraitUpsideDown",
                "UIInterfaceOrientationLandscapeLeft",
                "UIInterfaceOrientationLandscapeRight",
            ]
        }

        return baseInfo
    }

    /// Returns the default Info.plist content that macOS apps should have.
    ///
    /// - Returns: Info.plist content.
    func macosApp() -> [String: Any] {
        [
            "CFBundleIconFile": "",
            "LSMinimumSystemVersion": "$(MACOSX_DEPLOYMENT_TARGET)",
            "NSMainStoryboardFile": "Main",
            "NSPrincipalClass": "NSApplication",
        ]
    }

    /// Returns the default Info.plist content that macOS targets should have.
    ///
    /// - Returns: Info.plist content.
    func macos() -> [String: Any] {
        [
            "NSHumanReadableCopyright": "Copyright ©. All rights reserved.",
        ]
    }

    /// Returns the default Info.plist content for a watchOS App
    ///
    /// - Parameter name: Bundle display name
    /// - Parameter hostAppBundleId: The host application's bundle identifier
    private func watchosApp(name: String, hostAppBundleId: String?) -> [String: Any] {
        var infoPlist: [String: Any] = [
            "CFBundleDisplayName": name,
            "WKWatchKitApp": true,
            "UISupportedInterfaceOrientations": [
                "UIInterfaceOrientationPortrait",
                "UIInterfaceOrientationPortraitUpsideDown",
            ],
        ]
        if let hostAppBundleId {
            infoPlist["WKCompanionAppBundleIdentifier"] = hostAppBundleId
        }
        return infoPlist
    }

    /// Returns the default Info.plist content for a watchOS App Extension
    ///
    /// - Parameter name: Bundle display name
    /// - Parameter hostAppBundleId: The host application's bundle identifier
    private func watchosAppExtension(name: String, hostAppBundleId: String?) -> [String: Any] {
        let extensionAttributes: [String: Any] = hostAppBundleId.map { ["WKAppBundleIdentifier": $0] } ?? [:]
        return [
            "CFBundleDisplayName": name,
            "NSExtension": [
                "NSExtensionAttributes": extensionAttributes,
                "NSExtensionPointIdentifier": "com.apple.watchkit",
            ] as [String: Any],
            "WKExtensionDelegateClassName": "$(PRODUCT_MODULE_NAME).ExtensionDelegate",
        ]
    }

    /// Given a dictionary, it extends it with another dictionary.
    ///
    /// - Parameters:
    ///   - base: Dictionary to be extended.
    ///   - with: The content to extend the dictionary with.
    fileprivate func extend(_ base: inout [String: Any], with: [String: Any]) {
        with.forEach { base[$0.key] = $0.value }
    }

    private func hostTarget(for target: Target, in project: Project) -> Target? {
        project.targets.values.first {
            $0.dependencies.contains(where: { dependency in
                if case let .target(name, _, _) = dependency, name == target.name {
                    return true
                } else {
                    return false
                }
            })
        }
    }
}
