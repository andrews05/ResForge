//
//  BinaryData.swift
//  BinaryData
//
//  Created by Łukasz Kwoska on 08.12.2015.
//  Copyright © 2015 Macoscope Sp. z o.o. All rights reserved.
//

import Foundation

/**
 Structure for fast/immutable parsing of binary file.
 */
public struct BinaryData : ExpressibleByArrayLiteral {
  public typealias Element = UInt8
  ///Underlying data for this object.
  public let data: [UInt8]
  ///Is data in big-endian byte order?
  public let bigEndian: Bool
  
  // MARK: - Initializers
  
  /**
   Initialize with array literal
   
   You may initialize `BinaryData` with array literal like so:
   ```
   let data:BinaryData = [0xf, 0x00, 0x1, 0xa]
   ```
   
   - parameter data: `NSData` to parse
   - parameter bigEndian: Is data in big-endian or little-endian order?
   
   - returns: Initialized object
   
   - remark: Data is copied.
   */
  public init(arrayLiteral elements: Element...) {
    data = elements
    bigEndian = true
  }
  
  /**
   Initialize with array
   
   - parameter data: `Array` containing data to parse
   - parameter bigEndian: Is data in big-endian or little-endian order?
   
   - returns: Initialized object
   
   - remark: Data is copied.
   */
  
  public init(data: [UInt8], bigEndian: Bool = true) {
    self.data = data
    self.bigEndian = bigEndian
  }
  
  /**
   Initialize with `NSData`
   
   - parameter data: `NSData` to parse
   - parameter bigEndian: Is data in big-endian or little-endian order?
   
   - returns: Initialized object
   
   - remark: Data is copied.
   */
  public init(data:Data, bigEndian: Bool = true) {
    
    self.bigEndian = bigEndian
    
    var mutableData = [UInt8](repeating: 0, count: data.count)
    if data.count > 0 {
      (data as NSData).getBytes(&mutableData, length: data.count)
    }
    self.data = mutableData
  }
  
  // MARK: - Simple data types
  
  /**
   Parse `UInt8` from underlying data.
   
   - parameter offset: Offset in bytes from this value should be read
   - parameter bigEndian: Is data in big-endian or little-endian order? If this parameter may is ommited, than `BinaryData`
   setting is used.
   
   - returns: `UInt8` representation of byte at offset.
   - throws: `BinaryDataErrors.NotEnoughData` if there is not enough data.
   */
  public func get(_ offset: Int, bigEndian: Bool? = nil) throws -> UInt8 {
    guard offset < data.count else { throw BinaryDataErrors.notEnoughData }
    return data[offset]
  }
  
  /**
   Parse `UInt16` from underlying data.
   
   - parameter offset: Offset in bytes from this value should be read
   - parameter bigEndian: Is data in big-endian or little-endian order? If this parameter may is ommited, than `BinaryData`
   setting is used.
   
   - returns: `UInt16` representation of byte at offset.
   - throws: `BinaryDataErrors.NotEnoughData` if there is not enough data.
   */
  public func get(_ offset: Int, bigEndian: Bool? = nil) throws -> UInt16 {
    guard offset + 1 < data.count else { throw BinaryDataErrors.notEnoughData }
    return UInt16.join((data[offset], data[offset + 1]),
                       bigEndian: bigEndian ?? self.bigEndian)
  }
  
  /**
   Parse `UInt32` from underlying data.
   
   - parameter offset: Offset in bytes from this value should be read
   - parameter bigEndian: Is data in big-endian or little-endian order? If this parameter may is ommited, than `BinaryData`
   setting is used.
   
   - returns: `UInt32` representation of byte at offset.
   - throws: `BinaryDataErrors.NotEnoughData` if there is not enough data.
   */
  public func get(_ offset: Int, bigEndian: Bool? = nil) throws -> UInt32 {
    guard offset + 3 < data.count else { throw BinaryDataErrors.notEnoughData }
    return UInt32.join((data[offset], data[offset + 1], data[offset + 2], data[offset + 3]),
                       bigEndian: bigEndian ?? self.bigEndian)
  }
  
  /**
   Parse `UInt64` from underlying data.
   
   - parameter offset: Offset in bytes from this value should be read
   - parameter bigEndian: Is data in big-endian or little-endian order? If this parameter may is ommited, than `BinaryData`
   setting is used.
   
   - returns: `UInt64` representation of byte at offset.
   - throws: `BinaryDataErrors.NotEnoughData` if there is not enough data.
   */
  public func get(_ offset: Int, bigEndian: Bool? = nil) throws -> UInt64 {
    guard offset + 7 < data.count else { throw BinaryDataErrors.notEnoughData }
    return UInt64.join((data[offset], data[offset + 1], data[offset + 2], data[offset + 3],
      data[offset + 4], data[offset + 5], data[offset + 6], data[offset + 7]),
                       bigEndian: bigEndian ?? self.bigEndian)  }
  
  /**
   Parse `Int8` from underlying data.
   
   - parameter offset: Offset in bytes from this value should be read
   - parameter bigEndian: Is data in big-endian or little-endian order? If this parameter may is ommited, than `BinaryData`
   setting is used.
   
   - returns: `Int8` representation of byte at offset.
   - throws: `BinaryDataErrors.NotEnoughData` if there is not enough data.
   */
  public func get(_ offset: Int, bigEndian: Bool? = nil) throws -> Int8 {
    let uint: UInt8 = try get(offset, bigEndian: bigEndian ?? self.bigEndian)
    return Int8(bitPattern: uint)
  }
  
  /**
   Parse `Int16` from underlying data.
   
   - parameter offset: Offset in bytes from this value should be read
   - parameter bigEndian: Is data in big-endian or little-endian order? If this parameter may is ommited, than `BinaryData`
   setting is used.
   
   - returns: `Int16` representation of byte at offset.
   - throws: `BinaryDataErrors.NotEnoughData` if there is not enough data.
   */
  public func get(_ offset: Int, bigEndian: Bool? = nil) throws -> Int16 {
    let uint:UInt16 = try get(offset, bigEndian: bigEndian ?? self.bigEndian)
    return Int16(bitPattern: uint)
  }
  
  /**
   Parse `Int32` from underlying data.
   
   - parameter offset: Offset in bytes from this value should be read
   - parameter bigEndian: Is data in big-endian or little-endian order? If this parameter may is ommited, than `BinaryData`
   setting is used.
   
   - returns: `Int32` representation of byte at offset.
   - throws: `BinaryDataErrors.NotEnoughData` if there is not enough data.
   */
  public func get(_ offset: Int, bigEndian: Bool? = nil) throws -> Int32 {
    let uint:UInt32 = try get(offset, bigEndian: bigEndian ?? self.bigEndian)
    return Int32(bitPattern: uint)
  }
  
  /**
   Parse `Int64` from underlying data.
   
   - parameter offset: Offset in bytes from this value should be read
   - parameter bigEndian: Is data in big-endian or little-endian order? If this parameter may is ommited, than `BinaryData`
   setting is used.
   
   - returns: `Int64` representation of byte at offset.
   - throws: `BinaryDataErrors.NotEnoughData` if there is not enough data.
   */
  public func get(_ offset: Int, bigEndian: Bool? = nil) throws -> Int64 {
    let uint:UInt64 = try get(offset, bigEndian: bigEndian ?? self.bigEndian)
    return Int64(bitPattern: uint)
  }
  
  /**
   Parse `Float32` from underlying data.
   
   - parameter offset: Offset in bytes from this value should be read
   - parameter bigEndian: Is data in big-endian or little-endian order? If this parameter may is ommited, than `BinaryData`
   setting is used.
   
   - returns: `Float32` representation of byte at offset.
   - throws: `BinaryDataErrors.NotEnoughData` if there is not enough data.
   */
  public func get(_ offset: Int) throws -> Float32 {
    let uint:UInt32 = try get(offset)
    return unsafeConversion(uint)
  }
  
  /**
   Parse `Float64` from underlying data.
   
   - parameter offset: Offset in bytes from this value should be read
   - parameter bigEndian: Is data in big-endian or little-endian order? If this parameter may is ommited, than `BinaryData`
   setting is used.
   
   - returns: `Float64` representation of byte at offset.
   - throws: `BinaryDataErrors.NotEnoughData` if there is not enough data.
   */
  public func get(_ offset: Int) throws -> Float64 {
    let uint:UInt64 = try get(offset)
    return unsafeConversion(uint)
  }
  
  // MARK: - Strings
  
  /**
   Parse null-terminated UTF8 `String` from underlying data.
   
   - parameter offset: Offset in bytes from this value should be read
   
   - returns: Read `String`
   - throws:
      - `BinaryDataErrors.NotEnoughData` if there is not enough data.
      - `BinaryDataErrors.FailedToConvertToString` if there was an error converting byte stream to String.
   */
  public func getNullTerminatedUTF8(_ offset: Int) throws -> String {
    var utf8 = UTF8()
    var string = ""
    var generator = try subData(offset, data.count - offset).data.makeIterator()
    
    while true {
      switch utf8.decode(&generator) {
      case .scalarValue(let unicodeScalar) where unicodeScalar.value > 0:
        string.append(String(unicodeScalar))
      case .scalarValue(_)://\0 means end of string
        return string
      case .emptyInput:
        throw BinaryDataErrors.failedToConvertToString
      case .error:
        throw BinaryDataErrors.failedToConvertToString
      }
    }
  }
  
  /**
   Parse UTF8 `String` of known size from underlying data.
   
   - parameter offset: Offset in bytes from this value should be read
   - parameter length: Length in bytes to read
   
   - returns: Read `String`
   - throws:
      - `BinaryDataErrors.NotEnoughData` if there is not enough data.
      - `BinaryDataErrors.FailedToConvertToString` if there was an error converting byte stream to String.
   */
  public func getUTF8(_ offset: Int, length: Int) throws -> String {
    var utf8 = UTF8()
    var string = ""
    var generator = try subData(offset, length).data.makeIterator()
    
    while true {
      switch utf8.decode(&generator) {
      case .scalarValue(let unicodeScalar):
        string.append(String(unicodeScalar))
      case .emptyInput:
        return string
      case .error:
        throw BinaryDataErrors.failedToConvertToString
      }
    }
  }
  
  // MARK: - Data manipulation
  
  /**
   Get subdata in range (offset, self.data.length)
   
   - parameter offset: Offset to start of subdata
   
   - returns: Subdata
   - throws: `BinaryDataErrors.NotEnoughData` if there is not enough data.
   */
  public func tail(_ offset: Int) throws -> BinaryData {
    if offset > data.count {
      throw BinaryDataErrors.notEnoughData
    }
    
    return try subData(offset, data.count - offset)
  }
  
  /**
   Get subdata in range (offset, length)
   
   - parameter offset: Offset to start of subdata
   - parameter length: Length of subdata
   
   - returns: Subdata
   - throws: `BinaryDataErrors.NotEnoughData` if there is not enough data.
   */
  public func subData(_ offset: Int, _ length: Int) throws -> BinaryData {
    if offset >= 0 && offset <= data.count && length >= 0 && (offset + length) <= data.count {
      return BinaryData(data: Array(data[offset..<(offset + length)]))
    } else {
      throw BinaryDataErrors.notEnoughData
    }
  }
}
