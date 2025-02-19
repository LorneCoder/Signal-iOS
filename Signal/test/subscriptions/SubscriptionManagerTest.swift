//
//  Copyright (c) 2022 Open Whisper Systems. All rights reserved.
//

import XCTest

class SubscriptionChargeFailureTest: XCTestCase {
    typealias ChargeFailure = Subscription.ChargeFailure

    func testNilInit() {
        let chargeFailure = ChargeFailure()
        XCTAssertNil(chargeFailure.code)
    }

    func testStringInit() {
        let chargeFailure = ChargeFailure(code: "foo bar")
        XCTAssertEqual(chargeFailure.code, "foo bar")
    }

    func testJsonInit() {
        let chargeFailure = ChargeFailure(jsonDictionary: ["code": "foo"])
        XCTAssertEqual(chargeFailure.code, "foo")

        let strangeInputs: [[String: Any]] = [[:], ["no code": "missing"], ["code": 123]]
        for jsonDictionary in strangeInputs {
            let chargeFailure = ChargeFailure(jsonDictionary: jsonDictionary)
            XCTAssertNil(chargeFailure.code)
        }
    }
}

class SubscriptionTest: XCTestCase {
    let subscriptionDict: [String: Any] = {
        let endOfCurrentPeriodRawValue: Double = 1618881836
        let billingCycleAnchorRawValue: Double = 1587345836
        return [
            "level": 123,
            "currency": "USD",
            "amount": 500,
            "endOfCurrentPeriod": endOfCurrentPeriodRawValue,
            "billingCycleAnchor": billingCycleAnchorRawValue,
            "active": true,
            "cancelAtPeriodEnd": false,
            "status": "active"
        ]
    }()

    func testJsonInit() throws {
        let subscription = try Subscription(subscriptionDict: subscriptionDict,
                                            chargeFailureDict: nil)

        XCTAssertEqual(subscription.level, 123)
        XCTAssertEqual(subscription.currency, "USD")
        XCTAssertEqual(subscription.amount, 500)
        XCTAssertEqual(subscription.endOfCurrentPeriod, 1618881836)
        XCTAssertEqual(subscription.billingCycleAnchor, 1587345836)
        XCTAssertTrue(subscription.active)
        XCTAssertFalse(subscription.cancelAtEndOfPeriod)
        XCTAssertEqual(subscription.status, .active)
        XCTAssertNil(subscription.chargeFailure)
    }

    func testJsonInitWithUnexpectedStatus() throws {
        var subscriptionDictWithUnexpectedStatus = subscriptionDict
        subscriptionDictWithUnexpectedStatus["status"] = "unexpected!!"

        let subscription = try Subscription(subscriptionDict: subscriptionDictWithUnexpectedStatus,
                                            chargeFailureDict: nil)

        XCTAssertEqual(subscription.status, .unknown)
        XCTAssertNil(subscription.chargeFailure)
    }

    func testChargeFailure() throws {
        let subscription = try Subscription(subscriptionDict: subscriptionDict,
                                            chargeFailureDict: ["code": "foo bar"])
        XCTAssertEqual(subscription.chargeFailure?.code, "foo bar")

        let strangeChargeFailures: [[String: Any]] = [[:], ["no code": "missing"], ["code": 123]]
        for chargeFailureDict in strangeChargeFailures {
            let subscription = try Subscription(subscriptionDict: subscriptionDict,
                                                chargeFailureDict: chargeFailureDict)
            XCTAssertNotNil(subscription.chargeFailure)
            XCTAssertNil(subscription.chargeFailure?.code)
        }
    }
}
