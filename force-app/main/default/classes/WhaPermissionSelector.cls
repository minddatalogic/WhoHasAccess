/**
 * Reads profiles, permission sets, permission set groups and their
 * assignments (ObjectPermissions, PermissionSet, PermissionSetAssignment,
 * PermissionSetGroup). Muting permission sets are left out.
 *
 * without sharing / SYSTEM_MODE: the tool lists other users' assignments.
 * WhaAccessGuard runs first.
 */
public without sharing class WhaPermissionSelector {
  /**
   * @param objectName Object API name
   * @return ObjectPermissions granting View All or Modify All on the object
   */
  public List<ObjectPermissions> selectViewAllOrModifyAll(String objectName) {
    return [
      SELECT
        ParentId,
        Parent.Label,
        Parent.Type,
        Parent.IsOwnedByProfile,
        Parent.Profile.Name,
        Parent.PermissionSetGroupId,
        PermissionsViewAllRecords,
        PermissionsModifyAllRecords
      FROM ObjectPermissions
      WHERE
        SobjectType = :objectName
        AND (PermissionsViewAllRecords = TRUE
        OR PermissionsModifyAllRecords = TRUE)
        AND Parent.Type != 'Muting'
      WITH SYSTEM_MODE
    ];
  }

  /**
   * @return Permission sets (incl. profiles) granting View or Modify All Data
   */
  public List<PermissionSet> selectViewAllOrModifyAllData() {
    return [
      SELECT
        Id,
        Label,
        Type,
        IsOwnedByProfile,
        Profile.Name,
        PermissionSetGroupId,
        PermissionsViewAllData,
        PermissionsModifyAllData
      FROM PermissionSet
      WHERE
        (PermissionsViewAllData = TRUE
        OR PermissionsModifyAllData = TRUE)
        AND Type != 'Muting'
      WITH SYSTEM_MODE
    ];
  }

  /**
   * @param objectName Object API name
   * @return ObjectPermissions granting Read on the object
   */
  public List<ObjectPermissions> selectObjectRead(String objectName) {
    return [
      SELECT
        ParentId,
        Parent.Label,
        Parent.Type,
        Parent.IsOwnedByProfile,
        Parent.Profile.Name,
        Parent.PermissionSetGroupId,
        PermissionsRead,
        PermissionsEdit
      FROM ObjectPermissions
      WHERE
        SobjectType = :objectName
        AND PermissionsRead = TRUE
        AND Parent.Type != 'Muting'
      WITH SYSTEM_MODE
    ];
  }

  /**
   * @param permissionSetIds Permission set Ids
   * @return Active assignee count per permission set (missing = 0)
   */
  public Map<Id, Integer> countActiveAssignments(Set<Id> permissionSetIds) {
    Map<Id, Integer> countsByPermissionSet = new Map<Id, Integer>();
    if (permissionSetIds == null || permissionSetIds.isEmpty()) {
      return countsByPermissionSet;
    }
    for (AggregateResult result : [
      SELECT PermissionSetId permissionSetId, COUNT(Id) total
      FROM PermissionSetAssignment
      WHERE PermissionSetId IN :permissionSetIds AND Assignee.IsActive = TRUE
      WITH SYSTEM_MODE
      GROUP BY PermissionSetId
    ]) {
      countsByPermissionSet.put(
        (Id) result.get('permissionSetId'),
        (Integer) result.get('total')
      );
    }
    return countsByPermissionSet;
  }

  /**
   * @param permissionSetGroupIds Permission set group Ids
   * @return MasterLabel per permission set group
   */
  public Map<Id, String> selectGroupLabels(Set<Id> permissionSetGroupIds) {
    Map<Id, String> labelsById = new Map<Id, String>();
    if (permissionSetGroupIds == null || permissionSetGroupIds.isEmpty()) {
      return labelsById;
    }
    for (PermissionSetGroup permissionSetGroup : [
      SELECT Id, MasterLabel
      FROM PermissionSetGroup
      WHERE Id IN :permissionSetGroupIds
      WITH SYSTEM_MODE
    ]) {
      labelsById.put(permissionSetGroup.Id, permissionSetGroup.MasterLabel);
    }
    return labelsById;
  }

  /**
   * Active assignments of a permission set, or of the group it belongs to.
   * @param permissionSetId Permission set (or profile) Id
   * @param permissionSetGroupId Group Id, or null
   * @param afterId Last assignment of the previous page, or null
   * @return Up to WhaConstants.QUERY_LIMIT assignments with Assignee fields
   */
  public List<PermissionSetAssignment> selectActiveAssignmentPage(
    Id permissionSetId,
    Id permissionSetGroupId,
    Id afterId
  ) {
    Map<String, Object> binds = new Map<String, Object>{
      'permissionSetId' => permissionSetId,
      'permissionSetGroupId' => permissionSetGroupId
    };
    String soql =
      'SELECT Id, AssigneeId, Assignee.Name, Assignee.IsActive, Assignee.Profile.Name, Assignee.UserRole.Name' +
      ' FROM PermissionSetAssignment' +
      ' WHERE (PermissionSetId = :permissionSetId' +
      ' OR (PermissionSetGroupId != NULL AND PermissionSetGroupId = :permissionSetGroupId))' +
      ' AND Assignee.IsActive = TRUE';
    if (afterId != null) {
      soql += ' AND Id > :afterId';
      binds.put('afterId', afterId);
    }
    soql += ' ORDER BY Id LIMIT ' + WhaConstants.QUERY_LIMIT;
    return (List<PermissionSetAssignment>) Database.queryWithBinds(
      soql,
      binds,
      AccessLevel.SYSTEM_MODE
    );
  }

  /**
   * @param userId User Id
   * @param objectName Object API name
   * @return The user's ObjectPermissions on the object, one per assigned set
   */
  public List<ObjectPermissions> selectUserObjectPermissions(
    Id userId,
    String objectName
  ) {
    return [
      SELECT
        PermissionsRead,
        PermissionsCreate,
        PermissionsEdit,
        PermissionsDelete,
        PermissionsViewAllRecords,
        PermissionsModifyAllRecords
      FROM ObjectPermissions
      WHERE
        SobjectType = :objectName
        AND ParentId IN (
          SELECT PermissionSetId
          FROM PermissionSetAssignment
          WHERE AssigneeId = :userId
        )
      WITH SYSTEM_MODE
    ];
  }

  /**
   * @param userId User Id
   * @return The user's assigned permission sets with the All Data flags
   */
  public List<PermissionSet> selectUserPermissionSets(Id userId) {
    return [
      SELECT PermissionsViewAllData, PermissionsModifyAllData
      FROM PermissionSet
      WHERE
        Id IN (
          SELECT PermissionSetId
          FROM PermissionSetAssignment
          WHERE AssigneeId = :userId
        )
      WITH SYSTEM_MODE
    ];
  }
}
