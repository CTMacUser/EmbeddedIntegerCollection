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
      ? .mostSignificantFirst
      : .leastSignificantFirst
  )
  #expect(
    String(reflecting: collection) == "\(type(of: collection))(\(expected))"
  )
}

@Test("Repeating-element initializer")
func repeatingInitializer() async throws {
  let collection1 = EmbeddedIntegerCollection.init(
    repeating: 0 as UInt16, embeddedIn: UInt64.self,
    iteratingFrom: .mostSignificantFirst)
  let collection2 = EmbeddedIntegerCollection(
    embedding: UInt16.self, within: 0 as UInt64,
    iteratingFrom: .mostSignificantFirst)
  #expect(collection1 == collection2)

  let collection3 = EmbeddedIntegerCollection(
    embedding: UInt8.self, within: 0x6F6F_6F6F as UInt32,
    iteratingFrom: .leastSignificantFirst)
  let collection4 = EmbeddedIntegerCollection(
    repeating: 0x6F as UInt8, embeddedIn: UInt32.self,
    iteratingFrom: .leastSignificantFirst)
  #expect(collection3 == collection4)
}
