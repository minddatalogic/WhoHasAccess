/**
 * Resolves a Group into the users it stands for, based on Group.Type:
 *   Regular / Queue                       -> GroupMember (nested groups stay lazy)
 *   Role / RoleAndSubordinates(Internal)  -> WhaRoleService
 *   Manager / ManagerAndSubordinatesInt.  -> WhaManagerService
 *   Territory(AndSubordinates)            -> WhaTerritoryService
 *   Organization / portal / partner       -> a count (membership is implicit)
 *   CollaborationGroup                    -> CollaborationGroupMember
 * Also builds the labelled group nodes shown under share rows.
 */
public with sharing class WhaGroupService {
  private static final List<String> INTERNAL_USER_TYPES = new List<String>{
    'Standard'
  };
  private static final List<String> CUSTOMER_PORTAL_USER_TYPES = new List<String>{
    'PowerCustomerSuccess',
    'CustomerSuccess',
    'CspLitePortal'
  };
  private static final List<String> PARTNER_USER_TYPES = new List<String>{
    'PowerPartner'
  };

  private final WhaGroupSelector groupSelector = new WhaGroupSelector();
  private final WhaUserSelector userSelector = new WhaUserSelector();
  private final WhaRoleSelector roleSelector = new WhaRoleSelector();
  private final WhaRoleService roleService = new WhaRoleService();
  private final WhaManagerService managerService = new WhaManagerService();
  private final WhaTerritoryService territoryService = new WhaTerritoryService();

  /**
   * @param groupId Group Id
   * @param afterId Last row of the previous page, or null
   * @return The group's members, resolved by Group.Type
   */
  public List<WhaAccessNodeDTO> expandGroup(Id groupId, Id afterId) {
    Group publicGroup = groupSelector.selectById(groupId);
    Id relatedId = publicGroup.RelatedId;
    switch on publicGroup.Type {
      when 'Role' {
        return roleService.expandRoleUsers(
          relatedId,
          WhaConstants.EXPAND_GROUP,
          publicGroup.Id,
          afterId
        );
      }
      when 'RoleAndSubordinates' {
        return roleService.expandRoleAndSubordinates(relatedId, false, afterId);
      }
      when 'RoleAndSubordinatesInternal' {
        return roleService.expandRoleAndSubordinates(relatedId, true, afterId);
      }
      when 'Manager' {
        return managerService.expandManagerChain(relatedId);
      }
      when 'ManagerAndSubordinatesInternal' {
        return managerService.expandReports(relatedId, true, afterId);
      }
      when 'Territory' {
        return territoryService.expandTerritoryUsers(relatedId, false, afterId);
      }
      when 'TerritoryAndSubordinates' {
        return territoryService.expandTerritoryUsers(relatedId, true, afterId);
      }
      when 'Organization' {
        return countImplicitMembers('All internal users', INTERNAL_USER_TYPES);
      }
      when 'AllCustomerPortal' {
        return countImplicitMembers(
          'All customer portal users',
          CUSTOMER_PORTAL_USER_TYPES
        );
      }
      when 'PRMOrganization' {
        return countImplicitMembers('All partner users', PARTNER_USER_TYPES);
      }
      when 'CollaborationGroup' {
        return expandChatterMembers(relatedId, afterId);
      }
      when else {
        // Regular, Queue, Participant, Dynamic, ChannelProgramGroup, ...
        return expandMembers(publicGroup, afterId);
      }
    }
  }

  /**
   * @param collaborationGroupId Chatter group Id
   * @param afterId Last member row of the previous page, or null
   * @return Member nodes, or a note when Chatter is not available
   */
  public List<WhaAccessNodeDTO> expandChatterMembers(
    Id collaborationGroupId,
    Id afterId
  ) {
    List<WhaAccessNodeDTO> nodes = new List<WhaAccessNodeDTO>();
    try {
      List<SObject> page = groupSelector.selectChatterMemberPage(
        collaborationGroupId,
        afterId
      );
      Id lastRowId = WhaExpandCursor.trimToPage(page);
      Set<Id> userIds = new Set<Id>();
      for (SObject member : page) {
        userIds.add((Id) member.get('MemberId'));
      }
      nodes.addAll(
        WhaNodeFactory.userNodes(userSelector.selectByIds(userIds).values())
      );
      if (lastRowId != null) {
        nodes.add(
          WhaNodeFactory.more(
            WhaConstants.EXPAND_CHATTER,
            collaborationGroupId,
            lastRowId
          )
        );
      }
    } catch (QueryException e) {
      nodes.add(
        WhaNodeFactory.info(
          'Chatter group members unavailable: ' + e.getMessage()
        )
      );
    }
    if (nodes.isEmpty()) {
      nodes.add(WhaNodeFactory.info('No members'));
    }
    return nodes;
  }

  /**
   * One lazy node per group, labelled by type ("Role: CEO", "Queue: Intake").
   * Uses at most four queries however many groups are passed.
   * @param groupIds Group Ids
   * @return Node per group Id; unknown Ids get a placeholder node
   */
  public Map<Id, WhaAccessNodeDTO> buildGroupNodes(Set<Id> groupIds) {
    Map<Id, WhaAccessNodeDTO> nodesById = new Map<Id, WhaAccessNodeDTO>();
    if (groupIds == null || groupIds.isEmpty()) {
      return nodesById;
    }
    List<Group> groups = groupSelector.selectByIds(groupIds);
    Map<Id, String> relatedNames = selectRelatedNames(groups);
    for (Group publicGroup : groups) {
      String nodeType = isRoleGroup(publicGroup.Type)
        ? WhaConstants.NODE_ROLE
        : WhaConstants.NODE_GROUP;
      String label = WhaLabelUtil.groupLabel(
        publicGroup,
        publicGroup.RelatedId == null
          ? null
          : relatedNames.get(publicGroup.RelatedId)
      );
      nodesById.put(
        publicGroup.Id,
        new WhaAccessNodeDTO(nodeType, publicGroup.Id, label)
          .withSubtitle(WhaLabelUtil.groupTypeLabel(publicGroup.Type))
          .lazyOn(WhaConstants.EXPAND_GROUP, publicGroup.Id)
      );
    }
    for (Id groupId : groupIds) {
      if (!nodesById.containsKey(groupId)) {
        nodesById.put(
          groupId,
          WhaNodeFactory.copyOrPlaceholder(null, groupId)
        );
      }
    }
    return nodesById;
  }

  /** Regular groups, queues and other member-based groups, paged. */
  private List<WhaAccessNodeDTO> expandMembers(Group publicGroup, Id afterId) {
    List<GroupMember> page = groupSelector.selectMemberPage(
      publicGroup.Id,
      afterId
    );
    Id lastRowId = WhaExpandCursor.trimToPage(page);
    Set<Id> userIds = new Set<Id>();
    Set<Id> nestedGroupIds = new Set<Id>();
    for (GroupMember member : page) {
      if (WhaNodeFactory.isUserId(member.UserOrGroupId)) {
        userIds.add(member.UserOrGroupId);
      } else {
        nestedGroupIds.add(member.UserOrGroupId);
      }
    }
    List<WhaAccessNodeDTO> nodes = new List<WhaAccessNodeDTO>();
    if (
      afterId == null &&
      publicGroup.DoesIncludeBosses == true &&
      publicGroup.Type == 'Regular'
    ) {
      nodes.add(
        WhaNodeFactory.info(
          'Grant Access Using Hierarchies is ON — members\' managers also get access'
        )
      );
    }
    nodes.addAll(buildGroupNodes(nestedGroupIds).values());
    nodes.addAll(
      WhaNodeFactory.userNodes(userSelector.selectByIds(userIds).values())
    );
    if (lastRowId != null) {
      nodes.add(
        WhaNodeFactory.more(WhaConstants.EXPAND_GROUP, publicGroup.Id, lastRowId)
      );
    }
    if (page.isEmpty() && afterId == null) {
      nodes.add(WhaNodeFactory.info(emptyGroupMessage(publicGroup.Type)));
    }
    return nodes;
  }

  /** Groups whose membership is implicit (every user of a type): a count. */
  private List<WhaAccessNodeDTO> countImplicitMembers(
    String label,
    List<String> userTypes
  ) {
    return new List<WhaAccessNodeDTO>{
      WhaNodeFactory.info(label)
        .withCount(userSelector.countActiveByUserTypes(userTypes))
        .withSubtitle('Membership is implicit — every active user of this type')
    };
  }

  /** Names of the roles, users and territories that groups point to. */
  private Map<Id, String> selectRelatedNames(List<Group> groups) {
    Set<Id> roleIds = new Set<Id>();
    Set<Id> userIds = new Set<Id>();
    Set<Id> territoryIds = new Set<Id>();
    for (Group publicGroup : groups) {
      Id relatedId = publicGroup.RelatedId;
      if (relatedId == null) {
        continue;
      }
      Schema.SObjectType relatedType = relatedId.getSObjectType();
      if (relatedType == UserRole.SObjectType) {
        roleIds.add(relatedId);
      } else if (relatedType == User.SObjectType) {
        userIds.add(relatedId);
      } else {
        territoryIds.add(relatedId);
      }
    }
    Map<Id, String> namesById = new Map<Id, String>();
    for (UserRole role : roleSelector.selectByIds(roleIds).values()) {
      namesById.put(role.Id, role.Name);
    }
    for (User relatedUser : userSelector.selectByIds(userIds).values()) {
      namesById.put(relatedUser.Id, relatedUser.Name);
    }
    namesById.putAll(territoryService.getTerritoryNames(territoryIds));
    return namesById;
  }

  private static Boolean isRoleGroup(String groupType) {
    return groupType == 'Role' ||
      (groupType != null && groupType.startsWith('RoleAndSub'));
  }

  private static String emptyGroupMessage(String groupType) {
    Boolean memberBased = groupType == 'Regular' || groupType == 'Queue';
    return memberBased
      ? 'No members'
      : 'Membership of ' +
          groupType +
          ' groups is managed by Salesforce and not stored as group members';
  }
}
