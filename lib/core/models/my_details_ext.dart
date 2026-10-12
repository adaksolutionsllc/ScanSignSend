import '../db/app_database.dart';
import '../services/prefill_matcher.dart';

extension UserProfileMyDetails on UserProfileData {
  /// The details PreFill fills forms with.
  MyDetails get myDetails => MyDetails(
    firstName: firstName,
    middleName: middleName,
    lastName: lastName,
    email: email,
    phone: phone,
    addressLine1: address,
    addressLine2: address2,
    city: city,
    state: state,
    zip: zip,
    country: country,
    company: company,
    jobTitle: jobTitle,
    dateOfBirth: dateOfBirth,
  );
}
