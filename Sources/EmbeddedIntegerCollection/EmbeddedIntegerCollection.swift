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
