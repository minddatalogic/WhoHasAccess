@IsTest
private class WhaPermissionServiceTest {
  @TestSetup
  static void setup() {
    WhaTestDataFactory.createAccessScenario();
  }

  @IsTest
  static void shouldListModifyAllDataProfile_WhenBypassBranchBuilt() {
    Account account = WhaTestDataFactory.getAccount();
    Id adminProfileId = [
        SELECT PermissionSetId
        FROM PermissionSetAssignment
        WHERE
          Assignee.IsActive = TRUE
          AND PermissionSet.IsOwnedByProfile = TRUE
          AND PermissionSet.PermissionsModifyAllData = TRUE
        LIMIT 1
      ]
      .PermissionSetId;

    Test.startTest();
    WhaAccessNodeDTO branch = service(account.Id).buildBypassBranch();
    Test.stopTest();

    WhaAccessNodeDTO profiles = WhaTestDataFactory.findChild(branch, 'Profiles');
    Assert.isNotNull(profiles, 'Profiles bucket: ' + JSON.serialize(branch));
    WhaAccessNodeDTO adminNode = findById(profiles.children, adminProfileId);
    Assert.areEqual('Modify All Data', adminNode.accessLevel, 'System permission shown');
    Assert.areEqual(WhaConstants.EXPAND_PERMSET, adminNode.expandType, 'Users load lazily');
  }

  @IsTest
  static void shouldGrantReadOnly_WhenOrgDefaultIsNotPublicWrite() {
    Account account = WhaTestDataFactory.getAccount();

    Test.startTest();
    List<WhaPermissionContainerDTO> containers = service(account.Id)
      .buildObjectReadContainers(false);
    Test.stopTest();

    Assert.isFalse(containers.isEmpty(), 'Some profile can read Account');
    for (WhaPermissionContainerDTO container : containers) {
      Assert.areEqual('Read Only', container.grantedAccess, 'Read Only for all');
    }
  }

  @IsTest
  static void shouldHideContainer_WhenNobodyAssigned() {
    Account account = WhaTestDataFactory.getAccount();
    PermissionSet unused = new PermissionSet(Name = 'WHA_Unused', Label = 'WHA Unused');
    insert unused;
    WhaPermissionContainerDTO container = new WhaPermissionContainerDTO();
    container.permissionSetId = unused.Id;
    container.kind = WhaConstants.NODE_PERMSET;
    WhaAccessNodeDTO parent = WhaNodeFactory.category('Test');

    Test.startTest();
    service(account.Id)
      .addContainerNodes(parent, new List<WhaPermissionContainerDTO>{ container });
    Test.stopTest();

    Assert.areEqual('No users get access this way', parent.children[0].name, 'Nothing shown');
    Assert.areEqual(
      '1 profile(s) / permission set(s) with no active users hidden',
      parent.subtitle,
      'Hidden count explained'
    );
  }

  @IsTest
  static void shouldListAssignee_WhenPermissionSetExpanded() {
    Account account = WhaTestDataFactory.getAccount();
    User viewer = WhaTestDataFactory.getUser(WhaTestDataFactory.VIEWER_ALIAS);
    PermissionSet viewerSet = WhaTestDataFactory.getPermissionSet(
      WhaTestDataFactory.VIEWER_PERMISSION_SET
    );

    Test.startTest();
    List<WhaAccessNodeDTO> nodes = service(account.Id)
      .expandAssignedUsers(viewerSet.Id, null);
    Test.stopTest();

    Assert.isTrue(WhaTestDataFactory.containsId(nodes, viewer.Id), 'Viewer assigned');
  }

  @IsTest
  static void shouldSayNoUsers_WhenPermissionSetUnassigned() {
    Account account = WhaTestDataFactory.getAccount();
    PermissionSet unused = new PermissionSet(Name = 'WHA_Unused', Label = 'WHA Unused');
    insert unused;

    Test.startTest();
    List<WhaAccessNodeDTO> nodes = service(account.Id)
      .expandAssignedUsers(unused.Id, null);
    Test.stopTest();

    Assert.areEqual('No active users assigned', nodes[0].name, 'Empty set explained');
  }

  private static WhaPermissionService service(Id recordId) {
    return new WhaPermissionService(new WhaAccessContext(recordId));
  }

  private static WhaAccessNodeDTO findById(List<WhaAccessNodeDTO> nodes, Id nodeId) {
    for (WhaAccessNodeDTO node : nodes) {
      if (node.id == String.valueOf(nodeId)) {
        return node;
      }
    }
    Assert.fail('No node with Id ' + nodeId);
    return null;
  }
}
