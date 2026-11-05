@IsTest
private class WhaExpandCursorTest {
  @IsTest
  static void shouldHaveNoCursor_WhenExpandIdIsPlain() {
    WhaExpandCursor cursor = new WhaExpandCursor('Manual');
    Assert.areEqual('Manual', cursor.baseId, 'Base is the whole Id');
    Assert.isTrue(cursor.isFirstPage(), 'No cursor means first page');
  }

  @IsTest
  static void shouldSplitCursor_WhenExpandIdHasCursor() {
    Id groupId = WhaTestDataFactory.fakeId(Group.SObjectType, 1);
    Id lastRowId = WhaTestDataFactory.fakeId(GroupMember.SObjectType, 2);
    WhaExpandCursor cursor = new WhaExpandCursor(
      WhaExpandCursor.encode(groupId, lastRowId)
    );
    Assert.areEqual(groupId, cursor.baseRecordId(), 'Base Id parsed');
    Assert.areEqual(lastRowId, cursor.afterId, 'After Id parsed');
    Assert.isFalse(cursor.isFirstPage(), 'Cursor means a later page');
  }

  @IsTest
  static void shouldHandleNull_WhenExpandIdIsNull() {
    WhaExpandCursor cursor = new WhaExpandCursor(null);
    Assert.isNull(cursor.baseId, 'No base');
    Assert.isNull(cursor.afterId, 'No cursor');
  }

  @IsTest
  static void shouldKeepAllRows_WhenPageNotFull() {
    List<Account> rows = fakeAccounts(WhaConstants.MAX_CHILDREN);
    Id lastRowId = WhaExpandCursor.trimToPage(rows);
    Assert.isNull(lastRowId, 'No further page');
    Assert.areEqual(WhaConstants.MAX_CHILDREN, rows.size(), 'Nothing removed');
  }

  @IsTest
  static void shouldTrimProbeRow_WhenAnotherPageExists() {
    List<Account> rows = fakeAccounts(WhaConstants.QUERY_LIMIT);
    Id expectedLastId = rows[WhaConstants.MAX_CHILDREN - 1].Id;
    Id lastRowId = WhaExpandCursor.trimToPage(rows);
    Assert.areEqual(expectedLastId, lastRowId, 'Last kept row returned');
    Assert.areEqual(WhaConstants.MAX_CHILDREN, rows.size(), 'Probe row removed');
  }

  private static List<Account> fakeAccounts(Integer count) {
    List<Account> rows = new List<Account>();
    for (Integer index = 1; index <= count; index++) {
      rows.add(
        new Account(Id = WhaTestDataFactory.fakeId(Account.SObjectType, index))
      );
    }
    return rows;
  }
}
