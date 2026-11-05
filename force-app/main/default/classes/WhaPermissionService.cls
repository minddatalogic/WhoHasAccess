/**
 * Access that comes from profiles, permission sets and permission set groups:
 * object Read under a public org-wide default, View All / Modify All on the
 * object, and View / Modify All Data. Also lists the users assigned to each.
 */
public with sharing class WhaPermissionService {
  private static final List<String> CONTAINER_KINDS = new List<String>{
    WhaConstants.NODE_PROFILE,
    WhaConstants.NODE_PERMSET,
    WhaConstants.NODE_PSG
  };
  private static final Map<String, String> BUCKET_LABELS = new Map<String, String>{
    WhaConstants.NODE_PROFILE => 'Profiles',
    WhaConstants.NODE_PERMSET => 'Permission Sets',
    WhaConstants.NODE_PSG => 'Permission Set Groups'
  };

  private final WhaAccessContext context;
  private final WhaPermissionSelector permissionSelector = new WhaPermissionSelector();

  /**
   * @param context Analysed record
   */
  public WhaPermissionService(WhaAccessContext context) {
    this.context = context;
  }

  /**
   * @return The "Object Permission Bypass" branch (View All, Modify All,
   *         View All Data, Modify All Data)
   */
  public WhaAccessNodeDTO buildBypassBranch() {
    WhaAccessNodeDTO branch = WhaNodeFactory.category(
        'Object Permission Bypass'
      )
      .withSubtitle(
        'View All / Modify All on ' +
          context.objectLabel +
          ', or View / Modify All Data — ignores sharing'
      );
    Map<Id, WhaPermissionContainerDTO> containersById = new Map<Id, WhaPermissionContainerDTO>();
    for (
      ObjectPermissions permission : permissionSelector.selectViewAllOrModifyAll(
        context.objectName
      )
    ) {
      String grant =
        (permission.PermissionsModifyAllRecords ? 'Modify All (' : 'View All (') +
        context.objectLabel +
        ')';
      containersById.put(
        permission.ParentId,
        WhaPermissionContainerDTO.fromPermissionSet(permission.Parent, grant)
      );
    }
    for (
      PermissionSet permissionSet : permissionSelector.selectViewAllOrModifyAllData()
    ) {
      String grant = permissionSet.PermissionsModifyAllData
        ? 'Modify All Data'
        : 'View All Data';
      // system permission wins over the object-level one
      containersById.put(
        permissionSet.Id,
        WhaPermissionContainerDTO.fromPermissionSet(permissionSet, grant)
      );
    }
    addContainerNodes(branch, containersById.values());
    return branch;
  }

  /**
   * Under Public Read/Write, Edit on the object means Read/Write; otherwise Read Only.
   * @param publicWrite True when the org-wide default is Public Read/Write
   * @return One container per profile / permission set with object Read
   */
  public List<WhaPermissionContainerDTO> buildObjectReadContainers(
    Boolean publicWrite
  ) {
    List<WhaPermissionContainerDTO> containers = new List<WhaPermissionContainerDTO>();
    for (
      ObjectPermissions permission : permissionSelector.selectObjectRead(
        context.objectName
      )
    ) {
      String grant = publicWrite && permission.PermissionsEdit
        ? 'Read/Write'
        : 'Read Only';
      containers.add(
        WhaPermissionContainerDTO.fromPermissionSet(permission.Parent, grant)
      );
    }
    return containers;
  }

  /**
   * Adds the containers under Profiles / Permission Sets / Permission Set
   * Groups buckets. Containers with no active assignees (e.g. system
   * session-based permission sets) are left out: they give nobody access.
   * @param parent Branch to add the buckets to
   * @param containers Containers to show
   */
  public void addContainerNodes(
    WhaAccessNodeDTO parent,
    List<WhaPermissionContainerDTO> containers
  ) {
    Set<Id> permissionSetIds = new Set<Id>();
    Set<Id> permissionSetGroupIds = new Set<Id>();
    for (WhaPermissionContainerDTO container : containers) {
      permissionSetIds.add(container.permissionSetId);
      if (container.permissionSetGroupId != null) {
        permissionSetGroupIds.add(container.permissionSetGroupId);
      }
    }
    Map<Id, Integer> assigneeCounts = permissionSelector.countActiveAssignments(
      permissionSetIds
    );
    Map<Id, String> groupLabels = permissionSelector.selectGroupLabels(
      permissionSetGroupIds
    );

    Map<String, WhaAccessNodeDTO> bucketsByKind = new Map<String, WhaAccessNodeDTO>();
    for (String kind : CONTAINER_KINDS) {
      bucketsByKind.put(kind, WhaNodeFactory.category(BUCKET_LABELS.get(kind)));
    }
    Integer hiddenCount = 0;
    for (WhaPermissionContainerDTO container : containers) {
      Integer assigned = assigneeCounts.get(container.permissionSetId) ?? 0;
      if (assigned == 0) {
        hiddenCount++;
        continue;
      }
      bucketsByKind.get(container.kind)
        .add(buildContainerNode(container, assigned, groupLabels));
    }
    for (String kind : CONTAINER_KINDS) {
      WhaAccessNodeDTO bucket = bucketsByKind.get(kind);
      if (bucket.hasChildren()) {
        parent.add(bucket.withCount(bucket.children.size()));
      }
    }
    if (!parent.hasChildren()) {
      parent.add(WhaNodeFactory.info('No users get access this way'));
    }
    if (hiddenCount > 0) {
      parent.appendSubtitle(
        hiddenCount +
        ' profile(s) / permission set(s) with no active users hidden'
      );
    }
  }

  /**
   * Active users assigned to a profile / permission set (or to its group).
   * @param expandId "psId" or "psId|psgId" (WhaPermissionContainerDTO.toExpandId)
   * @param afterId Last assignment of the previous page, or null
   * @return User nodes sorted by name, plus a MORE node when there are more
   */
  public List<WhaAccessNodeDTO> expandAssignedUsers(
    String expandId,
    Id afterId
  ) {
    List<Id> ids = WhaPermissionContainerDTO.parseExpandId(expandId);
    List<PermissionSetAssignment> page = permissionSelector.selectActiveAssignmentPage(
      ids[0],
      ids[1],
      afterId
    );
    Id lastRowId = WhaExpandCursor.trimToPage(page);
    List<User> assignees = new List<User>();
    Set<Id> seenUserIds = new Set<Id>();
    for (PermissionSetAssignment assignment : page) {
      if (seenUserIds.add(assignment.AssigneeId)) {
        assignees.add(assignment.Assignee);
      }
    }
    List<WhaAccessNodeDTO> nodes = WhaNodeFactory.userNodesSortedByName(
      assignees
    );
    if (lastRowId != null) {
      nodes.add(
        WhaNodeFactory.more(WhaConstants.EXPAND_PERMSET, expandId, lastRowId)
      );
    }
    if (nodes.isEmpty() && afterId == null) {
      nodes.add(WhaNodeFactory.info('No active users assigned'));
    }
    return nodes;
  }

  private static WhaAccessNodeDTO buildContainerNode(
    WhaPermissionContainerDTO container,
    Integer assigned,
    Map<Id, String> groupLabels
  ) {
    String label = container.label;
    if (
      container.kind == WhaConstants.NODE_PSG &&
      groupLabels.containsKey(container.permissionSetGroupId)
    ) {
      label = groupLabels.get(container.permissionSetGroupId);
    }
    return new WhaAccessNodeDTO(
        container.kind,
        container.permissionSetId,
        label
      )
      .withAccessLevel(container.grantedAccess)
      .withCount(assigned)
      .lazyOn(WhaConstants.EXPAND_PERMSET, container.toExpandId());
  }
}
