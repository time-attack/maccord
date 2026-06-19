import Foundation

/// One file attachment for a multipart message upload.
public struct FilePart: Sendable {
    public var filename: String
    public var contentType: String
    public var data: Data

    public init(filename: String, contentType: String, data: Data) {
        self.filename = filename
        self.contentType = contentType
        self.data = data
    }
}

/// Builds a `multipart/form-data` body matching Discord's create-message upload
/// shape: a single `payload_json` field followed by `files[n]` parts.
public struct MultipartFormBody {
    /// A fresh random boundary; callers put this in the `Content-Type` header.
    public let boundary: String

    public init(boundary: String = "maccord.\(UUID().uuidString)") {
        self.boundary = boundary
    }

    /// Produces `(body, boundary)` for the given JSON payload and files.
    /// Files are emitted as `files[0]`, `files[1]`, … in order.
    public func encode(payloadJSON: Data, files: [FilePart]) -> (body: Data, boundary: String) {
        var body = Data()
        let crlf = "\r\n"
        let boundaryLine = "--\(boundary)\(crlf)"

        // payload_json part
        body.appendString(boundaryLine)
        body.appendString("Content-Disposition: form-data; name=\"payload_json\"\(crlf)")
        body.appendString("Content-Type: application/json\(crlf)")
        body.appendString(crlf)
        body.append(payloadJSON)
        body.appendString(crlf)

        // files[n] parts
        for (index, file) in files.enumerated() {
            body.appendString(boundaryLine)
            body.appendString(
                "Content-Disposition: form-data; name=\"files[\(index)]\"; filename=\"\(file.filename)\"\(crlf)"
            )
            body.appendString("Content-Type: \(file.contentType)\(crlf)")
            body.appendString(crlf)
            body.append(file.data)
            body.appendString(crlf)
        }

        body.appendString("--\(boundary)--\(crlf)")
        return (body, boundary)
    }

    /// The full value for the `Content-Type` request header.
    public var contentTypeHeader: String {
        "multipart/form-data; boundary=\(boundary)"
    }
}

private extension Data {
    mutating func appendString(_ string: String) {
        if let data = string.data(using: .utf8) {
            append(data)
        }
    }
}
