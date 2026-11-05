@IsTest
private class WhaRoleServiceTest {
  @TestSetup
  static void setup() {
    WhaTestDataFactory.createAccessScenario();
  }

  @IsTest
  static void shouldListParentRole_WhenOwnerHasRole() {
    User viewer = WhaTestDataFactory.getUser(WhaTestDataFactory.VIEWER_ALIAS);
    UserRole topRole = WhaTestDataFactory.getRole(WhaTestDataFactory.TOP_ROLE);

    Test.startTest();
    WhaAccessNodeDTO branch = new WhaRoleService()
      .buildHierarchyAboveOwner(viewer.Id);
    Test.stopTest();

    Assert.areEqual(1, branch.children.size(), 'One role above the owner');
    WhaAccessNodeDTO parentRole = branch.children[0];
    Assert.areEqual(String.valueOf(topRole.Id), parentRole.id, 'Top role listed');
    Assert.areEqual('Same as owner', parentRole.accessLevel, 'Inherits owner access');
    Assert.areEqual(1, parentRole.count, 'The manager is in the top role');
    Assert.areEqual(WhaConstants.EXPAND_ROLE, parentRole.expandType, 'Lazy role');
  }

  @IsTest
  static void shouldSayTopOfHierarchy_WhenOwnerRoleHasNoParent() {
    User manager = WhaTestDataFactory.getUser(WhaTestDataFactory.MANAGER_ALIAS);

    Test.startTest();
    WhaAccessNodeDTO branch = new WhaRoleService()
      .buildHierarchyAboveOwner(manager.Id);
    Test.stopTest();

    Assert.areEqual(
      'Owner is at the top of the hierarchy',
      branch.children[0].name,
      'Top role explained'
    );
  }

  @IsTest
  static void shouldSayNotApplicable_WhenOwnerIsQueue() {
    Group testGroup = WhaTestDataFactory.getGroup(WhaTestDataFactory.GROUP_NAME);

    Test.startTest();
    WhaAccessNodeDTO branch = new WhaRoleService()
      .buildHierarchyAboveOwner(testGroup.Id);
    Test.stopTest();

    Assert.areEqual('Not applicable', branch.children[0].name, 'Queues have no role');
  }

  @IsTest
  static void shouldSayNoManagers_WhenOwnerHasNoRole() {
    User member = WhaTestDataFactory.getUser(WhaTestDataFactory.MEMBER_ALIAS);
    System.runAs(new User(Id = UserInfo.getUserId())) {
      update new User(Id = member.Id, UserRoleId = null);
    }

    Test.startTest();
    WhaAccessNodeDTO branch = new WhaRoleService()
      .buildHierarchyAboveOwner(member.Id);
    Test.stopTest();

    Assert.areEqual('No managers inherit access', branch.children[0].name, 'No role explained');
  }

  @IsTest
  static void shouldListUsers_WhenRoleExpanded() {
    UserRole childRole = WhaTestDataFactory.getRole(WhaTestDataFactory.CHILD_ROLE);

    Test.startTest();
    List<WhaAccessNodeDTO> nodes = new WhaRoleService()
      .expandRoleUsers(childRole.Id, WhaConstants.EXPAND_ROLE, childRole.Id, null);
    Test.stopTest();

    Assert.areEqual(WhaTestDataFactory.USERS_IN_CHILD_ROLE, nodes.size(), 'Viewer and member');
  }

  @IsTest
  static void shouldSayNoUsers_WhenRoleEmpty() {
    UserRole emptyRole;
    System.runAs(new User(Id = UserInfo.getUserId())) {
      emptyRole = WhaTestDataFactory.createRole('WHA Empty', 'WHA_Empty', null);
    }

    Test.startTest();
    List<WhaAccessNodeDTO> nodes = new WhaRoleService()
      .expandRoleUsers(emptyRole.Id, WhaConstants.EXPAND_ROLE, emptyRole.Id, null);
    Test.stopTest();

    Assert.areEqual('No active users in this role', nodes[0].name, 'Empty role explained');
  }

  @IsTest
  static void shouldListChildRoleWithCount_WhenSubordinatesExpanded() {
    UserRole topRole = WhaTestDataFactory.getRole(WhaTestDataFactory.TOP_ROLE);
    UserRole childRole = WhaTestDataFactory.getRole(WhaTestDataFactory.CHILD_ROLE);

    Test.startTest();
    List<WhaAccessNodeDTO> nodes = new WhaRoleService()
      .expandRoleAndSubordinates(topRole.Id, false, null);
    Test.stopTest();

    WhaAccessNodeDTO childNode = nodes[0];
    Assert.areEqual(String.valueOf(childRole.Id), childNode.id, 'Child role first');
    Assert.areEqual(WhaTestDataFactory.USERS_IN_CHILD_ROLE, childNode.count, 'Users counted');
    Assert.areEqual(WhaConstants.EXPAND_ROLE_SUB, childNode.expandType, 'Drills down');
  }

  @IsTest
  static void shouldKeepInternalChildRole_WhenInternalOnly() {
    UserRole topRole = WhaTestDataFactory.getRole(WhaTestDataFactory.TOP_ROLE);
    UserRole childRole = WhaTestDataFactory.getRole(WhaTestDataFactory.CHILD_ROLE);

    Test.startTest();
    List<WhaAccessNodeDTO> nodes = new WhaRoleService()
      .expandRoleAndSubordinates(topRole.Id, true, null);
    Test.stopTest();

    Assert.isTrue(WhaTestDataFactory.containsId(nodes, childRole.Id), 'Internal role kept');
    Assert.areEqual(
      WhaConstants.EXPAND_ROLE_SUB_INTERNAL,
      nodes[0].expandType,
      'Internal-only expand type carried down'
    );
  }

  @IsTest
  static void shouldSayNothingBelow_WhenLeafRoleHasNoUsers() {
    UserRole emptyRole;
    System.runAs(new User(Id = UserInfo.getUserId())) {
      emptyRole = WhaTestDataFactory.createRole('WHA Leaf', 'WHA_Leaf', null);
    }

    Test.startTest();
    List<WhaAccessNodeDTO> nodes = new WhaRoleService()
      .expandRoleAndSubordinates(emptyRole.Id, false, null);
    Test.stopTest();

    Assert.areEqual(1, nodes.size(), 'Only the note');
    Assert.areEqual(
      'No active users in this role',
      nodes[0].name,
      'Empty leaf role explained'
    );
  }
}
