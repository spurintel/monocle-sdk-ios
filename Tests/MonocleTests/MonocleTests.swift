import XCTest
@testable import Monocle

final class MonocleTests: XCTestCase {
    func testDecryptedAssessmentDecoding() throws {
        // The example JSON string
        let json = """
        {
          "vpn": true,
          "proxied": false,
          "anon": true,
          "rdp": false,
          "dch": false,
          "cc": "US",
          "ip": "198.51.23.210",
          "ipv6": "2001:db8:e214:9f67:711:f03e:a141:3871",
          "ts": "2022-10-17T14:03:19-04:00",
          "complete": true,
          "id": "580f12c9-8030-4d49-b39f-35dfe560fa9e",
          "sid": "example-sign-up-form"
        }
        """
        
        // Convert the JSON string to Data
        guard let data = json.data(using: .utf8) else {
            XCTFail("Failed to convert JSON string to Data")
            return
        }
        
        // Create a JSONDecoder and set the date decoding strategy
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        do {
            // Decode the JSON data into a DecryptedAssessment instance
            let assessment = try decoder.decode(DecryptedAssessment.self, from: data)
            
            // Assert that all fields are decoded correctly
            XCTAssertEqual(assessment.vpn, true)
            XCTAssertEqual(assessment.proxied, false)
            XCTAssertEqual(assessment.anon, true)
            XCTAssertEqual(assessment.rdp, false)
            XCTAssertEqual(assessment.dch, false)
            XCTAssertEqual(assessment.cc, "US")
            XCTAssertEqual(assessment.ip, "198.51.23.210")
            XCTAssertEqual(assessment.ipv6, "2001:db8:e214:9f67:711:f03e:a141:3871")
            XCTAssertEqual(assessment.complete, true)
            XCTAssertEqual(assessment.id, "580f12c9-8030-4d49-b39f-35dfe560fa9e")
            XCTAssertEqual(assessment.sid, "example-sign-up-form")
            
            // Verify the timestamp
            let expectedDateComponents = DateComponents(
                calendar: Calendar(identifier: .gregorian),
                timeZone: TimeZone(secondsFromGMT: -4 * 3600),
                year: 2022,
                month: 10,
                day: 17,
                hour: 14,
                minute: 3,
                second: 19
            )
            if let expectedDate = expectedDateComponents.date {
                XCTAssertEqual(assessment.ts, expectedDate)
            } else {
                XCTFail("Failed to create expected date from components")
            }
            
        } catch {
            XCTFail("Decoding failed with error: \(error)")
        }
    }}
