/**
 * The record being analysed and facts about its object that come from the
 * describe: name field, owner field and parent lookups. Runs no queries.
 */
public class WhaAccessContext {
  public final Id recordId;
  public final Schema.DescribeSObjectResult objectDescribe;
  public final String objectName;
  public final String objectLabel;

  private Map<String, Schema.SObjectField> fieldsByName;
  private String nameField;
  private Boolean nameFieldResolved = false;
  private List<String> parentFieldNames;

  /**
   * @param recordId Record to analyse
   * @throws WhaException when recordId is null
   */
  public WhaAccessContext(Id recordId) {
    if (recordId == null) {
      throw new WhaException('A record Id is required.');
    }
    this.recordId = recordId;
    this.objectDescribe = recordId.getSObjectType().getDescribe();
    this.objectName = objectDescribe.getName();
    this.objectLabel = objectDescribe.getLabel();
  }

  /**
   * @return API name of the object's name field, or null if it has none
   */
  public String getNameField() {
    if (!nameFieldResolved) {
      for (Schema.SObjectField field : getFields().values()) {
        Schema.DescribeFieldResult fieldDescribe = field.getDescribe();
        if (fieldDescribe.isNameField()) {
          nameField = fieldDescribe.getName();
          break;
        }
      }
      nameFieldResolved = true;
    }
    return nameField;
  }

  /**
   * @return True when the object has an OwnerId field
   */
  public Boolean hasOwnerField() {
    return getFields().containsKey('ownerid');
  }

  /**
   * Master-detail fields, plus AccountId on standard objects that are
   * "controlled by parent" (Contact, Order, Asset...).
   * @return Field API names; empty when there are none
   */
  public List<String> getParentFieldNames() {
    if (parentFieldNames != null) {
      return parentFieldNames;
    }
    parentFieldNames = new List<String>();
    for (Schema.SObjectField field : getFields().values()) {
      Schema.DescribeFieldResult fieldDescribe = field.getDescribe();
      if (fieldDescribe.getType() != Schema.DisplayType.REFERENCE) {
        continue;
      }
      Boolean masterDetail = fieldDescribe.getRelationshipOrder() != null;
      Boolean standardParent =
        !objectDescribe.isCustom() && fieldDescribe.getName() == 'AccountId';
      if (masterDetail || standardParent) {
        parentFieldNames.add(fieldDescribe.getName());
      }
    }
    return parentFieldNames;
  }

  /**
   * @return Fields to query on the record: Id, name, owner and parent lookups
   */
  public Set<String> getRecordFields() {
    Set<String> fields = new Set<String>{ 'Id' };
    if (getNameField() != null) {
      fields.add(getNameField());
    }
    if (hasOwnerField()) {
      fields.add('OwnerId');
    }
    fields.addAll(getParentFieldNames());
    return fields;
  }

  /**
   * @param record The analysed record, queried with getRecordFields()
   * @return Its name, or its Id when the name is blank
   */
  public String getRecordName(SObject record) {
    Object name = getNameField() == null ? null : record.get(getNameField());
    return name == null ? String.valueOf(record.Id) : String.valueOf(name);
  }

  private Map<String, Schema.SObjectField> getFields() {
    if (fieldsByName == null) {
      fieldsByName = objectDescribe.fields.getMap();
    }
    return fieldsByName;
  }
}
