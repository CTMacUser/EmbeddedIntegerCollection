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

@Test(
  "Basic Sequence/Collection support",
  arguments: zip(
    [
      (0x4142_4344, true),
      (0x4142_4344, false),
    ],
    [
      [0x41, 0x42, 0x43, 0x44],
      [0x44, 0x43, 0x42, 0x41],
    ]
  )
)
func basicCollections(
  _ input: (base: UInt32, isBigEndian: Bool), expected: [UInt8]
) async throws {
  // Sequence (and indirectly Collection)
  var collection = EmbeddedIntegerCollection(
    embedding: UInt8.self, within: input.base,
    iteratingFrom: input.isBigEndian
      ? .mostSignificantFirst
      : .leastSignificantFirst
  )
  #expect(AnySequence(collection).elementsEqual(expected))

  // MutableCollection
  let sentinelValue: UInt8 = 0x9F
  try #require(expected.count >= 2 && expected[1] != sentinelValue)

  let secondIndex = collection.index(after: collection.startIndex)
  let newExpected = [expected.first!] + [sentinelValue] + expected[2...]
  collection[secondIndex] = sentinelValue
  #expect(collection.elementsEqual(newExpected))

  // BidirectionalCollection
  #expect(
    collection.indices.lazy.reversed().map {
      collection[$0]
    }.elementsEqual(newExpected.reversed())
  )
}
