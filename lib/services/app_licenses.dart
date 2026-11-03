import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// The SIL Open Font License text that ships with the bundled Inter font.
const interLicenseAsset = 'assets/fonts/Inter-OFL.txt';

/// Cryonis's own licence: the repository's LICENSE file, bundled as an asset so
/// the text shown in the app is the text in the repository.
const appLicenseAsset = 'LICENSE';

/// The one-line notice shown on Flutter's third-party licences page.
const appLegalese = '© 2026 Rupesh Jadhav. Released under the MIT License.';

/// Adds the licences Flutter cannot collect from the package list to the
/// registry behind the app's licences page. Flutter gathers the license files
/// of every pub package on its own; the Inter font is a bundled asset, so its
/// notice has to be registered here.
void registerAppLicenses({AssetBundle? bundle}) {
  LicenseRegistry.addLicense(() async* {
    final text = await (bundle ?? rootBundle).loadString(interLicenseAsset);
    yield LicenseEntryWithLineBreaks(const ['Inter (font)'], text);
  });
}
