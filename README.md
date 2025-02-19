# Instancify

Instancify is a powerful iOS app that simplifies AWS EC2 instance management, offering an intuitive interface for monitoring and controlling your cloud infrastructure.

## Features

- **AWS EC2 Management**
  - Start, stop, and monitor EC2 instances
  - Real-time instance status updates
  - Multi-region support
  - Instance tagging and organization

- **Runtime Monitoring**
  - Customizable runtime alerts
  - Push notifications for instance state changes
  - Cost monitoring and usage metrics
  - Background monitoring capabilities

- **Security**
  - Secure AWS credentials storage using iOS Keychain
  - Minimal required IAM permissions
  - No server-side storage of AWS credentials
  - End-to-end encryption

- **User Experience**
  - Clean, modern SwiftUI interface
  - Dark mode support
  - Intuitive navigation
  - Real-time updates

## Requirements

- iOS 16.0+
- Xcode 15.0+
- Swift 5.9+
- Active AWS Account with EC2 access

## Installation

1. Clone the repository:
```bash
git clone https://github.com/tjswar/InstancifyV1.git
cd InstancifyV1
```

2. Open `Instancify.xcodeproj` in Xcode

3. Configure your Firebase project:
   - Create a new Firebase project
   - Add your iOS app to the project
   - Download `GoogleService-Info.plist` and add it to the project
   - Enable Authentication and Firestore in Firebase Console

4. Build and run the project

## AWS Setup

1. Create an IAM user with the following permissions:
```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "ec2:DescribeInstances",
                "ec2:StartInstances",
                "ec2:StopInstances",
                "ec2:RebootInstances",
                "ec2:DescribeRegions",
                "ec2:DescribeInstanceStatus",
                "ec2:DescribeTags",
                "ec2:CreateTags",
                "ec2:DeleteTags"
            ],
            "Resource": "*"
        }
    ]
}
```

2. Note down the Access Key ID and Secret Access Key

## Configuration

1. First launch setup:
   - Enter your AWS credentials
   - Select your preferred AWS region
   - Configure notification preferences

2. Optional: Configure runtime monitoring alerts

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## Support

If you find this app helpful, consider supporting its development:
- [PayPal](https://paypal.me/SaiTejaswarReddy)

## Privacy & Security

- AWS credentials are stored securely in the iOS Keychain
- No sensitive data is transmitted to external servers
- All instance monitoring is done directly through AWS APIs
- Full privacy policy available in the app

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Contact

For support or inquiries:
- Email: saitejaswar84@gmail.com

## Acknowledgments

- Built with SwiftUI and AWS SDK for iOS
- Uses Firebase for notifications and analytics
- Icon designs from SF Symbols