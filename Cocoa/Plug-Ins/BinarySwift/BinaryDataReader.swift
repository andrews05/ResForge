//
//  BinaryDataReader.swift
//  BinaryData
//
//  Created by Łukasz Kwoska on 09.12.2015.
//  Copyright © 2015 Macoscope Sp. z o.o. All rights reserved.
//

import Foundation

///Wrapper on `BinaryReader` which is reference type and keeps current offset.
open class BinaryDataReader {
  public private(set) var readIndex: Int
  let data: BinaryData
  
  /**
   Initialize `BinaryDataReader`
   - parameter data: Underlying `BinaryData`
   - parameter readIndex: Starting index. If ommited than 0 is used.
   
   - returns: Initialized object
   */
  public init(_ data: BinaryData, readIndex: Int = 0) {
    self.data = data
    self.readIndex = readIndex
  }
  
  // MARK: - Parsing out simple types
  
  /**
   Parse `UInt8` from underlying data at current offset and increase offset.
   
   - returns: `UInt8` representation of byte at offset.
   - throws: `BinaryDataErrors.NotEnoughData` if there is not enough data.
   */
  open func read(_ bigEndian: Bool? = nil) throws -> UInt8 {
    let value: UInt8 = try data.get(readIndex, bigEndian: bigEndian)
    readIndex = readIndex + 1
    return value
  }
  
  /**
   Parse `Int8` from underlying data at current offset and increase offset.
   
   - returns: `Int8` representation of byte at offset.
   - throws: `BinaryDataErrors.NotEnoughData` if there is not enough data.
   */
  open func read(_ bigEndian: Bool? = nil) throws -> Int8 {
    let value: Int8 = try data.get(readIndex, bigEndian: bigEndian)
    readIndex = readIndex + 1
    return value
  }
  
  /**
   Parse `UInt16` from underlying data at current offset and increase offset.
   
   - returns: `UInt16` representation of bytes at offset.
   - throws: `BinaryDataErrors.NotEnoughData` if there is not enough data.
   */
  open func read(_ bigEndian: Bool? = nil) throws -> UInt16 {
    let value: UInt16 = try data.get(readIndex, bigEndian: bigEndian)
    readIndex = readIndex + 2
    return value
  }
  
  /**
   Parse `Int16` from underlying data at current offset and increase offset.
   
   - returns: `Int16` representation of bytes at offset.
   - throws: `BinaryDataErrors.NotEnoughData` if there is not enough data.
   */
  open func read(_ bigEndian: Bool? = nil) throws -> Int16 {
    let value: Int16 = try data.get(readIndex, bigEndian: bigEndian)
    readIndex = readIndex + 2
    return value
  }
  
  /**
   Parse `UInt32` from underlying data at current offset and increase offset.
   
   - returns: `UInt32` representation of bytes at offset.
   - throws: `BinaryDataErrors.NotEnoughData` if there is not enough data.
   */
  open func read(_ bigEndian: Bool? = nil) throws -> UInt32 {
    let value: UInt32 = try data.get(readIndex, bigEndian: bigEndian)
    readIndex = readIndex + 4
    return value
  }
  
  /**
   Parse `Int32` from underlying data at current offset and increase offset.
   
   - returns: `Int32` representation of bytes at offset.
   - throws: `BinaryDataErrors.NotEnoughData` if there is not enough data.
   */
  open func read(_ bigEndian: Bool? = nil) throws -> Int32 {
    let value: Int32 = try data.get(readIndex, bigEndian: bigEndian)
    readIndex = readIndex + 4
    return value
  }
  
  /**
   Parse `UInt64` from underlying data at current offset and increase offset.
   
   - returns: `UInt64` representation of bytes at offset.
   - throws: `BinaryDataErrors.NotEnoughData` if there is not enough data.
   */
  open func read(_ bigEndian: Bool? = nil) throws -> UInt64 {
    let value: UInt64 = try data.get(readIndex, bigEndian: bigEndian)
    readIndex = readIndex + 8
    return value
  }
  
  /**
   Parse `Int64` from underlying data at current offset and increase offset.
   
   - returns: `Int64` representation of bytes at offset.
   - throws: `BinaryDataErrors.NotEnoughData` if there is not enough data.
   */
  open func read(_ bigEndian: Bool? = nil) throws -> Int64 {
    let value: Int64 = try data.get(readIndex, bigEndian: bigEndian)
    readIndex = readIndex + 8
    return value
  }
  
  /**
   Parse `Float32` from underlying data at current offset and increase offset.
   
   - returns: `Float32` representation of bytes at offset.
   - throws: `BinaryDataErrors.NotEnoughData` if there is not enough data.
   */
  open func read() throws -> Float32 {
    let value: Float32 = try data.get(readIndex)
    readIndex = readIndex + 4
    return value
  }
  
  /**
   Parse `Float64` from underlying data at current offset and increase offset.
   
   - returns: `Float64` representation of bytes at offset.
   - throws: `BinaryDataErrors.NotEnoughData` if there is not enough data.
   */
  open func read() throws -> Float64 {
    let value: Float64 = try data.get(readIndex)
    readIndex = readIndex + 8
    return value
  }
  
  /**
   Parse null-terminated UTF8 `String` from underlying data at current offset and increase offset.
   
   - returns: `String` representation of null-terminated UTF8 bytes at offset.
   
   - throws:
   - `BinaryDataErrors.NotEnoughData` if there is not enough data.
   - `BinaryDataErrors.FailedToConvertToString` if there was an error converting byte stream to String.
   */
  open func readNullTerminatedUTF8() throws -> String {
    let string = try data.getNullTerminatedUTF8(readIndex)
    readIndex += string.utf8.count + 1//Account for \0
    return string
  }
  
  /**
   Parse UTF8 `String` of known size from underlying data at current offset and increase offset.
   
   - parameter length: String length in bytes.
   
   - returns: `String` representation of null-terminated UTF8 bytes at offset.
   - throws:
   - `BinaryDataErrors.NotEnoughData` if there is not enough data.
   - `BinaryDataErrors.FailedToConvertToString` if there was an error converting byte stream to String.
   */
  open func readUTF8(_ length: Int) throws -> String {
    let string = try data.getUTF8(readIndex, length: length)
    readIndex += length
    return string
  }
  
  /**
   Get subdata at current offset and increase offset.
   
   - parameter length: String length in bytes.
   
   - returns: `BinaryData` subdata starting at `offset` with given `length`.
   - throws: `BinaryDataErrors.NotEnoughData` if there is not enough data.
   */
  open func read(_ length: Int) throws -> BinaryData {
    let subdata = try data.subData(readIndex, length)
    readIndex += length
    return subdata
  }
}
