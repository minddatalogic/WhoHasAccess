/**
 * Effective access of one user on the analysed record, shown in the LWC's
 * "Check effective access" panel. The field names are the LWC contract.
 */
public class WhaUserAccessDTO {
  @AuraEnabled
  public String userId;
  @AuraEnabled
  public String userName;
  @AuraEnabled
  public String profileName;
  @AuraEnabled
  public String roleName;
  @AuraEnabled
  public Boolean isActive;
  @AuraEnabled
  public String maxAccess;
  @AuraEnabled
  public Boolean recordRead = false;
  @AuraEnabled
  public Boolean recordEdit = false;
  @AuraEnabled
  public Boolean recordDelete = false;
  @AuraEnabled
  public Boolean recordTransfer = false;
  @AuraEnabled
  public Boolean recordAll = false;
  @AuraEnabled
  public Boolean objRead = false;
  @AuraEnabled
  public Boolean objCreate = false;
  @AuraEnabled
  public Boolean objEdit = false;
  @AuraEnabled
  public Boolean objDelete = false;
  @AuraEnabled
  public Boolean objViewAll = false;
  @AuraEnabled
  public Boolean objModifyAll = false;
  @AuraEnabled
  public Boolean viewAllData = false;
  @AuraEnabled
  public Boolean modifyAllData = false;
}
