/**
 * Loads the children of a lazy node. Routes each expand type to the service
 * that owns it; each call returns at most MAX_CHILDREN nodes plus a "Load more"
 * node when there are more (see WhaExpandCursor).
 */
public with sharing class WhaExpandService {
  private final WhaAccessContext context;

  /**
   * @param context Analysed record
   */
  public WhaExpandService(WhaAccessContext context) {
    this.context = context;
  }

  /**
   * @param expandType One of WhaConstants.EXPAND_*
   * @param rawExpandId The node's expandId, optionally with a paging cursor
   * @return Child nodes
   * @throws WhaException when the expand type is unknown or the Id is missing
   */
  public List<WhaAccessNodeDTO> expand(String expandType, String rawExpandId) {
    if (String.isBlank(rawExpandId)) {
      throw new WhaException('An expand Id is required.');
    }
    WhaExpandCursor cursor = new WhaExpandCursor(rawExpandId);
    Id afterId = cursor.afterId;
    // Literals must match WhaConstants.EXPAND_* (switch needs literals).
    switch on expandType {
      when 'SHARE_ROWS' {
        return new WhaShareService(context)
          .expandShareRows(cursor.baseId, afterId);
      }
      when 'PERMSET' {
        return new WhaPermissionService(context)
          .expandAssignedUsers(cursor.baseId, afterId);
      }
      when 'GROUP' {
        return new WhaGroupService()
          .expandGroup(cursor.baseRecordId(), afterId);
      }
      when 'CHATTER' {
        return new WhaGroupService()
          .expandChatterMembers(cursor.baseRecordId(), afterId);
      }
      when 'ROLE' {
        Id roleId = cursor.baseRecordId();
        return new WhaRoleService()
          .expandRoleUsers(roleId, WhaConstants.EXPAND_ROLE, roleId, afterId);
      }
      when 'ROLE_SUB' {
        return new WhaRoleService()
          .expandRoleAndSubordinates(cursor.baseRecordId(), false, afterId);
      }
      when 'ROLE_SUB_INT' {
        return new WhaRoleService()
          .expandRoleAndSubordinates(cursor.baseRecordId(), true, afterId);
      }
      when 'MANAGER_UP' {
        return new WhaManagerService()
          .expandManagerChain(cursor.baseRecordId());
      }
      when 'MANAGER_SUB' {
        return new WhaManagerService()
          .expandReports(cursor.baseRecordId(), false, afterId);
      }
      when 'TERRITORY' {
        return new WhaTerritoryService()
          .expandTerritoryUsers(cursor.baseRecordId(), false, afterId);
      }
      when 'TERRITORY_SUB' {
        return new WhaTerritoryService()
          .expandTerritoryUsers(cursor.baseRecordId(), true, afterId);
      }
      when else {
        throw new WhaException('Unknown expand type: ' + expandType);
      }
    }
  }
}
