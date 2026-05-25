import XCTest

final class TodoAppUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
        // In UI tests it is usually best to stop immediately when a failure occurs.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testSignInFlow() throws {
        let app = XCUIApplication()
        app.launch()
        
        // This is a basic scaffold for UI testing.
        // Needs matching accessibility identifiers in SwiftUI views.
        let emailField = app.textFields["Email"]
        if emailField.exists {
            emailField.tap()
            emailField.typeText("test@test.com")
            
            let passwordField = app.secureTextFields["Password"]
            passwordField.tap()
            passwordField.typeText("password123")
            
            app.buttons["Sign In"].tap()
            
            // Wait for TaskList to appear
            XCTAssertTrue(app.navigationBars["My Tasks"].waitForExistence(timeout: 5))
        }
    }
}
