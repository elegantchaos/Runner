// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 14/06/22.
//  All code (c) 2022 - present day, Elegant Chaos Limited.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Foundation

public class PipeInfo {
    public typealias Callback = (String) -> Void

    class Buffer {
        var text: String = ""
    }
    
    let pipe: Pipe
    let queue: DispatchQueue
    var callback: Callback
    var handle: FileHandle?
    var tee: FileHandle?
    var buffer: Buffer
    
    init(tee teeHandle: FileHandle? = nil, queue: DispatchQueue, callback: Callback? = nil) {
        let buffer = Buffer()
        
        self.pipe = Pipe()
        self.queue = queue
        self.tee = teeHandle
        self.handle = pipe.fileHandleForReading
        self.buffer = buffer
        self.callback = callback ?? { buffer.text.append($0) }

        handle?.readabilityHandler = { handle in
            let data = handle.availableData
            queue.async {
                self.write(data: data)
            }
        }
    }
    
    func finish() -> String {
        if let handle = handle {
            queue.async {
                let data = handle.readDataToEndOfFile()
                handle.readabilityHandler = nil
                self.write(data: data)
            }
        }

        var final = ""
        queue.sync {
            final = buffer.text
        }
        
        return final
    }
    
    func write(data: Data) {
        tee?.write(data)
        if let string = String(data: data, encoding: .utf8) {
            if string.count > 0 {
                self.callback(string)
            }
        }
    }
    
    @available(macOS 12.0, *)
    var bytes: FileHandle.AsyncBytes? {
        handle?.bytes
    }
    
    @available(macOS 12.0, *)
    var lines: AsyncLineSequence<FileHandle.AsyncBytes>? {
        handle.map { $0.bytes.lines }
    }
}
