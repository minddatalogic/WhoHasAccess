@IsTest
private class WhaManagerServiceTest {
  @TestSetup
  static void setup() {
    WhaTestDataFactory.createAccessScenario();
  }

  @IsTest
  static void shouldListUserThenManager_WhenChainExpanded() {
    User viewer = WhaTestDataFactory.getUser(WhaTestDataFactory.VIEWER_ALIAS);

    Test.startTest();
    List<WhaAccessNodeDTO> nodes = new WhaManagerService()
      .expandManagerChain(viewer.Id);
    Test.stopTest();

    Assert.areEqual(2, nodes.size(), 'Viewer plus manager');
    Assert.areEqual(String.valueOf(viewer.Id), nodes[0].id, 'Group user first');
    Assert.isTrue(nodes[0].subtitle.startsWith('Group user'), 'Group user label');
    Assert.areEqual(String.valueOf(viewer.ManagerId), nodes[1].id, 'Manager next');
    Assert.isTrue(nodes[1].subtitle.startsWith('Manager'), 'Manager label');
  }

  @IsTest
  static void shouldListDrillableReports_WhenReportsExpanded() {
    User manager = WhaTestDataFactory.getUser(WhaTestDataFactory.MANAGER_ALIAS);

    Test.startTest();
    List<WhaAccessNodeDTO> nodes = new WhaManagerService()
      .expandReports(manager.Id, false, null);
    Test.stopTest();

    Assert.areEqual(2, nodes.size(), 'Viewer and member report to the manager');
    Assert.areEqual(WhaConstants.EXPAND_MANAGER_SUB, nodes[0].expandType, 'Drillable');
    Assert.isTrue(nodes[0].subtitle.startsWith('Direct report'), 'Report label');
  }

  @IsTest
  static void shouldIncludeGroupUser_WhenIncludeSelf() {
    User manager = WhaTestDataFactory.getUser(WhaTestDataFactory.MANAGER_ALIAS);

    Test.startTest();
    List<WhaAccessNodeDTO> nodes = new WhaManagerService()
      .expandReports(manager.Id, true, null);
    Test.stopTest();

    Assert.areEqual(3, nodes.size(), 'Manager plus two reports');
    Assert.areEqual(String.valueOf(manager.Id), nodes[0].id, 'Manager first');
  }

  @IsTest
  static void shouldSayNoReports_WhenUserHasNone() {
    User viewer = WhaTestDataFactory.getUser(WhaTestDataFactory.VIEWER_ALIAS);

    Test.startTest();
    List<WhaAccessNodeDTO> nodes = new WhaManagerService()
      .expandReports(viewer.Id, false, null);
    Test.stopTest();

    Assert.areEqual('No direct reports', nodes[0].name, 'No reports explained');
  }
}
