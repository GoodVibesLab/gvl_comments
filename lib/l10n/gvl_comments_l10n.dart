import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'gvl_comments_l10n_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of GvlCommentsL10n
/// returned by `GvlCommentsL10n.of(context)`.
///
/// Applications need to include `GvlCommentsL10n.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/gvl_comments_l10n.dart';
///
/// return MaterialApp(
///   localizationsDelegates: GvlCommentsL10n.localizationsDelegates,
///   supportedLocales: GvlCommentsL10n.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the GvlCommentsL10n.supportedLocales
/// property.
abstract class GvlCommentsL10n {
  GvlCommentsL10n(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static GvlCommentsL10n? of(BuildContext context) {
    return Localizations.of<GvlCommentsL10n>(context, GvlCommentsL10n);
  }

  static const LocalizationsDelegate<GvlCommentsL10n> delegate =
      _GvlCommentsL10nDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('en')];

  /// No description provided for @retryTooltip.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retryTooltip;

  /// No description provided for @sendTooltip.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get sendTooltip;

  /// No description provided for @addCommentHint.
  ///
  /// In en, this message translates to:
  /// **'Add a comment…'**
  String get addCommentHint;

  /// No description provided for @reportSentLabel.
  ///
  /// In en, this message translates to:
  /// **'Report sent'**
  String get reportSentLabel;

  /// No description provided for @reportErrorLabel.
  ///
  /// In en, this message translates to:
  /// **'Error sending report'**
  String get reportErrorLabel;

  /// No description provided for @reportLabel.
  ///
  /// In en, this message translates to:
  /// **'Report'**
  String get reportLabel;

  /// No description provided for @alreadyReportedLabel.
  ///
  /// In en, this message translates to:
  /// **'You already reported this comment'**
  String get alreadyReportedLabel;

  /// No description provided for @reportedPlaceholderLabel.
  ///
  /// In en, this message translates to:
  /// **'⚠ This comment has been reported'**
  String get reportedPlaceholderLabel;

  /// No description provided for @moderatedPlaceholderLabel.
  ///
  /// In en, this message translates to:
  /// **'⚠ This comment has been moderated'**
  String get moderatedPlaceholderLabel;

  /// No description provided for @loadPreviousCommentsLabel.
  ///
  /// In en, this message translates to:
  /// **'Load previous comments'**
  String get loadPreviousCommentsLabel;

  /// No description provided for @timeJustNow.
  ///
  /// In en, this message translates to:
  /// **'Just now'**
  String get timeJustNow;

  /// No description provided for @timeOneMinute.
  ///
  /// In en, this message translates to:
  /// **'1 min ago'**
  String get timeOneMinute;

  /// No description provided for @timeXMinutes.
  ///
  /// In en, this message translates to:
  /// **'{m} min ago'**
  String timeXMinutes(Object m);

  /// No description provided for @timeOneHour.
  ///
  /// In en, this message translates to:
  /// **'1h ago'**
  String get timeOneHour;

  /// No description provided for @timeXHours.
  ///
  /// In en, this message translates to:
  /// **'{h}h ago'**
  String timeXHours(Object h);

  /// No description provided for @timeYesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get timeYesterday;

  /// No description provided for @timeXDays.
  ///
  /// In en, this message translates to:
  /// **'{d} days ago'**
  String timeXDays(Object d);

  /// No description provided for @timeFallbackDate.
  ///
  /// In en, this message translates to:
  /// **'On {y}-{m}-{d}'**
  String timeFallbackDate(Object d, Object m, Object y);
}

class _GvlCommentsL10nDelegate extends LocalizationsDelegate<GvlCommentsL10n> {
  const _GvlCommentsL10nDelegate();

  @override
  Future<GvlCommentsL10n> load(Locale locale) {
    return SynchronousFuture<GvlCommentsL10n>(lookupGvlCommentsL10n(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en'].contains(locale.languageCode);

  @override
  bool shouldReload(_GvlCommentsL10nDelegate old) => false;
}

GvlCommentsL10n lookupGvlCommentsL10n(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return GvlCommentsL10nEn();
  }

  throw FlutterError(
      'GvlCommentsL10n.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
