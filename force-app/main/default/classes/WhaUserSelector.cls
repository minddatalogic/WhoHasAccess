/**
 * Reads users for the access tree: by Id, by role, by manager, and counts.
 *
 * without sharing / SYSTEM_MODE: User sharing may be private, but the tool must
 * name everyone who has access. WhaAccessGuard runs first.
 */
public without sharing class WhaUserSelector {
  /**
   * @param userIds User Ids
   * @return Users (Name, IsActive, Profile, Role) by Id, in name order
   */
  public Map<Id, User> selectByIds(Set<Id> userIds) {
    if (userIds == null || userIds.isEmpty()) {
      return new Map<Id, User>();
    }
    return new Map<Id, User>(
      [
        SELECT Id, Name, IsActive, Profile.Name, UserRole.Name
        FROM User
        WHERE Id IN :userIds
        WITH SYSTEM_MODE
        ORDER BY Name
      ]
    );
  }

  /**
   * @param userId User Id
   * @return The user with manager and role hierarchy fields
   * @throws WhaException when the user does not exist
   */
  public User selectWithHierarchyById(Id userId) {
    List<User> users = [
      SELECT
        Id,
        Name,
        IsActive,
        ManagerId,
        UserRoleId,
        Profile.Name,
        UserRole.Name,
        UserRole.ParentRoleId
      FROM User
      WHERE Id = :userId
      WITH SYSTEM_MODE
      LIMIT 1
    ];
    if (users.isEmpty()) {
      throw new WhaException('User not found: ' + userId);
    }
    return users[0];
  }

  /**
   * Follows User.ManagerId one level per query, stopping at a loop or maxDepth.
   * @param userId User to start from (included in the result)
   * @param maxDepth Maximum number of users to return
   * @return The user followed by their managers, nearest first
   */
  public List<User> selectManagerChain(Id userId, Integer maxDepth) {
    List<User> chain = new List<User>();
    Set<Id> visitedIds = new Set<Id>();
    Id currentId = userId;
    while (
      currentId != null &&
      !visitedIds.contains(currentId) &&
      visitedIds.size() < maxDepth
    ) {
      visitedIds.add(currentId);
      User current = selectWithHierarchyById(currentId);
      chain.add(current);
      currentId = current.ManagerId;
    }
    return chain;
  }

  /**
   * @param roleId Role Id
   * @param afterId Last user of the previous page, or null
   * @return Up to WhaConstants.QUERY_LIMIT active users in the role, by Id
   */
  public List<User> selectActiveByRolePage(Id roleId, Id afterId) {
    Integer rowLimit = WhaConstants.QUERY_LIMIT;
    if (afterId == null) {
      return [
        SELECT Id, Name, IsActive, Profile.Name, UserRole.Name
        FROM User
        WHERE UserRoleId = :roleId AND IsActive = TRUE
        WITH SYSTEM_MODE
        ORDER BY Id
        LIMIT :rowLimit
      ];
    }
    return [
      SELECT Id, Name, IsActive, Profile.Name, UserRole.Name
      FROM User
      WHERE UserRoleId = :roleId AND IsActive = TRUE AND Id > :afterId
      WITH SYSTEM_MODE
      ORDER BY Id
      LIMIT :rowLimit
    ];
  }

  /**
   * @param managerId Manager's user Id
   * @param afterId Last user of the previous page, or null
   * @return Up to WhaConstants.QUERY_LIMIT active direct reports, by Id
   */
  public List<User> selectActiveReportsPage(Id managerId, Id afterId) {
    Integer rowLimit = WhaConstants.QUERY_LIMIT;
    if (afterId == null) {
      return [
        SELECT Id, Name, IsActive, Profile.Name, UserRole.Name
        FROM User
        WHERE ManagerId = :managerId AND IsActive = TRUE
        WITH SYSTEM_MODE
        ORDER BY Id
        LIMIT :rowLimit
      ];
    }
    return [
      SELECT Id, Name, IsActive, Profile.Name, UserRole.Name
      FROM User
      WHERE ManagerId = :managerId AND IsActive = TRUE AND Id > :afterId
      WITH SYSTEM_MODE
      ORDER BY Id
      LIMIT :rowLimit
    ];
  }

  /**
   * COUNT() is charged one query row.
   * @param userTypes User.UserType values
   * @return Number of active users of those types
   */
  public Integer countActiveByUserTypes(List<String> userTypes) {
    return [
      SELECT COUNT()
      FROM User
      WHERE IsActive = TRUE AND UserType IN :userTypes
      WITH SYSTEM_MODE
    ];
  }

  /**
   * @param roleIds Role Ids
   * @return Active user count per role (missing = 0)
   */
  public Map<Id, Integer> countActiveByRole(Set<Id> roleIds) {
    Map<Id, Integer> countsByRole = new Map<Id, Integer>();
    if (roleIds == null || roleIds.isEmpty()) {
      return countsByRole;
    }
    for (AggregateResult result : [
      SELECT UserRoleId roleId, COUNT(Id) total
      FROM User
      WHERE UserRoleId IN :roleIds AND IsActive = TRUE
      WITH SYSTEM_MODE
      GROUP BY UserRoleId
    ]) {
      countsByRole.put((Id) result.get('roleId'), (Integer) result.get('total'));
    }
    return countsByRole;
  }
}
