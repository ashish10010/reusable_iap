# reusable_iap Publish Checklist

## Package Metadata

- [ ] Replace the placeholder text in `LICENSE` with the real license you want to publish under.
- [ ] Add `repository`, `issue_tracker`, and `documentation` URLs to `pubspec.yaml`.
- [ ] Confirm the package name, description, topics, and version in `pubspec.yaml`.
- [ ] Review `CHANGELOG.md` so the release notes match what you are publishing.

## Documentation

- [ ] Read `README.md` top to bottom and make sure the first screen answers what the package is and how to use it.
- [ ] Verify the import path is `package:reusable_iap/reusable_iap.dart` everywhere.
- [ ] Keep the README example aligned with the real public API.
- [ ] Verify `example/lib/main.dart` still matches the recommended usage pattern.

## Product and Platform Readiness

- [ ] Replace the sample product IDs in the example with your real IDs before demoing it.
- [ ] Confirm App Store Connect / Google Play Console product setup is complete.
- [ ] Test on at least one Android device and one iOS device with sandbox / test accounts.
- [ ] Verify restore flows, cancellations, verification failures, and already-owned purchases.
- [ ] Make sure your production app uses a real `PurchaseVerifier` when server-side trust matters.

## Local Validation

- [ ] Run `flutter pub get`.
- [ ] Run `flutter analyze`.
- [ ] Run `flutter test`.
- [ ] Run `flutter pub publish --dry-run`.

## Final Publish

- [ ] Review the files that will be uploaded and remove anything accidental.
- [ ] Tag the release in source control if you use tags.
- [ ] Run `flutter pub publish`.
