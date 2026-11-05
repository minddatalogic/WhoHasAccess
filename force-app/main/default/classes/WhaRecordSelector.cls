/**
 * Reads the record under analysis and its object's sharing model.
 *
 * without sharing / SYSTEM_MODE: the tool explains access the viewer may not
 * have themselves. WhaAccessGuard checks the custom permission, and that the
 * viewer can read the record, before any of this runs.
 */
public without sharing class WhaRecordSelector {
  /**
   * @param objectName Object API name
   * @return The EntityDefinition with Internal/ExternalSharingModel, or null
   */
  public EntityDefinition selectSharingModel(String objectName) {
    List<EntityDefinition> definitions = [
      SELECT InternalSharingModel, ExternalSharingModel
      FROM EntityDefinition
      WHERE QualifiedApiName = :objectName
      LIMIT 1
    ];
    return definitions.isEmpty() ? null : definitions[0];
  }

  /**
   * Field and object names come from the describe, never from user input.
   * @param context Analysed record
   * @return The record with context.getRecordFields() populated
   * @throws WhaException when the record does not exist
   */
  public SObject selectRecord(WhaAccessContext context) {
    String soql =
      'SELECT ' +
      String.join(new List<String>(context.getRecordFields()), ', ') +
      ' FROM ' +
      context.objectName +
      ' WHERE Id = :recordId LIMIT 1';
    List<SObject> records = Database.queryWithBinds(
      soql,
      new Map<String, Object>{ 'recordId' => context.recordId },
      AccessLevel.SYSTEM_MODE
    );
    if (records.isEmpty()) {
      throw new WhaException('Record not found: ' + context.recordId);
    }
    return records[0];
  }
}
