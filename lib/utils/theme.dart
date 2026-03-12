import 'package:flutter/material.dart';

class AppTheme {
  static const Color primary = Color(0xFF6366F1);
  static const Color primaryLight = Color(0xFFEEF2FF);
  static const Color danger = Color(0xFFDC2626);
  static const Color dangerLight = Color(0xFFFEE2E2);
  static const Color warning = Color(0xFFD97706);
  static const Color warningLight = Color(0xFFFEF3C7);
  static const Color success = Color(0xFF059669);
  static const Color successLight = Color(0xFFD1FAE5);
  static const Color info = Color(0xFF2563EB);
  static const Color infoLight = Color(0xFFDBEAFE);
  static const Color gray100 = Color(0xFFF3F4F6);
  static const Color gray50  = Color(0xFFF9FAFB);
  static const Color gray200 = Color(0xFFE5E7EB);
  static const Color gray300 = Color(0xFFD1D5DB);
  static const Color gray400 = Color(0xFF9CA3AF);
  static const Color gray500 = Color(0xFF6B7280);
  static const Color gray600 = Color(0xFF4B5563);
  static const Color gray700 = Color(0xFF374151);
  static const Color gray800 = Color(0xFF1F2937);

  static ThemeData get theme => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.light,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: gray800,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: gray800,
        fontSize: 18,
        fontWeight: FontWeight.w600,
        fontFamily: 'sans-serif',
      ),
    ),
    scaffoldBackgroundColor: const Color(0xFFF8FAFC),
    cardTheme: CardThemeData(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.white,
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: gray200),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: gray200),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: primary, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      filled: true,
      fillColor: Colors.white,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: primary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    ),
    dividerTheme: const DividerThemeData(color: gray100, thickness: 1),
    chipTheme: ChipThemeData(
      backgroundColor: gray100,
      selectedColor: primaryLight,
      labelStyle: const TextStyle(fontSize: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
  );
}

// 심각도 배지 색상
Map<String, Color> severityColors = {
  '중결함': AppTheme.danger,
  '경결함': AppTheme.warning,
  '권고사항': AppTheme.info,
};
Map<String, Color> severityBgColors = {
  '중결함': AppTheme.dangerLight,
  '경결함': AppTheme.warningLight,
  '권고사항': AppTheme.infoLight,
};

// 상태 배지 색상
Map<String, Color> statusColors = {
  '미조치': AppTheme.danger,
  '조치중': AppTheme.warning,
  '조치완료': AppTheme.success,
  '재검사필요': AppTheme.info,
  '합격': AppTheme.success,
  '불합격': AppTheme.danger,
  '조건부합격': AppTheme.warning,
  '완료': AppTheme.success,
  '예정': AppTheme.info,
  '진행중': AppTheme.primary,
  '불가': AppTheme.gray500,
  '이월': AppTheme.gray500,
  '양호': AppTheme.success,
  '주의': AppTheme.warning,
  '불량': AppTheme.danger,
  '긴급조치필요': AppTheme.danger,
  'active': AppTheme.success,
  'inactive': AppTheme.gray500,
  'suspended': AppTheme.warning,
  'normal': AppTheme.success,
  'warning': AppTheme.warning,
  'fault': AppTheme.danger,
  'stopped': AppTheme.gray500,
};

Map<String, Color> statusBgColors = {
  '미조치': AppTheme.dangerLight,
  '조치중': AppTheme.warningLight,
  '조치완료': AppTheme.successLight,
  '재검사필요': AppTheme.infoLight,
  '합격': AppTheme.successLight,
  '불합격': AppTheme.dangerLight,
  '조건부합격': AppTheme.warningLight,
  '완료': AppTheme.successLight,
  '예정': AppTheme.infoLight,
  '진행중': AppTheme.primaryLight,
  '불가': AppTheme.gray100,
  '이월': AppTheme.gray100,
  '양호': AppTheme.successLight,
  '주의': AppTheme.warningLight,
  '불량': AppTheme.dangerLight,
  '긴급조치필요': AppTheme.dangerLight,
  'active': AppTheme.successLight,
  'inactive': AppTheme.gray100,
  'suspended': AppTheme.warningLight,
  'normal': AppTheme.successLight,
  'warning': AppTheme.warningLight,
  'fault': AppTheme.dangerLight,
  'stopped': AppTheme.gray100,
};
