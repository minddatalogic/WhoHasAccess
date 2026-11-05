/**
 * Turns Salesforce API values (sharing models, access levels, row causes,
 * group types) into the labels shown in the access tree. Pure, no queries.
 */
public class WhaLabelUtil {
  private static final String APEX_SHARING_PREFIX = 'Apex Sharing: ';
  private static final String CUSTOM_SUFFIX = '__c';

  private static final Map<String, String> SHARING_MODEL_LABELS = new Map<String, String>{
    'Private' => 'Private',
    'Read' => 'Public Read Only',
    'ReadWrite' => 'Public Read/Write',
    'ReadWriteTransfer' => 'Public Read/Write/Transfer',
    'FullAccess' => 'Public Full Access',
    'ControlledByParent' => 'Controlled by Parent',
    'ControlledByLeadOrContact' => 'Controlled by Lead or Contact',
    'ControlledByCampaign' => 'Controlled by Campaign'
  };

  private static final Map<String, String> ACCESS_LEVEL_LABELS = new Map<String, String>{
    'Read' => 'Read Only',
    'Edit' => 'Read/Write',
    'All' => 'Full Access'
  };

  private static final Map<String, String> ROW_CAUSE_LABELS = new Map<String, String>{
    'Owner' => 'Owner',
    'Manual' => 'Manual Share',
    'Rule' => 'Sharing Rule',
    'GuestRule' => 'Guest User Sharing Rule',
    'ImplicitChild' => 'Implicit Child',
    'ImplicitParent' => 'Implicit Parent',
    'ImplicitPerson' => 'Person Account',
    'Team' => 'Team',
    'Territory' => 'Territory',
    'TerritoryManual' => 'Territory (Manual)',
    'TerritoryRule' => 'Territory Rule',
    'Territory2AssociationManual' => 'Territory Assignment (Manual)',
    'Territory2Forecast' => 'Territory Forecast',
    'PortalImplicit' => 'Portal Implicit',
    'RelatedPortalUser' => 'Related Portal User'
  };

  private static final Map<String, String> ROW_CAUSE_HELP = new Map<String, String>{
    'Owner' => 'The user or queue in OwnerId',
    'Manual' => 'Shared manually from the UI or by code',
    'Rule' => 'Created by an owner- or criteria-based sharing rule',
    'GuestRule' => 'Guest user sharing rule',
    'ImplicitChild' => 'Access from owning / sharing a child record (Contact, Opportunity, Case)',
    'ImplicitParent' => 'A child record shares access with its parent',
    'ImplicitPerson' => 'Person account sharing',
    'Team' => 'Member of the Account / Opportunity / Case team',
    'Territory' => 'User is in an assigned territory',
    'TerritoryManual' => 'Record manually shared to a territory',
    'TerritoryRule' => 'A territory rule shared the record',
    'Territory2AssociationManual' => 'Record manually assigned to a territory',
    'Territory2Forecast' => 'Territory forecasting shared the record',
    'PortalImplicit' => 'Portal / community user implicit access'
  };

  private static final Map<String, String> GROUP_TYPE_HELP = new Map<String, String>{
    'Regular' => 'Public group — resolved via GroupMember',
    'Queue' => 'Queue — resolved via GroupMember',
    'Role' => 'Users in this role only',
    'RoleAndSubordinates' => 'Role plus every subordinate role',
    'RoleAndSubordinatesInternal' => 'Role plus internal subordinate roles',
    'Manager' => 'User plus their direct and indirect managers',
    'ManagerAndSubordinatesInternal' => 'User plus their direct and indirect reports',
    'Organization' => 'Every internal user',
    'Territory' => 'Users in this territory',
    'TerritoryAndSubordinates' => 'Territory plus sub-territories',
    'AllCustomerPortal' => 'All customer portal users',
    'PRMOrganization' => 'All partner users',
    'CollaborationGroup' => 'Chatter group — resolved via CollaborationGroupMember',
    'ChannelProgramGroup' => 'Partners in a channel program',
    'Participant' => 'Compliant Data Sharing participant group',
    'Dynamic' => 'Dynamic group',
    'DataAnalytics' => 'CRM Analytics / Data Cloud system group',
    'SharingRecordCollGroup' => 'Sharing record collection group'
  };

  /** Group.Type values whose label uses the related role / user / territory name. */
  private static final Map<String, String> RELATED_GROUP_PREFIXES = new Map<String, String>{
    'Role' => 'Role: ',
    'RoleAndSubordinates' => 'Role & Subordinates: ',
    'RoleAndSubordinatesInternal' => 'Role & Internal Subordinates: ',
    'Manager' => 'Managers of: ',
    'ManagerAndSubordinatesInternal' => 'Manager & Subordinates: ',
    'Territory' => 'Territory: ',
    'TerritoryAndSubordinates' => 'Territory & Subordinates: '
  };

  private WhaLabelUtil() {
    // static helpers only
  }

  /**
   * @param model EntityDefinition.InternalSharingModel / ExternalSharingModel
   * @return Label, "n/a" for null, or the API value when unknown
   * @example WhaLabelUtil.sharingModelLabel('Read'); // 'Public Read Only'
   */
  public static String sharingModelLabel(String model) {
    if (model == null) {
      return 'n/a';
    }
    return SHARING_MODEL_LABELS.containsKey(model)
      ? SHARING_MODEL_LABELS.get(model)
      : model;
  }

  /**
   * @param level Share table access level: Read, Edit or All
   * @return Label, or the API value when unknown
   */
  public static String accessLevelLabel(String level) {
    return level != null && ACCESS_LEVEL_LABELS.containsKey(level)
      ? ACCESS_LEVEL_LABELS.get(level)
      : level;
  }

  /**
   * Fallback label when the org's RowCause picklist has none.
   * @param cause RowCause API value
   * @return Label; Apex sharing reasons become "Apex Sharing: Reason Name"
   */
  public static String rowCauseLabel(String cause) {
    if (cause != null && ROW_CAUSE_LABELS.containsKey(cause)) {
      return ROW_CAUSE_LABELS.get(cause);
    }
    if (isApexSharingReason(cause)) {
      return APEX_SHARING_PREFIX +
        cause.removeEnd(CUSTOM_SUFFIX).replace('_', ' ');
    }
    return cause;
  }

  /**
   * @param cause RowCause API value
   * @return One-line explanation, or null when there is none
   */
  public static String rowCauseHelp(String cause) {
    if (cause != null && ROW_CAUSE_HELP.containsKey(cause)) {
      return ROW_CAUSE_HELP.get(cause);
    }
    return isApexSharingReason(cause) ? 'Apex managed sharing reason' : null;
  }

  /**
   * @param publicGroup Group with Name, DeveloperName and Type
   * @param relatedName Name of the related role / user / territory, or null
   * @return Label such as "Public Group: Sales" or "Role: CEO"
   */
  public static String groupLabel(Group publicGroup, String relatedName) {
    String type = publicGroup.Type;
    if (type == 'Regular') {
      return 'Public Group: ' + publicGroup.Name;
    }
    if (type == 'Queue') {
      return 'Queue: ' + publicGroup.Name;
    }
    if (type == 'Organization') {
      return 'All Internal Users';
    }
    if (type != null && RELATED_GROUP_PREFIXES.containsKey(type)) {
      return RELATED_GROUP_PREFIXES.get(type) +
        (relatedName ?? publicGroup.Name);
    }
    return type + ': ' + (publicGroup.Name ?? publicGroup.DeveloperName);
  }

  /**
   * @param type Group.Type
   * @return How membership of that group type is resolved, or the type itself
   */
  public static String groupTypeLabel(String type) {
    return type != null && GROUP_TYPE_HELP.containsKey(type)
      ? GROUP_TYPE_HELP.get(type)
      : type;
  }

  private static Boolean isApexSharingReason(String cause) {
    return cause != null && cause.endsWith(CUSTOM_SUFFIX);
  }
}
