import 'package:isar_community/isar.dart';

part 'app_settings.g.dart';

@Collection(accessor: 'appSettings')
class AppSettings {
  static const Id singletonId = 1;

  Id isarId = singletonId;
  String themeSelection;
  int? accentColor;
  String readingDirection;
  bool swapGamepadConfirmBack;
  int? readerCacheLimitMb;
  List<String> libraryNames;

  AppSettings({
    this.themeSelection = 'system',
    this.accentColor,
    this.readingDirection = 'LTR',
    this.swapGamepadConfirmBack = false,
    this.readerCacheLimitMb,
    this.libraryNames = const [],
  });

  AppSettings copy() => AppSettings(
    themeSelection: themeSelection,
    accentColor: accentColor,
    readingDirection: readingDirection,
    swapGamepadConfirmBack: swapGamepadConfirmBack,
    readerCacheLimitMb: readerCacheLimitMb,
    libraryNames: List<String>.of(libraryNames),
  );
}
