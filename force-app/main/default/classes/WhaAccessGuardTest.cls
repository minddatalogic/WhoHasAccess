@IsTest
private class WhaAccessGuardTest {
  @TestSetup
  static void setup() {
    WhaTestDataFactory.createAccessScenario();
  }

  @IsTest
  static void shouldThrow_WhenRecordIdNull() {
    try {
      WhaAccessGuard.assertCanAnalyse(null);
      Assert.fail('Expected WhaException');
    } catch (WhaException e) {
      Assert.areEqual('A record Id is required.', e.getMessage(), 'Message');
    }
  }

  @IsTest
  static void shouldThrow_WhenCustomPermissionMissing() {
    Account account = WhaTestDataFactory.getAccount();
    User member = WhaTestDataFactory.getUser(WhaTestDataFactory.MEMBER_ALIAS);
    System.runAs(member) {
      try {
        WhaAccessGuard.assertCanAnalyse(account.Id);
        Assert.fail('Expected WhaException');
      } catch (WhaException e) {
        Assert.isTrue(
          e.getMessage().contains('"Who Has Access" permission set'),
          'Permission message: ' + e.getMessage()
        );
      }
    }
  }

  @IsTest
  static void shouldAllow_WhenViewerCanReadRecord() {
    Account account = WhaTestDataFactory.getAccount();
    User viewer = WhaTestDataFactory.getUser(WhaTestDataFactory.VIEWER_ALIAS);
    Boolean allowed = false;
    System.runAs(viewer) {
      WhaAccessGuard.assertCanAnalyse(account.Id);
      allowed = true;
    }
    Assert.isTrue(allowed, 'Viewer owns the record and holds the permission');
  }
}
