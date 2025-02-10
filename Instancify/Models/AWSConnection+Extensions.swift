import Foundation
import AWSCore

extension AWSConnection {
    func toAWSCredentials() -> AWSStaticCredentialsProvider {
        return AWSStaticCredentialsProvider(
            accessKey: self.accessKeyId,
            secretKey: self.secretKey
        )
    }
} 