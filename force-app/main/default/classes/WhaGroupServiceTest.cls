@IsTest
private class WhaGroupServiceTest {
  @TestSetup
  static void setup() {
    WhaTestDataFactory.createAccessScenario();
  }

  @IsTest
  static void shouldListMember_WhenRegularGroupExpanded() {
    Group testGroup = WhaTestDataFactory.getGroup(WhaTestDataFactory.GROUP_NAME);
    User member = WhaTestDataFactory.getUser(WhaTestDataFactory.MEMBER_ALIAS);

    Test.startTest();
    List<WhaAccessNodeDTO> nodes = new WhaGroupService()
      .expandGroup(testGroup.Id, null);
    Test.stopTest();

    Assert.isTrue(
      WhaTestDataFactory.containsId(nodes, member.Id),
      'Member resolved: ' + JSON.serialize(nodes)
    );
  }

  @IsTest
  static void shouldNoteHierarchyAccess_WhenGroupIncludesBosses() {
    Group testGroup = WhaTestDataFactory.getGroup(WhaTestDataFactory.GROUP_NAME);

    Test.startTest();
    List<WhaAccessNodeDTO> nodes = new WhaGroupService()
      .expandGroup(testGroup.Id, null);
    Test.stopTest();

    Assert.isTrue(
      nodes[0].name.startsWith('Grant Access Using Hierarchies is ON'),
      'Bosses note comes first'
    );
  }

  @IsTest
  static void shouldSayNoMembers_WhenQueueEmpty() {
    Group queue;
    System.runAs(new User(Id = UserInfo.getUserId())) {
      queue = WhaTestDataFactory.createGroups('WHA Queue', 'Queue', 1, false)[0];
    }

    Test.startTest();
    List<WhaAccessNodeDTO> nodes = new WhaGroupService()
      .expandGroup(queue.Id, null);
    Test.stopTest();

    Assert.areEqual(1, nodes.size(), 'Only the note');
    Assert.areEqual('No members', nodes[0].name, 'Empty queue explained');
  }

  @IsTest
  static void shouldPageMembers_WhenGroupExceedsPage() {
    Integer memberCount = WhaConstants.MAX_CHILDREN + 5;
    Group bigGroup;
    System.runAs(new User(Id = UserInfo.getUserId())) {
      bigGroup = WhaTestDataFactory.createGroups('WHA Big', 'Regular', 1, false)[0];
      List<Id> nestedIds = new List<Id>();
      for (Group nested : WhaTestDataFactory.createGroups('WHA Kid', 'Regular', memberCount, false)) {
        nestedIds.add(nested.Id);
      }
      WhaTestDataFactory.addMembers(bigGroup.Id, nestedIds);
    }

    Test.startTest();
    WhaGroupService groupService = new WhaGroupService();
    List<WhaAccessNodeDTO> page1 = groupService.expandGroup(bigGroup.Id, null);
    WhaAccessNodeDTO more = page1[page1.size() - 1];
    List<WhaAccessNodeDTO> page2 = groupService.expandGroup(
      bigGroup.Id,
      new WhaExpandCursor(more.expandId).afterId
    );
    Test.stopTest();

    Assert.areEqual(WhaConstants.MAX_CHILDREN + 1, page1.size(), 'Page + MORE');
    Assert.areEqual(WhaConstants.NODE_MORE, more.type, 'Last node loads more');
    Assert.areEqual(5, page2.size(), 'Remaining members on page 2');
  }

  @IsTest
  static void shouldListRoleUsers_WhenRoleGroupExpanded() {
    UserRole topRole = WhaTestDataFactory.getRole(WhaTestDataFactory.TOP_ROLE);
    Group roleGroup = WhaTestDataFactory.getRoleGroup('Role', topRole.Id);
    User manager = WhaTestDataFactory.getUser(WhaTestDataFactory.MANAGER_ALIAS);

    Test.startTest();
    List<WhaAccessNodeDTO> nodes = new WhaGroupService()
      .expandGroup(roleGroup.Id, null);
    Test.stopTest();

    Assert.isTrue(WhaTestDataFactory.containsId(nodes, manager.Id), 'Manager listed');
  }

  @IsTest
  static void shouldListChildRole_WhenRoleAndSubordinatesExpanded() {
    UserRole topRole = WhaTestDataFactory.getRole(WhaTestDataFactory.TOP_ROLE);
    UserRole childRole = WhaTestDataFactory.getRole(WhaTestDataFactory.CHILD_ROLE);
    Group roleGroup = WhaTestDataFactory.getRoleGroup('RoleAndSubordinates', topRole.Id);

    Test.startTest();
    List<WhaAccessNodeDTO> nodes = new WhaGroupService()
      .expandGroup(roleGroup.Id, null);
    Test.stopTest();

    Assert.isTrue(WhaTestDataFactory.containsId(nodes, childRole.Id), 'Child role listed');
  }

  @IsTest
  static void shouldCountUsers_WhenOrganizationGroupExpanded() {
    Group orgGroup = [SELECT Id FROM Group WHERE Type = 'Organization' LIMIT 1];
    Integer activeInternal = [
      SELECT COUNT()
      FROM User
      WHERE IsActive = TRUE AND UserType = 'Standard'
    ];

    Test.startTest();
    List<WhaAccessNodeDTO> nodes = new WhaGroupService()
      .expandGroup(orgGroup.Id, null);
    Test.stopTest();

    Assert.areEqual(WhaConstants.NODE_INFO, nodes[0].type, 'Implicit membership');
    Assert.areEqual(activeInternal, nodes[0].count, 'Active internal users counted');
  }

  @IsTest
  static void shouldLabelGroupNodes_WhenBuiltForShareRows() {
    Group testGroup = WhaTestDataFactory.getGroup(WhaTestDataFactory.GROUP_NAME);
    UserRole topRole = WhaTestDataFactory.getRole(WhaTestDataFactory.TOP_ROLE);
    Group roleGroup = WhaTestDataFactory.getRoleGroup('Role', topRole.Id);

    Test.startTest();
    Map<Id, WhaAccessNodeDTO> nodes = new WhaGroupService()
      .buildGroupNodes(new Set<Id>{ testGroup.Id, roleGroup.Id });
    Test.stopTest();

    Assert.areEqual('Public Group: WHA Test Group', nodes.get(testGroup.Id).name, 'Group label');
    Assert.areEqual('Role: ' + WhaTestDataFactory.TOP_ROLE_NAME, nodes.get(roleGroup.Id).name, 'Role label');
    Assert.areEqual(WhaConstants.NODE_ROLE, nodes.get(roleGroup.Id).type, 'Role groups are ROLE nodes');
  }

  @IsTest
  static void shouldUsePlaceholder_WhenGroupMissing() {
    Id missingId = WhaTestDataFactory.fakeId(Group.SObjectType, 1);

    Test.startTest();
    Map<Id, WhaAccessNodeDTO> nodes = new WhaGroupService()
      .buildGroupNodes(new Set<Id>{ missingId });
    Test.stopTest();

    Assert.areEqual(String.valueOf(missingId), nodes.get(missingId).name, 'Placeholder named by Id');
  }

  @IsTest
  static void shouldAnswer_WhenChatterGroupHasNoMembers() {
    Id missingId = WhaTestDataFactory.fakeId(CollaborationGroup.SObjectType, 1);

    Test.startTest();
    List<WhaAccessNodeDTO> nodes = new WhaGroupService()
      .expandChatterMembers(missingId, null);
    Test.stopTest();

    Assert.areEqual(1, nodes.size(), 'One note');
    Assert.areEqual(WhaConstants.NODE_INFO, nodes[0].type, 'Explained, not an error');
  }
}
