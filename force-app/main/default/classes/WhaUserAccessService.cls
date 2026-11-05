/**
 * Effective access of one user on the analysed record: what Salesforce
 * enforces (UserRecordAccess) next to their object and system permissions.
 */
public with sharing class WhaUserAccessService {
  private final WhaAccessContext context;
  private final WhaUserSelector userSelector = new WhaUserSelector();
  private final WhaRecordAccessSelector recordAccessSelector = new WhaRecordAccessSelector();
  private final WhaPermissionSelector permissionSelector = new WhaPermissionSelector();

  /**
   * @param context Analysed record
   */
  public WhaUserAccessService(WhaAccessContext context) {
    this.context = context;
  }

  /**
   * @param userId User to check
   * @return Record, object and system access of the user
   * @throws WhaException when userId is null or the user does not exist
   */
  public WhaUserAccessDTO getUserAccess(Id userId) {
    if (userId == null) {
      throw new WhaException('A user Id is required.');
    }
    User userRecord = userSelector.selectWithHierarchyById(userId);
    WhaUserAccessDTO access = new WhaUserAccessDTO();
    access.userId = userRecord.Id;
    access.userName = userRecord.Name;
    access.isActive = userRecord.IsActive;
    access.profileName = userRecord.Profile?.Name;
    access.roleName = userRecord.UserRole?.Name;

    applyRecordAccess(
      access,
      recordAccessSelector.selectForUser(userId, context.recordId)
    );
    applyObjectPermissions(
      access,
      permissionSelector.selectUserObjectPermissions(userId, context.objectName)
    );
    applySystemPermissions(
      access,
      permissionSelector.selectUserPermissionSets(userId)
    );
    return access;
  }

  private static void applyRecordAccess(
    WhaUserAccessDTO access,
    UserRecordAccess recordAccess
  ) {
    if (recordAccess != null) {
      access.recordRead = recordAccess.HasReadAccess;
      access.recordEdit = recordAccess.HasEditAccess;
      access.recordDelete = recordAccess.HasDeleteAccess;
      access.recordTransfer = recordAccess.HasTransferAccess;
      access.recordAll = recordAccess.HasAllAccess;
    }
    access.maxAccess = maxAccessLabel(access);
  }

  /** A user can hold the object permission through any assigned set. */
  private static void applyObjectPermissions(
    WhaUserAccessDTO access,
    List<ObjectPermissions> permissions
  ) {
    for (ObjectPermissions permission : permissions) {
      access.objRead |= permission.PermissionsRead;
      access.objCreate |= permission.PermissionsCreate;
      access.objEdit |= permission.PermissionsEdit;
      access.objDelete |= permission.PermissionsDelete;
      access.objViewAll |= permission.PermissionsViewAllRecords;
      access.objModifyAll |= permission.PermissionsModifyAllRecords;
    }
  }

  private static void applySystemPermissions(
    WhaUserAccessDTO access,
    List<PermissionSet> permissionSets
  ) {
    for (PermissionSet permissionSet : permissionSets) {
      access.viewAllData |= permissionSet.PermissionsViewAllData;
      access.modifyAllData |= permissionSet.PermissionsModifyAllData;
    }
  }

  private static String maxAccessLabel(WhaUserAccessDTO access) {
    if (access.recordAll) {
      return 'Full Access';
    }
    if (access.recordDelete) {
      return 'Delete';
    }
    if (access.recordEdit) {
      return 'Read/Write';
    }
    return access.recordRead ? 'Read Only' : 'None';
  }
}
