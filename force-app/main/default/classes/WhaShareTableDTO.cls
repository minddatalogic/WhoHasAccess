/**
 * Describes an object's share table. Standard objects use AccountShare with
 * AccountId / AccountAccessLevel; custom objects use Obj__Share with
 * ParentId / AccessLevel.
 */
public class WhaShareTableDTO {
  public String shareObject;
  public String parentField;
  public String levelField;
  public Map<String, String> causeLabels = new Map<String, String>();

  /**
   * @param objectDescribe Describe of the object that owns the share table
   * @return The share table, or null when the object has none (for example a
   *         Public Read/Write custom object)
   */
  public static WhaShareTableDTO describeFor(
    Schema.DescribeSObjectResult objectDescribe
  ) {
    String objectName = objectDescribe.getName();
    String shareName = objectDescribe.isCustom()
      ? objectName.removeEnd('__c') + '__Share'
      : objectName + 'Share';
    Schema.DescribeSObjectResult shareDescribe;
    try {
      shareDescribe = Schema.describeSObjects(new List<String>{ shareName })[0];
    } catch (System.NoAccessException e) {
      return null; // share table name exists but is not usable (e.g. Product2Share)
    } catch (System.InvalidParameterValueException e) {
      return null; // no share table for this object
    }
    Map<String, Schema.SObjectField> fields = shareDescribe.fields.getMap();
    WhaShareTableDTO shareTable = new WhaShareTableDTO();
    shareTable.shareObject = shareDescribe.getName();
    shareTable.parentField = fields.containsKey('parentid')
      ? 'ParentId'
      : objectName + 'Id';
    shareTable.levelField = fields.containsKey('accesslevel')
      ? 'AccessLevel'
      : objectName + 'AccessLevel';
    if (
      !fields.containsKey(shareTable.parentField.toLowerCase()) ||
      !fields.containsKey(shareTable.levelField.toLowerCase())
    ) {
      return null;
    }
    if (fields.containsKey('rowcause')) {
      for (
        Schema.PicklistEntry entry : fields.get('rowcause')
          .getDescribe()
          .getPicklistValues()
      ) {
        shareTable.causeLabels.put(entry.getValue(), entry.getLabel());
      }
    }
    return shareTable;
  }

  /**
   * Uses the org's own RowCause picklist label, so new and custom causes are covered.
   * @param cause RowCause API value
   * @return Label shown in the tree
   */
  public String labelFor(String cause) {
    String label = causeLabels.get(cause);
    if (String.isBlank(label)) {
      return WhaLabelUtil.rowCauseLabel(cause);
    }
    return cause != null && cause.endsWith('__c')
      ? 'Apex Sharing: ' + label
      : label;
  }
}
