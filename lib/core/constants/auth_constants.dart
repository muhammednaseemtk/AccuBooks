class AuthConstants {
  // Roles
  static const String roleOwner = 'OWNER';
  static const String roleAdmin = 'ADMIN';
  static const String roleAccountant = 'ACCOUNTANT';
  static const String roleStaff = 'STAFF';
  static const String roleViewer = 'VIEWER';

  static const List<String> allRoles = [
    roleOwner,
    roleAdmin,
    roleAccountant,
    roleStaff,
    roleViewer,
  ];

  // SharedPreferences Keys
  static const String prefAuthToken = 'accubooks_auth_token';
  static const String prefUserId = 'accubooks_auth_user_id';
  static const String prefUserEmail = 'accubooks_auth_user_email';
  static const String prefRememberMe = 'accubooks_auth_remember_me';
  static const String prefActiveOrgId = 'accubooks_auth_org_id';
}
