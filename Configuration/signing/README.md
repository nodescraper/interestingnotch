# Signed macOS releases

This app is distributed outside the Mac App Store, so a warning-free install requires:

1. An Apple Developer Program membership for the team that owns the bundle identifier.
2. A `Developer ID Application` certificate installed in the login keychain.
3. A notarytool keychain profile created from an App Store Connect API key.

The certificate and private key must stay in the developer's keychain or CI secret store; they are not committed to this repository.

Create the notarytool profile once on the release machine:

```bash
xcrun notarytool store-credentials interestingnotch-notary \
  --key /path/to/AuthKey_KEYID.p8 \
  --key-id KEYID \
  --issuer ISSUER_UUID
```

Then run `Configuration/signing/build_release.sh` with `APPLE_TEAM_ID` set to the 10-character Team ID and `NOTARYTOOL_PROFILE` set to the profile name.

The resulting DMG is signed, notarized, and stapled. A user can drag the app to Applications without bypassing Gatekeeper.
