# 📱 vibedIPAManager

A lightweight iOS 16+ app for managing and modifying IPA files on your device. Replace, remove, and customize files within your own IPA archives through a SwiftUI interface.

## Features

- Import IPA files with the iOS Files picker
- Browse the archive contents
- Replace or remove selected files
- Export the modified IPA to Files or share it
- SwiftUI interface for iOS 16+

## Requirements

- iOS 16.0 or later
- Xcode 15 or later

## Development

```bash
git clone https://github.com/timmy6259/vibedIPAManager.git
cd vibedIPAManager
open vibedIPAManager.xcodeproj
```

## Important limitations

An IPA is a ZIP archive, but changing an app bundle invalidates its existing code signature. The exported archive is intended for legitimate development, testing, and personal files. It must be re-signed with an appropriate provisioning profile before iOS will install it.

## CI/CD

GitHub Actions builds on pushes and can be started manually. Alpha artifacts are published as prereleases when signing secrets are configured.

## License

MIT License.