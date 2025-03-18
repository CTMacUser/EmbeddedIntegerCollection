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

// MARK: Base Behaviors

extension EmbeddedIntegerCollection: Equatable, Hashable {}

extension EmbeddedIntegerCollection: Encodable where Wrapped: Encodable {}
extension EmbeddedIntegerCollection: Decodable where Wrapped: Decodable {}

extension EmbeddedIntegerCollection: Sendable where Wrapped: Sendable {}
extension EmbeddedIntegerCollection: BitwiseCopyable
where Wrapped: BitwiseCopyable {}

// MARK: Debugging

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

extension EmbeddedIntegerCollection: MutableCollection {
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

  public var startIndex: Index {
    switch initialBitRange {
    case .mostSignificantFirst:
      Element.bitWidth - Wrapped.bitWidth
    case .leastSignificantFirst:
      0
    }
  }
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

  public func index(after i: Index) -> Index {
    return i + Element.bitWidth
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
