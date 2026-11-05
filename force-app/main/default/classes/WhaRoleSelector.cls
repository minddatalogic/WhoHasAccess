/**
 * Reads roles (UserRole) one level at a time, so large hierarchies are never
 * loaded in full.
 *
 * without sharing / SYSTEM_MODE: WhaAccessGuard runs first.
 */
public without sharing class WhaRoleSelector {
  /**
   * @param roleId Role Id
   * @return The role with its parent, or null when it does not exist
   */
  public UserRole selectById(Id roleId) {
    List<UserRole> roles = [
      SELECT Id, Name, ParentRoleId
      FROM UserRole
      WHERE Id = :roleId
      WITH SYSTEM_MODE
      LIMIT 1
    ];
    return roles.isEmpty() ? null : roles[0];
  }

  /**
   * Walks up the hierarchy one level per query. Deliberate: the alternative is
   * loading the whole UserRole table (5,000+ rows in large orgs). Bounded by
   * maxDepth; Salesforce recommends at most 10 levels.
   * @param firstRoleId Role to start from (included in the result)
   * @param maxDepth Maximum number of roles to return
   * @return Roles from firstRoleId upwards, nearest first
   */
  public List<UserRole> selectAncestors(Id firstRoleId, Integer maxDepth) {
    List<UserRole> ancestors = new List<UserRole>();
    Id currentRoleId = firstRoleId;
    while (currentRoleId != null && ancestors.size() < maxDepth) {
      UserRole role = selectById(currentRoleId);
      if (role == null) {
        break;
      }
      ancestors.add(role);
      currentRoleId = role.ParentRoleId;
    }
    return ancestors;
  }

  /**
   * @param roleIds Role Ids
   * @return Roles (Id, Name) by Id
   */
  public Map<Id, UserRole> selectByIds(Set<Id> roleIds) {
    if (roleIds == null || roleIds.isEmpty()) {
      return new Map<Id, UserRole>();
    }
    return new Map<Id, UserRole>(
      [SELECT Id, Name FROM UserRole WHERE Id IN :roleIds WITH SYSTEM_MODE]
    );
  }

  /**
   * @param parentRoleId Role Id
   * @return Number of direct child roles
   */
  public Integer countChildren(Id parentRoleId) {
    return [
      SELECT COUNT()
      FROM UserRole
      WHERE ParentRoleId = :parentRoleId
      WITH SYSTEM_MODE
    ];
  }

  /**
   * @param parentRoleId Role Id
   * @param maxRows Row limit
   * @return Direct child roles (Id, Name, PortalType) in name order
   */
  public List<UserRole> selectChildren(Id parentRoleId, Integer maxRows) {
    return [
      SELECT Id, Name, PortalType
      FROM UserRole
      WHERE ParentRoleId = :parentRoleId
      WITH SYSTEM_MODE
      ORDER BY Name
      LIMIT :maxRows
    ];
  }
}
