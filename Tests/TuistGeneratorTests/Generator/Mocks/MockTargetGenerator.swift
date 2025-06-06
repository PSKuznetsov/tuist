import Foundation
import Path
import TuistCore
import TuistSupport
import XcodeGraph
import XcodeProj
@testable import TuistGenerator

class MockTargetGenerator: TargetGenerating {
    var generateTargetStub: (() -> PBXNativeTarget)?

    func generateTarget(
        target: Target,
        project _: Project,
        pbxproj _: PBXProj,
        pbxProject _: PBXProject,
        projectSettings _: Settings,
        fileElements _: ProjectFileElements,
        path _: AbsolutePath,
        graphTraverser _: GraphTraversing
    ) throws -> PBXNativeTarget {
        generateTargetStub?() ?? PBXNativeTarget(name: target.name)
    }

    func generateTargetDependencies(
        path _: AbsolutePath,
        targets _: [Target],
        nativeTargets _: [String: PBXNativeTarget],
        graphTraverser _: GraphTraversing
    ) throws {}
}
