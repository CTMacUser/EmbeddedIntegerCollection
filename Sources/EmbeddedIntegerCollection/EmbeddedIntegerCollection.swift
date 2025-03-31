/// A collection that stores its elements of some integer type as
/// segments of a larger integer type.
public struct EmbeddedIntegerCollection<Wrapped, Element>
where
  Wrapped: FixedWidthInteger & UnsignedInteger,
  Element: FixedWidthInteger & UnsignedInteger
{
  // I don't know how to insist that Wrapped.bitWidth has to
  // be a multiple of Element.bitWidth.

  /// The containing integer.
  @usableFromInline
  var word: Wrapped
  /// The sub-word to be treated as the first element.
  @usableFromInline
  let initialBitRange: EmbeddedIteratorDirection

  /// Creates a collection vending elements of the given type embedded in
  /// the given value,
  /// with the given flag indicating which bit range cap should be
  /// considered the first element.
  ///
  /// - Precondition: The bit length of `Wrapped` needs to be a multiple of
  ///   the bit length of `Element`.
  ///
  /// - Parameters:
  ///   - type: A metatype specifier for the `Element` type.
  ///     It does not need to be specified if the surrounding context already
  ///     locks it in.
  ///   - container: The initial value for the wrapping integer,
  ///     which determines the initial values of the embedded elements.
  ///     If not given,
  ///     zero will be used,
  ///     which sets all the embedded elements as zero too.
  ///   - bitRange: Whether the collection's first element should be taken from
  ///     the most-significant bit range,
  ///     or from the least significant.
  ///     Increasing indices will go towards the unselected range.
  @inlinable
  public init(
    embedding type: Element.Type = Element.self,
    within container: Wrapped = 0,
    iteratingFrom bitRange: EmbeddedIteratorDirection
  ) {
    word = container
    initialBitRange = bitRange
  }

  /// Creates a collection initially vending the maximum amount copies of
  /// the given value that can be embedded within the given type,
  /// notating which bit range cap should be considered the first element.
  ///
  /// - Precondition: The bit length of `Wrapped` needs to be a multiple of
  ///   the bit length of `Element`.
  ///
  /// - Parameters:
  ///   - element: The initial value for each embedded element.
  ///   - type: A metatype specifier for the `Wrapped` type.
  ///     It does not need to be specified if the surrounding context already
  ///     locks it in.
  ///   - bitRange: Whether the collection's first element should be taken from
  ///     the most-significant bit range,
  ///     or from the least significant.
  ///     Increasing indices will go towards the unselected range.
  @inlinable
  public init(
    repeating element: Element,
    embeddedIn type: Wrapped.Type = Wrapped.self,
    iteratingFrom bitRange: EmbeddedIteratorDirection
  ) {
    self.init(
      within: Wrapped(element) &* Self.allEmbeddedOnes, iteratingFrom: bitRange
    )
  }
}

/// Indicator for which direction embedded integer elements should be
/// read within their containing integer.
public enum EmbeddedIteratorDirection: Codable, Sendable, BitwiseCopyable {
  /// Use the highest sub-word as the first element.
  ///
  /// Subsequent elements will be at progressively lower bit offsets.
  case mostSignificantFirst
  /// Use the lowest sub-word as the first element.
  ///
  /// Subsequent elements will be at progressively higher bit offsets.
  case leastSignificantFirst
}

extension EmbeddedIteratorDirection: CaseIterable {}

// MARK: Base Behaviors

extension EmbeddedIntegerCollection: Equatable, Hashable {}

extension EmbeddedIntegerCollection: Encodable where Wrapped: Encodable {}
extension EmbeddedIntegerCollection: Decodable where Wrapped: Decodable {}

extension EmbeddedIntegerCollection: Sendable where Wrapped: Sendable {}
extension EmbeddedIntegerCollection: BitwiseCopyable
where Wrapped: BitwiseCopyable {}

// MARK: Printing

extension EmbeddedIntegerCollection: CustomStringConvertible {
  public var description: String {
    var result = "["
    print(
      lazy.map {
        String($0, radix: 16, uppercase: true)
      }.joined(separator: ", "),
      separator: "",
      terminator: "",
      to: &result
    )
    return result + "]"
  }
}

extension EmbeddedIntegerCollection: CustomDebugStringConvertible {
  public var debugDescription: String {
    var result = String(describing: Self.self)
    let hexValue = String(word, radix: 16, uppercase: true)
    switch initialBitRange {
    case .mostSignificantFirst:
      print("(*", hexValue, ")", separator: "", terminator: "", to: &result)
    case .leastSignificantFirst:
      print("(", hexValue, "*)", separator: "", terminator: "", to: &result)
    }
    return result
  }
}

// MARK: Collection Support

extension EmbeddedIntegerCollection: RandomAccessCollection, MutableCollection {
  // Each embedded element can be located by a bit range within
  // the wrapping integer.
  // All the elements use the same bit range width,
  // so the locations mainly differ by the offset of
  // each element's lowest-order bit from the lowest-order bit of
  // the wrapping integer.
  //
  // The index value is the bit offset for that element.
  // Simple comparisons work for iteration when starting from
  // the lowest-order bits and going upward.
  // Since `Index`'s comparison operators can't be (further) customized,
  // the solution when starting from the highest-order bits and
  // going downward is to use the negatives of the offsets.
  public typealias Index = Int

  // When this type was upgraded from `BidirectionalCollection` to
  // `RandomAccessCollection`,
  // the default `Indices` type changed,
  // but its implementation gave incompatible results,
  // so a custom type is required.
  public typealias Indices = EmbeddedIntegerCollectionIndices

  @inlinable
  public var startIndex: Index {
    switch initialBitRange {
    case .mostSignificantFirst:
      Element.bitWidth - Wrapped.bitWidth
    case .leastSignificantFirst:
      0
    }
  }
  @inlinable
  public var endIndex: Index {
    switch initialBitRange {
    case .mostSignificantFirst:
      Element.bitWidth
    case .leastSignificantFirst:
      Wrapped.bitWidth
    }
  }

  public subscript(position: Index) -> Element {
    get {
      return .init(truncatingIfNeeded: word >> abs(position))
    }
    set {
      let flipMask = self[position] ^ newValue
      word ^= Wrapped(flipMask) << abs(position)
    }
  }

  public mutating func swapAt(_ i: Int, _ j: Int) {
    let flipMask = Wrapped(self[i] ^ self[j])
    word ^= flipMask << abs(i) | flipMask << abs(j)
  }

  @inlinable
  public var indices: Indices {
    .init(every: Element.bitWidth, over: startIndex..<endIndex)
  }

  @inlinable
  public func index(after i: Index) -> Index {
    return indices.index(after: i)
  }
  @inlinable
  public func formIndex(after i: inout Int) {
    indices.formIndex(after: &i)
  }

  @inlinable
  public func index(before i: Index) -> Index {
    return indices.index(before: i)
  }
  @inlinable
  public func formIndex(before i: inout Int) {
    indices.formIndex(before: &i)
  }

  @inlinable
  public func index(_ i: Index, offsetBy distance: Int) -> Index {
    return indices.index(i, offsetBy: distance)
  }
  @inlinable
  public func index(_ i: Index, offsetBy distance: Int, limitedBy limit: Index)
    -> Index?
  {
    return indices.index(i, offsetBy: distance, limitedBy: limit)
  }
  @inlinable
  public func distance(from start: Index, to end: Index) -> Int {
    return indices.distance(from: start, to: end)
  }

  public func withContiguousStorageIfAvailable<R>(
    _ body: (UnsafeBufferPointer<Element>) throws -> R
  ) rethrows -> R? {
    var copy = self
    guard
      let result = try copy.withContiguousMutableStorageIfAvailable({ buffer in
        try body(.init(buffer))
      })
    else { return nil }

    assert(copy.word == word)  // Check against accidental mutation
    return result
  }
  public mutating func withContiguousMutableStorageIfAvailable<R>(
    _ body: (inout UnsafeMutableBufferPointer<Element>) throws -> R
  ) rethrows -> R? {
    guard Element.self is UInt8.Type else { return nil }
    guard word is _ExpressibleByBuiltinIntegerLiteral else { return nil }

    var storage =
      switch initialBitRange {
      case .mostSignificantFirst:
        word.bigEndian
      case .leastSignificantFirst:
        word.littleEndian
      }
    defer {
      word =
        switch initialBitRange {
        case .mostSignificantFirst:
          Wrapped(bigEndian: storage)
        case .leastSignificantFirst:
          Wrapped(littleEndian: storage)
        }
    }
    return try withUnsafeMutableBytes(of: &storage) { rawBuffer in
      return try rawBuffer.withMemoryRebound(to: Element.self) { buffer in
        var bufferCopy = buffer
        return try body(&bufferCopy)
      }
    }
  }
}

/// The `Indices` type for all `EmbeddedIntegerCollection` instantiations.
public struct EmbeddedIntegerCollectionIndices: RandomAccessCollection {
  /// The spacing between elements/indices.
  @usableFromInline
  let stride: Int

  public let startIndex: Int
  public let endIndex: Int

  /// Creates an index bundle over the given range,
  /// where the valid index values have the given spacing.
  ///
  /// - Precondition: Both bounds of `range` are multiples of `spacing`.
  ///   The value of `spacing` must be positive.
  ///
  /// - Parameters:
  ///   - spacing: The difference between the values of consecutive indices.
  ///   - range: The half-open bounds of this index bundle,
  ///     where the starting bound will be vended as the first value,
  ///     and no returned value will meet or exceed the ending bound.
  @inlinable
  init(every spacing: Int, over range: Range<Int>) {
    stride = spacing
    startIndex = range.lowerBound
    endIndex = range.upperBound
  }

  @inlinable
  public subscript(position: Int) -> Int {
    return position
  }
  @inlinable
  public subscript(bounds: Range<Int>) -> Self {
    return .init(every: stride, over: bounds)
  }

  @inlinable
  public func makeIterator() -> StrideToIterator<Int> {
    return Swift.stride(from: startIndex, to: endIndex, by: stride)
      .makeIterator()
  }

  @inlinable
  public func index(after i: Int) -> Int {
    return i + stride
  }
  @inlinable
  public func formIndex(after i: inout Int) {
    i += stride
  }

  @inlinable
  public func index(before i: Int) -> Int {
    return i - stride
  }
  @inlinable
  public func formIndex(before i: inout Int) {
    i -= stride
  }

  @inlinable
  public func index(_ i: Int, offsetBy distance: Int) -> Int {
    return i + distance * stride
  }
  public
    func index(_ i: Int, offsetBy distance: Int, limitedBy limit: Int) -> Int?
  {
    // The next two guards make the last one easier.
    guard distance != 0 else { return i }
    guard limit != i else { return nil }
    // Do `i + distance * stride` in a way that doesn't trap overflow.
    guard
      case let (bitDistance, overflow1) = distance.multipliedReportingOverflow(
        by: stride),
      case let (rawResult, overflow2) = i.addingReportingOverflow(bitDistance),
      !overflow1 && !overflow2
    else {
      // The magnitude of `distance` is WAY too big.
      return nil
    }
    // The `limit` does not apply if traversal went in the opposite direction.
    guard (distance < 0) == (limit < i) else { return rawResult }

    // Return the result if it doesn't blow past `limit`.
    if distance < 0 {
      return rawResult < limit ? nil : rawResult
    } else {
      return limit < rawResult ? nil : rawResult
    }
  }
  @inlinable
  public func distance(from start: Int, to end: Int) -> Int {
    return (end - start) / stride
  }

  @inlinable
  public var indices: Self { return self }

  public func _copyToContiguousArray() -> ContiguousArray<Int> {
    return .init(unsafeUninitializedCapacity: count) {
      buffer, initializedCount in
      for (sourceIndex, bufferIndex) in zip(indices, buffer.indices) {
        buffer.initializeElement(at: bufferIndex, to: sourceIndex)
        initializedCount += 1
      }
    }
  }

  @inlinable
  public func _customContainsEquatableElement(_ element: Int) -> Bool? {
    return .some(
      startIndex..<endIndex ~= element
        && (element - startIndex).isMultiple(of: stride)
    )
  }
  @inlinable
  public func _customIndexOfEquatableElement(_ element: Int) -> Int?? {
    return .some(
      _customContainsEquatableElement(element)! ? .some(element) : .none
    )
  }
  @inlinable
  public func _customLastIndexOfEquatableElement(_ element: Int) -> Int?? {
    return _customIndexOfEquatableElement(element)
  }
}

extension EmbeddedIntegerCollectionIndices: Equatable, Hashable, Codable,
  Sendable, BitwiseCopyable
{}

// MARK: More Initializers

extension EmbeddedIntegerCollection {
  /// Creates a collection wrapping an instance of the given integer type,
  /// where the integer's initial value embeds elements taken from
  /// the given iterator's virtual sequence,
  /// notating which bit range cap stores the first element.
  ///
  /// - Precondition: The bit length of `Wrapped` needs to be a multiple of
  ///   the bit length of `Element`.
  ///
  /// - Parameters:
  ///   - iterator: The source for the embedded elements' values.
  ///   - type: A metatype specifier for the `Wrapped` type.
  ///     It does not need to be specified if the surrounding context already
  ///     locks it in.
  ///   - bitRange: Whether the collection's first element should be embedded at
  ///     the most- or least-significant bit range of the wrapping integer.
  /// - Postcondition: This initializer fails if the `iterator` cannot
  ///   supply enough elements.
  ///   The count of elements extracted from the `iterator` will be the
  ///   minimum between its virtual sequence's length and the number of
  ///   elements supported by this collection type.
  @inlinable
  public init?<T: IteratorProtocol<Element>>(
    extractingFrom iterator: inout T,
    embeddingInto type: Wrapped.Type = Wrapped.self,
    fillingFrom bitRange: EmbeddedIteratorDirection
  ) {
    self.init(iteratingFrom: bitRange)

    // Fill up the wrapping word from the most-significant element down.
    var remainingElements = count
    while remainingElements > 0, let nextEmbeddedElement = iterator.next() {
      word <<= Element.bitWidth
      word |= Wrapped(nextEmbeddedElement)
      remainingElements -= 1
    }
    guard remainingElements == 0 else { return nil }

    // Flip the elements if the starting bit range is wrong.
    if bitRange == .leastSignificantFirst, !isEmpty {
      var first = startIndex
      var last = index(before: endIndex)
      while first < last {
        swapAt(first, last)
        formIndex(after: &first)
        formIndex(before: &last)
      }
    }
  }

  /// Creates a collection wrapping an instance of the given integer type,
  /// where the integer's initial value embeds elements taken from
  /// the prefix of the given sequence,
  /// notating which bit range cap stores the first element.
  ///
  /// - Precondition: The bit length of `Wrapped` needs to be a multiple of
  ///   the bit length of `Element`.
  ///
  /// If access to the elements of the `sequence` after what's needed to
  /// fill this collection is required,
  /// use the iterator-based `init(extractingFrom:embeddingInto:fillingFrom:)`
  /// instead.
  ///
  /// - Parameters:
  ///   - sequence: The source for the embedded elements' values.
  ///   - type: A metatype specifier for the `Wrapped` type.
  ///     It does not need to be specified if the surrounding context already
  ///     locks it in.
  ///   - readAll: Whether every element of the `sequence` needs to
  ///     be copied into this collection (i.e. not a strict prefix).
  ///   - bitRange: Whether the collection's first element should be embedded at
  ///     the most- or least-significant bit range of the wrapping integer.
  /// - Postcondition: This initializer fails if the `sequence` cannot
  ///   supply enough elements.
  ///   It also fails if `readAll` is `true` while the `sequence` has extra
  ///   elements after filling this collection.
  @inlinable
  public init?<T: Sequence<Element>>(
    readingFrom sequence: T,
    embeddingInto type: Wrapped.Type = Wrapped.self,
    requireEverythingRead readAll: Bool,
    fillingFrom bitRange: EmbeddedIteratorDirection
  ) {
    var iterator = sequence.makeIterator()
    self.init(
      extractingFrom: &iterator, embeddingInto: type, fillingFrom: bitRange
    )
    guard !readAll || iterator.next() == nil else { return nil }
  }
}

// MARK: - Bit Manipulation Helpers

extension EmbeddedIntegerCollection {
  // Adapted from "Bit Twiddling Hacks" at
  // <https://graphics.stanford.edu/~seander/bithacks.html>.

  /// Generates a collection with every element having a value of one.
  ///
  /// This can be multipled by an `Element` value to spread that value to
  /// every embedded element.
  @usableFromInline
  static var allEmbeddedOnes: Wrapped { Wrapped.max / Wrapped(Element.max) }
}
