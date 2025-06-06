import Foundation
import Mockable
import TuistLoader
import TuistServer
import TuistTesting
import XCTest

@testable import TuistKit

final class OrganizationRemoveSSOServiceTests: TuistUnitTestCase {
    private var updateOrganizationService: MockUpdateOrganizationServicing!
    private var subject: OrganizationRemoveSSOService!
    private var configLoader: MockConfigLoading!
    private var serverURL: URL!

    override func setUp() {
        super.setUp()

        updateOrganizationService = .init()
        configLoader = MockConfigLoading()
        serverURL = URL(string: "https://test.tuist.dev")!
        given(configLoader).loadConfig(path: .any).willReturn(.test(url: serverURL))

        subject = OrganizationRemoveSSOService(
            updateOrganizationService: updateOrganizationService,
            configLoader: configLoader
        )
    }

    override func tearDown() {
        updateOrganizationService = nil
        configLoader = nil
        subject = nil

        super.tearDown()
    }

    func test_organization_remove_sso() async throws {
        try await withMockedDependencies {
            // Given
            given(updateOrganizationService)
                .updateOrganization(
                    organizationName: .value("tuist"),
                    serverURL: .value(serverURL),
                    ssoOrganization: .value(nil)
                )
                .willReturn(.test())

            // When
            try await subject.run(
                organizationName: "tuist",
                directory: nil
            )

            // Then
            XCTAssertPrinterOutputContains(
                """
                SSO for tuist was removed.
                """
            )
        }
    }
}
