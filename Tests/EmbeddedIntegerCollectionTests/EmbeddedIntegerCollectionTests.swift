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
  #expect(!collection.isEmpty)

  // In-place index updating
  var dummy = collection.startIndex
  try #require(expected.count >= 2)  // `collection.count` saved for RAC tests

  let secondIndex = collection.index(after: dummy)
  collection.formIndex(after: &dummy)
  #expect(dummy == secondIndex)

  // MutableCollection
  let sentinelValue: UInt8 = 0x9F
  try #require(expected[1] != sentinelValue)

  let newExpected = [expected.first!] + [sentinelValue] + expected[2...]
  collection[secondIndex] = sentinelValue
  #expect(collection.elementsEqual(newExpected))

  // BidirectionalCollection
  #expect(collection.reversed().elementsEqual(newExpected.reversed()))

  #expect(collection.index(before: dummy) == collection.startIndex)
  collection.formIndex(before: &dummy)
  #expect(dummy == collection.startIndex)

  // RandomAcessCollection
  #expect(collection.count == newExpected.count)

  // (The `Array(collectionIndices)` operand triggers the indices-type's
  // `_copyToContiguousArray` method.)
  let collectionIndices = collection.indices
  let validIndices = Array(collectionIndices) + [collection.endIndex]
  let invalidIndices = [nil] + validIndices.map(Optional.init(_:)) + [nil]
  var expectedLow = 0
  var expectedHigh = validIndices.count
  for start in validIndices {
    defer {
      expectedLow -= 1
      expectedHigh -= 1
    }
    let distances = validIndices.map {
      collection.distance(from: start, to: $0)
    }
    #expect(distances.elementsEqual(expectedLow..<expectedHigh))

    let newIndices = distances.map { collection.index(start, offsetBy: $0) }
    #expect(newIndices.elementsEqual(validIndices))

    let invalidDistances = [expectedLow - 1] + distances + [expectedHigh + 1]
    let newInvalidIndices = invalidDistances.map {
      collection.index(
        start,
        offsetBy: $0,
        limitedBy: $0 < 0 ? collection.startIndex : collection.endIndex
      )
    }
    #expect(newInvalidIndices.elementsEqual(invalidIndices))
  }
}

@Test(
  "More random-access index checks",
  arguments: EmbeddedIteratorDirection.allCases
)
func moreIndexChecks(_ startingBitRange: EmbeddedIteratorDirection) async throws
{
  let collection = EmbeddedIntegerCollection(
    embedding: UInt8.self, within: 0 as UInt64, iteratingFrom: startingBitRange
  )
  let collectionIndices = collection.indices

  // Invalid index values
  let goodIndex = collection.startIndex
  #expect(collectionIndices.contains(goodIndex))
  #expect(collectionIndices.firstIndex(of: goodIndex) == goodIndex)
  #expect(collectionIndices.lastIndex(of: goodIndex) == goodIndex)

  let badIndex = collectionIndices.index(before: goodIndex)
  #expect(!collectionIndices.contains(badIndex))
  #expect(collectionIndices.firstIndex(of: badIndex) == nil)
  #expect(collectionIndices.lastIndex(of: badIndex) == nil)

  let worseIndex = goodIndex + 1
  #expect(!collectionIndices.contains(worseIndex))
  #expect(collectionIndices.firstIndex(of: worseIndex) == nil)
  #expect(collectionIndices.lastIndex(of: worseIndex) == nil)

  // No limits going in the wrong direction
  let secondIndex = collection.index(after: goodIndex)
  let thirdIndex = collection.index(after: secondIndex)
  #expect(
    collection.index(thirdIndex, offsetBy: -2, limitedBy: secondIndex) == nil
  )
  #expect(
    collection.index(thirdIndex, offsetBy: -2, limitedBy: collection.endIndex)
      == collection.startIndex
  )

  // Over-sized distances
  #expect(
    collection.index(
      goodIndex, offsetBy: .max, limitedBy: collection.endIndex
    ) == nil
  )

  // Subscripting, single and sub-sequences
  let subIndices = collectionIndices[goodIndex..<thirdIndex]
  #expect(subIndices.elementsEqual([goodIndex, secondIndex]))
  #expect(collectionIndices[goodIndex] == goodIndex)
  #expect(subIndices[secondIndex] == secondIndex)

  // Compare manual visitation versus the optimized iterator support.
  var manualIndices = [Int]()
  var manualIndex = goodIndex
  manualIndices.reserveCapacity(collectionIndices.count)
  while manualIndex < collectionIndices.endIndex {
    manualIndices.append(manualIndex)
    collectionIndices.formIndex(after: &manualIndex)
  }
  #expect(manualIndices.elementsEqual(collectionIndices))
}

@Test("Element swapping", arguments: EmbeddedIteratorDirection.allCases)
func elementSwap(_ startingBitRange: EmbeddedIteratorDirection) async throws {
  var collection = EmbeddedIntegerCollection<UInt32, UInt8>(
    iteratingFrom: startingBitRange
  )
  let firstIndex = collection.startIndex
  let secondIndex = collection.index(after: firstIndex)
  let thirdIndex = collection.index(after: secondIndex)
  let fourthIndex = collection.index(after: thirdIndex)
  assert(collection.index(after: fourthIndex) == collection.endIndex)
  collection[firstIndex] = 0x40
  collection[secondIndex] = 0x41
  collection[thirdIndex] = 0x42
  collection[fourthIndex] = 0x43

  #expect(collection.elementsEqual([0x40, 0x41, 0x42, 0x43]))
  collection.swapAt(secondIndex, secondIndex)
  #expect(collection.elementsEqual([0x40, 0x41, 0x42, 0x43]))
  collection.swapAt(firstIndex, thirdIndex)
  #expect(collection.elementsEqual([0x42, 0x41, 0x40, 0x43]))
  collection.swapAt(firstIndex, thirdIndex)
  #expect(collection.elementsEqual([0x40, 0x41, 0x42, 0x43]))
  collection.swapAt(fourthIndex, secondIndex)
  #expect(collection.elementsEqual([0x40, 0x43, 0x42, 0x41]))
}
