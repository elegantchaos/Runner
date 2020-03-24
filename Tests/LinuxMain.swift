import XCTest

import RunnerTests

var tests = [XCTestCaseEntry]()
tests += RunnerTests.__allTests()

XCTMain(tests)
