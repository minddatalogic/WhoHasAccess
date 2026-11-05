/**
 * Role-based access: managers above the record owner, users in a role, and
 * a role with its subordinate roles. Queries go through the selectors.
 */
public with sharing class WhaRoleService {
  private final WhaUserSelector userSelector = new WhaUserSelector();
  private final WhaRoleSelector roleSelector = new WhaRoleSelector();

  /**
   * Roles above the owner's role, which inherit the owner's access when
   * "Grant Access Using Hierarchies" is on.
   * @param ownerId Record OwnerId (a user or a queue)
   * @return The "Role Hierarchy above Owner" branch
   */
  public WhaAccessNodeDTO buildHierarchyAboveOwner(Id ownerId) {
    WhaAccessNodeDTO branch = WhaNodeFactory.category(
      'Role Hierarchy above Owner'
    );
    if (!WhaNodeFactory.isUserId(ownerId)) {
      return branch
        .withSubtitle('Owner is a queue — no role hierarchy inheritance')
        .add(WhaNodeFactory.info('Not applicable'));
    }
    User owner = userSelector.selectWithHierarchyById(ownerId);
    if (owner.UserRoleId == null) {
      return branch
        .withSubtitle('Owner ' + owner.Name + ' has no role')
        .add(WhaNodeFactory.info('No managers inherit access'));
    }
    branch.withSubtitle(
      'Owner role: ' +
        owner.UserRole.Name +
        ' · assumes "Grant Access Using Hierarchies" (always on for standard objects)'
    );
    List<UserRole> ancestors = roleSelector.selectAncestors(
      owner.UserRole.ParentRoleId,
      WhaConstants.MAX_ROLE_DEPTH
    );
    if (ancestors.isEmpty()) {
      return branch.add(
        WhaNodeFactory.info('Owner is at the top of the hierarchy')
      );
    }
    addAncestorNodes(branch, ancestors);
    return branch;
  }

  /**
   * Active users of one role, one page at a time.
   * @param roleId Role Id
   * @param pageExpandType Expand type for the "Load more" node
   * @param cursorOwnerId Id the "Load more" node re-expands (role or group)
   * @param afterId Last user of the previous page, or null
   * @return User nodes sorted by name, plus a MORE node when there are more
   */
  public List<WhaAccessNodeDTO> expandRoleUsers(
    Id roleId,
    String pageExpandType,
    Id cursorOwnerId,
    Id afterId
  ) {
    List<User> page = userSelector.selectActiveByRolePage(roleId, afterId);
    Id lastRowId = WhaExpandCursor.trimToPage(page);
    List<WhaAccessNodeDTO> nodes = WhaNodeFactory.userNodesSortedByName(page);
    if (lastRowId != null) {
      nodes.add(WhaNodeFactory.more(pageExpandType, cursorOwnerId, lastRowId));
    }
    if (nodes.isEmpty() && afterId == null) {
      nodes.add(WhaNodeFactory.info('No active users in this role'));
    }
    return nodes;
  }

  /**
   * Child roles (one level, first page only) followed by the role's own users.
   * @param roleId Role Id
   * @param internalOnly True to skip portal roles
   * @param afterId Last user of the previous page, or null
   * @return Role and user nodes
   */
  public List<WhaAccessNodeDTO> expandRoleAndSubordinates(
    Id roleId,
    Boolean internalOnly,
    Id afterId
  ) {
    String pageExpandType = internalOnly
      ? WhaConstants.EXPAND_ROLE_SUB_INTERNAL
      : WhaConstants.EXPAND_ROLE_SUB;
    List<WhaAccessNodeDTO> nodes = afterId == null
      ? buildChildRoleNodes(roleId, internalOnly, pageExpandType)
      : new List<WhaAccessNodeDTO>();
    Boolean hasChildRoles = !nodes.isEmpty();
    for (
      WhaAccessNodeDTO userNode : expandRoleUsers(
        roleId,
        pageExpandType,
        roleId,
        afterId
      )
    ) {
      // "No active users" is noise when the role has subordinates
      if (!(hasChildRoles && userNode.type == WhaConstants.NODE_INFO)) {
        nodes.add(userNode);
      }
    }
    if (nodes.isEmpty()) {
      nodes.add(WhaNodeFactory.info('No users or subordinate roles'));
    }
    return nodes;
  }

  private void addAncestorNodes(
    WhaAccessNodeDTO branch,
    List<UserRole> ancestors
  ) {
    Map<Id, Integer> userCountsByRole = userSelector.countActiveByRole(
      new Map<Id, UserRole>(ancestors).keySet()
    );
    Integer level = 1;
    for (UserRole role : ancestors) {
      branch.add(
        new WhaAccessNodeDTO(WhaConstants.NODE_ROLE, role.Id, role.Name)
          .withSubtitle(level + ' level(s) above owner')
          .withAccessLevel('Same as owner')
          .withCount(userCountsByRole.get(role.Id) ?? 0)
          .lazyOn(WhaConstants.EXPAND_ROLE, role.Id)
      );
      level++;
    }
    UserRole topRole = ancestors[ancestors.size() - 1];
    if (
      ancestors.size() >= WhaConstants.MAX_ROLE_DEPTH &&
      topRole.ParentRoleId != null
    ) {
      branch.add(
        WhaNodeFactory.info(
          'Hierarchy deeper than ' +
            WhaConstants.MAX_ROLE_DEPTH +
            ' levels — not shown'
        )
      );
    }
  }

  private List<WhaAccessNodeDTO> buildChildRoleNodes(
    Id roleId,
    Boolean internalOnly,
    String pageExpandType
  ) {
    List<WhaAccessNodeDTO> nodes = new List<WhaAccessNodeDTO>();
    Integer totalChildRoles = roleSelector.countChildren(roleId);
    if (totalChildRoles > WhaConstants.MAX_CHILDREN) {
      nodes.add(
        WhaNodeFactory.info(
          'Showing ' +
            WhaConstants.MAX_CHILDREN +
            ' of ' +
            totalChildRoles +
            ' subordinate roles'
        )
      );
    }
    List<UserRole> childRoles = new List<UserRole>();
    for (
      UserRole role : roleSelector.selectChildren(
        roleId,
        WhaConstants.MAX_CHILDREN
      )
    ) {
      if (!internalOnly || isInternalRole(role)) {
        childRoles.add(role);
      }
    }
    Map<Id, Integer> userCountsByRole = userSelector.countActiveByRole(
      new Map<Id, UserRole>(childRoles).keySet()
    );
    for (UserRole role : childRoles) {
      nodes.add(
        new WhaAccessNodeDTO(WhaConstants.NODE_ROLE, role.Id, role.Name)
          .withSubtitle('Subordinate role')
          .withCount(userCountsByRole.get(role.Id) ?? 0)
          .lazyOn(pageExpandType, role.Id)
      );
    }
    return nodes;
  }

  private static Boolean isInternalRole(UserRole role) {
    return role.PortalType == null || role.PortalType == 'None';
  }
}
