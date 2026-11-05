/**
 * Territory management may be off in the test org; either way the service
 * must answer with a note rather than an error.
 */
@IsTest
private class WhaTerritoryServiceTest {
  @IsTest
  static void shouldAnswerWithNote_WhenTerritoryHasNoUsers() {
    Id territoryId = UserInfo.getUserId(); // matches no territory

    Test.startTest();
    List<WhaAccessNodeDTO> nodes = new WhaTerritoryService()
      .expandTerritoryUsers(territoryId, false, null);
    Test.stopTest();

    Assert.areEqual(1, nodes.size(), 'One note');
    Assert.areEqual(WhaConstants.NODE_INFO, nodes[0].type, 'Note, not an error');
  }

  @IsTest
  static void shouldAnswerWithNote_WhenSubTerritoriesRequested() {
    Id territoryId = UserInfo.getUserId();

    Test.startTest();
    List<WhaAccessNodeDTO> nodes = new WhaTerritoryService()
      .expandTerritoryUsers(territoryId, true, null);
    Test.stopTest();

    Assert.areEqual(WhaConstants.NODE_INFO, nodes[0].type, 'Note, not an error');
  }

  @IsTest
  static void shouldReturnNoNames_WhenIdsAreNotTerritories() {
    Test.startTest();
    Map<Id, String> names = new WhaTerritoryService()
      .getTerritoryNames(new Set<Id>{ UserInfo.getUserId() });
    Test.stopTest();

    Assert.isTrue(names.isEmpty(), 'No territory names');
  }
}
