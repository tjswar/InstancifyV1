# Instancify



Instancify is an iOS application that helps manage AWS EC2 instances with an intuitive interface. It provides real-time monitoring, cost tracking, and automated instance management capabilities.

## Features

### Instance Management
- Real-time EC2 instance monitoring
- Start/Stop/Reboot instances
- Instance state change notifications
- Auto-stop scheduling for cost optimization

### Cost Management
- Real-time cost tracking
- Daily and monthly cost projections
- Region-based pricing information
- Cost history and analytics

### Security
- Secure AWS credentials management
- Custom App lock with PIN/password protection
- Secure credential storage in Keychain

### User Experience
- Intuitive dashboard interface
- Dark/Light mode support
- Widget support for quick instance monitoring
- Region-based filtering and organization

## Architecture

### Core Technologies
- SwiftUI for modern UI development
- Combine for reactive programming
- AWS SDK for iOS
- CloudKit for data sync (coming soon)

### Design Patterns
- MVVM (Model-View-ViewModel) architecture
- Repository pattern for data management
- Service-oriented architecture for AWS interactions
- Observer pattern for real-time updates

## Requirements

- iOS 14.0+
- Xcode 13.0+
- Swift 5.5+
- AWS Account with EC2 access
- AWS IAM user with appropriate permissions

## Installation

1. Clone the repository
```bash
git clone https://github.com/tjswar/InstancifyApp.git
```

2. Open the project in Xcode
```bash
cd InstancifyApp
open Instancify.xcodeproj
```

3. Install dependencies (if using CocoaPods)
```bash
pod install
```

4. Build and run the project

## AWS Configuration

### Required IAM Permissions
```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "ec2:Describe*",
                "ec2:StartInstances",
                "ec2:StopInstances",
                "ec2:RebootInstances"
            ],
            "Resource": "*"
        }
    ]
}
```

### Setting Up AWS Credentials
1. Create an IAM user in AWS Console
2. Attach the above policy to the user
3. Generate access key and secret key
4. Enter the credentials in Instancify app

## App Configuration

### Instance Monitoring
1. Configure refresh intervals
2. Set up notification preferences
3. Configure auto-stop schedules

### Cost Management
1. Set budget alerts
2. Configure cost thresholds
3. Set up daily/monthly reports

### Security Settings
1. Enable Face ID/Touch ID
2. Set up app lock
3. Configure auto-lock timing

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## Roadmap

- [ ] CloudKit integration for data sync
- [ ] Support for other AWS services
- [ ] Advanced cost analytics
- [ ] Custom widget configurations
- [ ] iPad optimization

## Support

For support, please:
1. Check the [Issues](https://github.com/tjswar/InstancifyApp/issues) page
2. Create a new issue if needed
3. Join our [Discussions](https://github.com/tjswar/InstancifyApp/discussions)

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details

## Acknowledgments

- AWS SDK for iOS
- SwiftUI community
- Contributors and testers 
