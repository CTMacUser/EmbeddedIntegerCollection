import Testing

@testable import EmbeddedIntegerCollection

@Test(
  "Debug printing",
  arguments: zip(
    [
      (0, true),
      (0, false),
      (.max, true),
      (.max, false),
    ],
    [
      "*0",
      "0*",
      "*FFFFFFFFFFFFFFFF",
      "FFFFFFFFFFFFFFFF*",
    ]
  )
)
func debugPrint(_ input: (base: UInt64, isBigEndian: Bool), expected: String)
  async throws
{
  let collection = EmbeddedIntegerCollection(
    embedding: UInt16.self, within: input.base,
    iteratingFrom: input.isBigEndian
      ? .mostSignificantFirst : .leastSignificantFirst
  )
  #expect(
    String(reflecting: collection) == "\(type(of: collection))(\(expected))"
  )
}
