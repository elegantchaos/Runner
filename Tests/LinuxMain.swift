import XCTest

import RunnerTests

var tests = [XCTestCaseEntry]()
tests += RunnerTests.allTests()
XCTMain(tests)