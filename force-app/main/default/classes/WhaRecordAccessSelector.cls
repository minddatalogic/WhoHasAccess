/**
 * Reads UserRecordAccess: the access Salesforce actually enforces for one
 * user on one record.
 *
 * without sharing: UserRecordAccess answers for the UserId in the filter, not
 * for the running user, so the sharing mode does not change the result.
 */
public without sharing class WhaRecordAccessSelector {
  /**
   * @param userId User to check
   * @param recordId Record to check
   * @return The access row, or null when Salesforce returns none
   */
  public UserRecordAccess selectForUser(Id userId, Id recordId) {
    List<UserRecordAccess> rows = [
      SELECT
        RecordId,
        HasReadAccess,
        HasEditAccess,
        HasDeleteAccess,
        HasTransferAccess,
        HasAllAccess
      FROM UserRecordAccess
      WHERE UserId = :userId AND RecordId = :recordId
    ];
    return rows.isEmpty() ? null : rows[0];
  }
}
