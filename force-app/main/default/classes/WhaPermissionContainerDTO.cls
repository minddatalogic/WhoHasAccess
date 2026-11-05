/**
 * A PermissionSet row seen as a container of access: a Profile, a Permission
 * Set or a Permission Set Group. PermissionSet.Type is Profile, Regular,
 * Group (PSG) or Session.
 */
public class WhaPermissionContainerDTO {
  private static final String SEPARATOR = '|';

  public Id permissionSetId;
  public Id permissionSetGroupId;
  public String label;
  public String kind; // WhaConstants.NODE_PROFILE, NODE_PERMSET or NODE_PSG
  public String grantedAccess;

  /**
   * @param permissionSet PermissionSet with Id, Label, Type, IsOwnedByProfile,
   *        Profile.Name and PermissionSetGroupId queried
   * @param grantedAccess Label of the access it grants, e.g. "View All Data"
   * @return The container
   */
  public static WhaPermissionContainerDTO fromPermissionSet(
    PermissionSet permissionSet,
    String grantedAccess
  ) {
    WhaPermissionContainerDTO container = new WhaPermissionContainerDTO();
    container.permissionSetId = permissionSet.Id;
    container.permissionSetGroupId = permissionSet.PermissionSetGroupId;
    container.grantedAccess = grantedAccess;
    if (permissionSet.IsOwnedByProfile) {
      container.kind = WhaConstants.NODE_PROFILE;
      container.label = permissionSet.Profile?.Name ?? permissionSet.Label;
    } else if (permissionSet.Type == 'Group') {
      container.kind = WhaConstants.NODE_PSG;
      container.label = permissionSet.Label;
    } else {
      container.kind = WhaConstants.NODE_PERMSET;
      container.label = permissionSet.Type == 'Session'
        ? permissionSet.Label + ' (session-based)'
        : permissionSet.Label;
    }
    return container;
  }

  /**
   * @return Expand id for the container's users: "psId" or "psId|psgId"
   */
  public String toExpandId() {
    return permissionSetGroupId == null
      ? String.valueOf(permissionSetId)
      : permissionSetId + SEPARATOR + permissionSetGroupId;
  }

  /**
   * Reads an expand id built by toExpandId.
   * @param expandId "psId" or "psId|psgId"
   * @return [permissionSetId, permissionSetGroupId or null]
   */
  public static List<Id> parseExpandId(String expandId) {
    List<String> parts = expandId.split('\\' + SEPARATOR);
    return new List<Id>{ (Id) parts[0], parts.size() > 1 ? (Id) parts[1] : null };
  }
}
