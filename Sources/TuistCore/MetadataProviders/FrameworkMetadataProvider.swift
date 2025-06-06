import FileSystem
import Foundation
import Path
import TuistSupport
import XcodeGraph

// MARK: - Provider Errors

enum FrameworkMetadataProviderError: FatalError, Equatable {
    case frameworkNotFound(AbsolutePath)

    // MARK: - FatalError

    var description: String {
        switch self {
        case let .frameworkNotFound(path):
            return "Couldn't find framework at \(path.pathString)"
        }
    }

    var type: ErrorType {
        switch self {
        case .frameworkNotFound:
            return .abort
        }
    }
}

// MARK: - Provider

public protocol FrameworkMetadataProviding: PrecompiledMetadataProviding {
    /// Loads all the metadata associated with a framework at the specified path
    /// - Note: This performs various shell calls and disk operations
    func loadMetadata(at path: AbsolutePath, status: LinkingStatus) async throws -> FrameworkMetadata

    /// Given the path to a framework, it returns the path to its dSYMs if they exist
    /// in the same framework directory.
    /// - Parameter frameworkPath: Path to the .framework directory.
    func dsymPath(frameworkPath: AbsolutePath) async throws -> AbsolutePath?

    /// Given the path to a framework, it returns the list of .bcsymbolmap files that
    /// are associated to the framework and that are present in the same directory.
    /// - Parameter frameworkPath: Path to the .framework directory.
    func bcsymbolmapPaths(frameworkPath: AbsolutePath) async throws -> [AbsolutePath]

    /// Returns the product for the framework at the given path.
    /// - Parameter frameworkPath: Path to the .framework directory.
    func product(frameworkPath: AbsolutePath) throws -> Product
}

// MARK: - Default Implementation

public final class FrameworkMetadataProvider: PrecompiledMetadataProvider, FrameworkMetadataProviding {
    private let fileSystem: FileSysteming

    public init(
        fileSystem: FileSysteming = FileSystem()
    ) {
        self.fileSystem = fileSystem
        super.init()
    }

    public func loadMetadata(at path: AbsolutePath, status: LinkingStatus) async throws -> FrameworkMetadata {
        guard try await fileSystem.exists(path) else {
            throw FrameworkMetadataProviderError.frameworkNotFound(path)
        }
        let binaryPath = binaryPath(frameworkPath: path)
        let dsymPath = try await dsymPath(frameworkPath: path)
        let bcsymbolmapPaths = try await bcsymbolmapPaths(frameworkPath: path)
        let linking = try linking(binaryPath: binaryPath)
        let architectures = try architectures(binaryPath: binaryPath)
        return FrameworkMetadata(
            path: path,
            binaryPath: binaryPath,
            dsymPath: dsymPath,
            bcsymbolmapPaths: bcsymbolmapPaths,
            linking: linking,
            architectures: architectures,
            status: status
        )
    }

    public func dsymPath(frameworkPath: AbsolutePath) async throws -> AbsolutePath? {
        let path = try AbsolutePath(validating: "\(frameworkPath.pathString).dSYM")
        if try await fileSystem.exists(path) { return path }
        return nil
    }

    public func bcsymbolmapPaths(frameworkPath: AbsolutePath) async throws -> [AbsolutePath] {
        let binaryPath = binaryPath(frameworkPath: frameworkPath)
        let uuids = try uuids(binaryPath: binaryPath)
        return try await uuids
            .map { frameworkPath.parentDirectory.appending(component: "\($0).bcsymbolmap") }
            .concurrentFilter { try await self.fileSystem.exists($0) }
            .sorted()
    }

    public func product(frameworkPath: AbsolutePath) throws -> Product {
        let binaryPath = binaryPath(frameworkPath: frameworkPath)
        switch try linking(binaryPath: binaryPath) {
        case .dynamic:
            return .framework
        case .static:
            return .staticFramework
        }
    }

    private func binaryPath(frameworkPath: AbsolutePath) -> AbsolutePath {
        frameworkPath.appending(component: frameworkPath.basenameWithoutExt)
    }
}

#if DEBUG
    public final class MockFrameworkMetadataProvider: MockPrecompiledMetadataProvider, FrameworkMetadataProviding {
        public var loadMetadataStub: ((AbsolutePath) throws -> FrameworkMetadata)?
        public func loadMetadata(at path: AbsolutePath, status: LinkingStatus) throws -> FrameworkMetadata {
            if let loadMetadataStub {
                return try loadMetadataStub(path)
            } else {
                return FrameworkMetadata.test(path: path, status: status)
            }
        }

        public var dsymPathStub: ((AbsolutePath) throws -> AbsolutePath?)?
        public func dsymPath(frameworkPath: AbsolutePath) throws -> AbsolutePath? {
            try dsymPathStub?(frameworkPath) ?? nil
        }

        public var bcsymbolmapPathsStub: ((AbsolutePath) throws -> [AbsolutePath])?
        public func bcsymbolmapPaths(frameworkPath: AbsolutePath) throws -> [AbsolutePath] {
            if let bcsymbolmapPathsStub {
                return try bcsymbolmapPathsStub(frameworkPath)
            } else {
                return []
            }
        }

        public var productStub: ((AbsolutePath) throws -> Product)?
        public func product(frameworkPath: AbsolutePath) throws -> Product {
            if let productStub {
                return try productStub(frameworkPath)
            } else {
                return .framework
            }
        }
    }
#endif
