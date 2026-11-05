/**
 * Decides who may use Who Has Access on a record. Every entry point calls it
 * before any system-mode query runs: the running user must hold the
 * Who_Has_Access_Viewer custom permission AND be able to read the record.
 */
public with sharing class WhaAccessGuard {
  private WhaAccessGuard() {
    // static helpers only
  }

  /**
   * @param recordId Record the user wants to analyse
   * @throws WhaException when the Id is missing, the permission is missing,
   *         or the user cannot read the record
   */
  public static void assertCanAnalyse(Id recordId) {
    if (recordId == null) {
      throw new WhaException('A record Id is required.');
    }
    if (!FeatureManagement.checkPermission(WhaConstants.CUSTOM_PERMISSION)) {
      throw new WhaException(
        'You need the "Who Has Access" permission set to use this component.'
      );
    }
    UserRecordAccess ownAccess = new WhaRecordAccessSelector()
      .selectForUser(UserInfo.getUserId(), recordId);
    if (ownAccess == null || !ownAccess.HasReadAccess) {
      throw new WhaException(
        'You can only analyse records that you can read yourself.'
      );
    }
  }
}
