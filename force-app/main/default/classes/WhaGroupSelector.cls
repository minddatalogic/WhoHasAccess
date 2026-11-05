/**
 * Reads public groups, queues and their members (Group, GroupMember) and
 * Chatter group members (CollaborationGroupMember).
 *
 * without sharing / SYSTEM_MODE: WhaAccessGuard runs first.
 */
public without sharing class WhaGroupSelector {
  /**
   * @param groupId Group Id
   * @return The group (Name, Type, RelatedId, DoesIncludeBosses)
   * @throws WhaException when the group does not exist
   */
  public Group selectById(Id groupId) {
    List<Group> groups = [
      SELECT Id, Name, Type, RelatedId, DoesIncludeBosses
      FROM Group
      WHERE Id = :groupId
      WITH SYSTEM_MODE
      LIMIT 1
    ];
    if (groups.isEmpty()) {
      throw new WhaException('Group not found: ' + groupId);
    }
    return groups[0];
  }

  /**
   * @param groupIds Group Ids
   * @return Groups (Name, DeveloperName, Type, RelatedId)
   */
  public List<Group> selectByIds(Set<Id> groupIds) {
    if (groupIds == null || groupIds.isEmpty()) {
      return new List<Group>();
    }
    return [
      SELECT Id, Name, DeveloperName, Type, RelatedId
      FROM Group
      WHERE Id IN :groupIds
      WITH SYSTEM_MODE
    ];
  }

  /**
   * @param groupId Group Id
   * @param afterId Last member row of the previous page, or null
   * @return Up to WhaConstants.QUERY_LIMIT members (users or groups), by Id
   */
  public List<GroupMember> selectMemberPage(Id groupId, Id afterId) {
    Integer rowLimit = WhaConstants.QUERY_LIMIT;
    if (afterId == null) {
      return [
        SELECT Id, UserOrGroupId
        FROM GroupMember
        WHERE GroupId = :groupId
        WITH SYSTEM_MODE
        ORDER BY Id
        LIMIT :rowLimit
      ];
    }
    return [
      SELECT Id, UserOrGroupId
      FROM GroupMember
      WHERE GroupId = :groupId AND Id > :afterId
      WITH SYSTEM_MODE
      ORDER BY Id
      LIMIT :rowLimit
    ];
  }

  /**
   * Dynamic SOQL so the class compiles in orgs where Chatter is off.
   * @param collaborationGroupId Chatter group Id
   * @param afterId Last member row of the previous page, or null
   * @return Up to WhaConstants.QUERY_LIMIT rows with Id and MemberId, by Id
   * @throws QueryException when Chatter groups are not available
   */
  public List<SObject> selectChatterMemberPage(
    Id collaborationGroupId,
    Id afterId
  ) {
    Map<String, Object> binds = new Map<String, Object>{
      'collaborationGroupId' => collaborationGroupId
    };
    String soql = 'SELECT Id, MemberId FROM CollaborationGroupMember WHERE CollaborationGroupId = :collaborationGroupId';
    if (afterId != null) {
      soql += ' AND Id > :afterId';
      binds.put('afterId', afterId);
    }
    soql += ' ORDER BY Id LIMIT ' + WhaConstants.QUERY_LIMIT;
    return Database.queryWithBinds(soql, binds, AccessLevel.SYSTEM_MODE);
  }
}
