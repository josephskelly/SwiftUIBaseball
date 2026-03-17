//
//  GameDetailViewTests.swift
//  SwiftUIBaseballTests
//

import Testing
@testable import SwiftUIBaseball

// MARK: - formatOPS

struct FormatOPSTests {

    @Test func belowOne() {
        #expect(formatOPS(0.850) == ".850 OPS")
    }

    @Test func exactlyOne() {
        #expect(formatOPS(1.000) == "1.000 OPS")
    }

    @Test func aboveOne() {
        #expect(formatOPS(1.036) == "1.036 OPS")
    }

    @Test func zero() {
        #expect(formatOPS(0.0) == ".000 OPS")
    }

    @Test func leadingZeroPreserved() {
        // .050 should not become ".50 OPS"
        #expect(formatOPS(0.050) == ".050 OPS")
    }

    @Test func nearBoundary() {
        #expect(formatOPS(0.999) == ".999 OPS")
    }

    @Test func eliteOPS() {
        #expect(formatOPS(1.116) == "1.116 OPS")
    }
}

// MARK: - abbreviatedName

struct AbbreviatedNameTests {

    @Test func twoPartName() {
        #expect(abbreviatedName("Aaron Judge") == "A. Judge")
    }

    @Test func twoPartNameOhtani() {
        #expect(abbreviatedName("Shohei Ohtani") == "S. Ohtani")
    }

    @Test func singleName() {
        // No space → returned unchanged
        #expect(abbreviatedName("Ohtani") == "Ohtani")
    }

    @Test func threePartName() {
        // Uses first initial and last word
        #expect(abbreviatedName("José de la Cruz") == "J. Cruz")
    }

    @Test func hyphenatedLastName() {
        #expect(abbreviatedName("Corbin Burnes") == "C. Burnes")
    }

    @Test func emptyString() {
        #expect(abbreviatedName("") == "")
    }
}
