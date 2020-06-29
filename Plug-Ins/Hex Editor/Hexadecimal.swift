import Foundation

extension String {
    enum ExtendedEncoding {
        case hexadecimal
    }
    
    func data(using encoding:ExtendedEncoding) -> Data?  {
        guard self.count % 2 == 0 else { return nil }
        var newData = Data(capacity: self.count/2)
        var indexIsEven = true
        for i in self.indices {
            if indexIsEven {
                let byteRange = i...self.index(after: i)
                guard let byte = UInt8(self[byteRange], radix: 16) else { return nil }
                newData.append(byte)
            }
            indexIsEven.toggle()
        }
        return newData
    }
}

extension Data {
    var hexadecimal: String {
        return map { String(format: "%02x", $0) }
            .joined()
    }
}
