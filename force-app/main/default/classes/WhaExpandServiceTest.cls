/**
 * Routing tests: each expand type reaches the service that owns it.
 * The services' own behaviour is covered by their test classes.
 */
@IsTest
private class WhaExpandServiceTest {
  @TestSetup
  static void setup() {
    WhaTestDataFactory.createAccessScenario();
  }

  @IsTest
  static void shouldThrow_WhenExpandTypeUnknown() {
    try {
      expand('NOPE', UserInfo.getUserId());
      Assert.fail('Expected WhaException');
    } catch (WhaException e) {
      Assert.areEqual('Unknown expand type: NOPE', e.getMessage(), 'Message');
    }
  }

  @IsTest
  static void shouldThrow_WhenExpandIdBlank() {
    try {
      expand(WhaConstants.EXPAND_GROUP, '');
      Assert.fail('Expected WhaException');
    } catch (WhaException e) {
      Assert.areEqual('An expand Id is required.', e.getMessage(), 'Message');
    }
  }

  @IsTest
  static void shouldRouteShareRows_WhenTypeIsShareRows() {
    List<WhaAccessNodeDTO> nodes = expand(WhaConstants.EXPAND_SHARE_ROWS, 'Owner');
    String expected = WhaTestDataFactory.accountHasOwnerShare(
        WhaTestDataFactory.getAccount().Id
      )
      ? WhaConstants.NODE_USER
      : WhaConstants.NODE_INFO; // Public Read/Write orgs may have no owner row
    Assert.areEqual(expected, nodes[0].type, 'Owner share row');
  }

  @IsTest
  static void shouldRoutePermissionSet_WhenTypeIsPermset() {
    PermissionSet viewerSet = WhaTestDataFactory.getPermissionSet(
      WhaTestDataFactory.VIEWER_PERMISSION_SET
    );
    User viewer = WhaTestDataFactory.getUser(WhaTestDataFactory.VIEWER_ALIAS);
    List<WhaAccessNodeDTO> nodes = expand(WhaConstants.EXPAND_PERMSET, viewerSet.Id);
    Assert.isTrue(WhaTestDataFactory.containsId(nodes, viewer.Id), 'Assignee');
  }

  @IsTest
  static void shouldRouteGroup_WhenTypeIsGroup() {
    Group testGroup = WhaTestDataFactory.getGroup(WhaTestDataFactory.GROUP_NAME);
    User member = WhaTestDataFactory.getUser(WhaTestDataFactory.MEMBER_ALIAS);
    List<WhaAccessNodeDTO> nodes = expand(WhaConstants.EXPAND_GROUP, testGroup.Id);
    Assert.isTrue(WhaTestDataFactory.containsId(nodes, member.Id), 'Member');
  }

  @IsTest
  static void shouldRouteRole_WhenTypeIsRole() {
    UserRole topRole = WhaTestDataFactory.getRole(WhaTestDataFactory.TOP_ROLE);
    User manager = WhaTestDataFactory.getUser(WhaTestDataFactory.MANAGER_ALIAS);
    List<WhaAccessNodeDTO> nodes = expand(WhaConstants.EXPAND_ROLE, topRole.Id);
    Assert.areEqual(String.valueOf(manager.Id), nodes[0].id, 'Role user');
  }

  @IsTest
  static void shouldRouteRoleSubordinates_WhenTypeIsRoleSub() {
    UserRole topRole = WhaTestDataFactory.getRole(WhaTestDataFactory.TOP_ROLE);
    List<WhaAccessNodeDTO> nodes = expand(WhaConstants.EXPAND_ROLE_SUB, topRole.Id);
    Assert.areEqual(WhaConstants.EXPAND_ROLE_SUB, nodes[0].expandType, 'Child role');
  }

  @IsTest
  static void shouldRouteInternalSubordinates_WhenTypeIsRoleSubInternal() {
    UserRole topRole = WhaTestDataFactory.getRole(WhaTestDataFactory.TOP_ROLE);
    List<WhaAccessNodeDTO> nodes = expand(
      WhaConstants.EXPAND_ROLE_SUB_INTERNAL,
      topRole.Id
    );
    Assert.areEqual(
      WhaConstants.EXPAND_ROLE_SUB_INTERNAL,
      nodes[0].expandType,
      'Internal child role'
    );
  }

  @IsTest
  static void shouldRouteManagerChain_WhenTypeIsManagerUp() {
    User viewer = WhaTestDataFactory.getUser(WhaTestDataFactory.VIEWER_ALIAS);
    List<WhaAccessNodeDTO> nodes = expand(WhaConstants.EXPAND_MANAGER_UP, viewer.Id);
    Assert.areEqual(2, nodes.size(), 'Viewer plus manager');
  }

  @IsTest
  static void shouldRouteReports_WhenTypeIsManagerSub() {
    User manager = WhaTestDataFactory.getUser(WhaTestDataFactory.MANAGER_ALIAS);
    List<WhaAccessNodeDTO> nodes = expand(WhaConstants.EXPAND_MANAGER_SUB, manager.Id);
    Assert.areEqual(2, nodes.size(), 'Two reports');
  }

  @IsTest
  static void shouldRouteTerritory_WhenTypeIsTerritory() {
    List<WhaAccessNodeDTO> nodes = expand(
      WhaConstants.EXPAND_TERRITORY,
      UserInfo.getUserId()
    );
    Assert.areEqual(WhaConstants.NODE_INFO, nodes[0].type, 'Territory note');
  }

  @IsTest
  static void shouldRouteSubTerritories_WhenTypeIsTerritorySub() {
    List<WhaAccessNodeDTO> nodes = expand(
      WhaConstants.EXPAND_TERRITORY_SUB,
      UserInfo.getUserId()
    );
    Assert.areEqual(WhaConstants.NODE_INFO, nodes[0].type, 'Sub-territory note');
  }

  @IsTest
  static void shouldRouteChatter_WhenTypeIsChatter() {
    Id missingId = WhaTestDataFactory.fakeId(CollaborationGroup.SObjectType, 1);
    List<WhaAccessNodeDTO> nodes = expand(WhaConstants.EXPAND_CHATTER, missingId);
    Assert.areEqual(WhaConstants.NODE_INFO, nodes[0].type, 'Chatter note');
  }

  private static List<WhaAccessNodeDTO> expand(String expandType, String expandId) {
    Account account = WhaTestDataFactory.getAccount();
    Test.startTest();
    List<WhaAccessNodeDTO> nodes = new WhaExpandService(
        new WhaAccessContext(account.Id)
      )
      .expand(expandType, expandId);
    Test.stopTest();
    return nodes;
  }
}
