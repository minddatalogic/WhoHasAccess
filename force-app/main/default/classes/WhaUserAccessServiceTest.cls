@IsTest
private class WhaUserAccessServiceTest {
  @TestSetup
  static void setup() {
    WhaTestDataFactory.createAccessScenario();
  }

  @IsTest
  static void shouldReportFullAccess_WhenUserOwnsRecord() {
    Account account = WhaTestDataFactory.getAccount();
    User viewer = WhaTestDataFactory.getUser(WhaTestDataFactory.VIEWER_ALIAS);

    Test.startTest();
    WhaUserAccessDTO access = service(account.Id).getUserAccess(viewer.Id);
    Test.stopTest();

    Assert.areEqual(String.valueOf(viewer.Id), access.userId, 'User Id');
    Assert.isTrue(access.recordAll, 'Owner has full access');
    Assert.areEqual('Full Access', access.maxAccess, 'Max access label');
    Assert.isTrue(access.objRead, 'Profile grants Account Read');
    Assert.areEqual(WhaTestDataFactory.CHILD_ROLE_NAME, access.roleName, 'Role name');
  }

  @IsTest
  static void shouldThrow_WhenUserIdIsNull() {
    Account account = WhaTestDataFactory.getAccount();
    try {
      service(account.Id).getUserAccess(null);
      Assert.fail('Expected WhaException');
    } catch (WhaException e) {
      Assert.areEqual('A user Id is required.', e.getMessage(), 'Message');
    }
  }

  @IsTest
  static void shouldThrow_WhenUserDoesNotExist() {
    Account account = WhaTestDataFactory.getAccount();
    Id missingUserId = WhaTestDataFactory.fakeId(User.SObjectType, 1);
    try {
      service(account.Id).getUserAccess(missingUserId);
      Assert.fail('Expected WhaException');
    } catch (WhaException e) {
      Assert.isTrue(e.getMessage().startsWith('User not found'), 'Message');
    }
  }

  private static WhaUserAccessService service(Id recordId) {
    return new WhaUserAccessService(new WhaAccessContext(recordId));
  }
}
