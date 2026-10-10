const _dot = '•';

/// `priya.raman@gmail.com` → `p•••@gmail.com`, for the audit page.
String maskEmail(String email) {
  final at = email.lastIndexOf('@');
  if (at <= 0) return _dot * 3;
  return '${email[0]}${_dot * 3}${email.substring(at)}';
}

/// Keeps the country code (when written as `+cc` followed by a space) and the
/// last four digits: `+91 98765 54821` → `+91 ••••• •4821`. Separators the
/// sender typed stay where they were.
String maskPhone(String phone) {
  final trimmed = phone.trim();
  var keepPrefix = 0;
  final cc = RegExp(r'^\+\d{1,3}\s').firstMatch(trimmed);
  if (cc != null) keepPrefix = cc.end;

  final digitsAfterPrefix = RegExp(
    r'\d',
  ).allMatches(trimmed.substring(keepPrefix)).length;
  var toMask = digitsAfterPrefix - 4;
  if (toMask <= 0) return trimmed;

  final out = StringBuffer(trimmed.substring(0, keepPrefix));
  for (final ch in trimmed.substring(keepPrefix).split('')) {
    if (RegExp(r'\d').hasMatch(ch) && toMask > 0) {
      out.write(_dot);
      toMask--;
    } else {
      out.write(ch);
    }
  }
  return out.toString();
}
