/**
 * End-to-end tests through the @AuraEnabled API the LWC calls, run as real
 * users. Detailed behaviour is covered by the Wha*Test classes.
 */
@IsTest
private class WhoHasAccessControllerTest {
  @TestSetup
  static void setup() {
    WhaTestDataFactory.createAccessScenario();
  }

  @IsTest
  static void shouldReturnTreeWithBranches_WhenViewerOpensOwnRecord() {
    Account account = WhaTestDataFactory.getAccount();
    WhaAccessNodeDTO root;
    System.runAs(viewer()) {
      Test.startTest();
      root = WhoHasAccessController.getAccessTree(account.Id);
      Test.stopTest();
    }
    Assert.areEqual(WhaConstants.NODE_RECORD, root.type, 'Root is the record');
    Assert.isNotNull(WhaTestDataFactory.findChild(root, 'Org-Wide Default'), 'OWD');
    Assert.isNotNull(WhaTestDataFactory.findChild(root, 'Object Permission Bypass'), 'Bypass');
    Assert.isNotNull(WhaTestDataFactory.findChild(root, 'Record Sharing'), 'Sharing');
    Assert.isNotNull(WhaTestDataFactory.findChild(root, 'Role Hierarchy'), 'Roles');
  }

  @IsTest
  static void shouldReturnMembers_WhenViewerExpandsGroup() {
    Account account = WhaTestDataFactory.getAccount();
    Group testGroup = WhaTestDataFactory.getGroup(WhaTestDataFactory.GROUP_NAME);
    User member = WhaTestDataFactory.getUser(WhaTestDataFactory.MEMBER_ALIAS);
    List<WhaAccessNodeDTO> nodes;
    System.runAs(viewer()) {
      Test.startTest();
      nodes = WhoHasAccessController.expandNode(
        WhaConstants.EXPAND_GROUP,
        testGroup.Id,
        account.Id
      );
      Test.stopTest();
    }
    Assert.isTrue(WhaTestDataFactory.containsId(nodes, member.Id), 'Member listed');
  }

  @IsTest
  static void shouldReturnFullAccess_WhenViewerChecksOwnAccess() {
    Account account = WhaTestDataFactory.getAccount();
    User viewerUser = viewer();
    WhaUserAccessDTO access;
    System.runAs(viewerUser) {
      Test.startTest();
      access = WhoHasAccessController.getUserAccess(viewerUser.Id, account.Id);
      Test.stopTest();
    }
    Assert.areEqual('Full Access', access.maxAccess, 'Owner has full access');
  }

  @IsTest
  static void shouldReject_WhenCustomPermissionMissing() {
    Account account = WhaTestDataFactory.getAccount();
    User member = WhaTestDataFactory.getUser(WhaTestDataFactory.MEMBER_ALIAS);
    System.runAs(member) {
      try {
        WhoHasAccessController.getAccessTree(account.Id);
        Assert.fail('Expected AuraHandledException');
      } catch (AuraHandledException e) {
        Assert.isTrue(
          e.getMessage().contains('"Who Has Access" permission set'),
          'Permission message: ' + e.getMessage()
        );
      }
    }
  }

  @IsTest
  static void shouldReject_WhenRecordIdNull() {
    System.runAs(viewer()) {
      try {
        WhoHasAccessController.getAccessTree(null);
        Assert.fail('Expected AuraHandledException');
      } catch (AuraHandledException e) {
        Assert.areEqual('A record Id is required.', e.getMessage(), 'Message');
      }
    }
  }

  @IsTest
  static void shouldPassMessageThrough_WhenExpandTypeUnknown() {
    Account account = WhaTestDataFactory.getAccount();
    System.runAs(viewer()) {
      try {
        WhoHasAccessController.expandNode('NOPE', account.Id, account.Id);
        Assert.fail('Expected AuraHandledException');
      } catch (AuraHandledException e) {
        Assert.areEqual('Unknown expand type: NOPE', e.getMessage(), 'Message');
      }
    }
  }

  @IsTest
  static void shouldHideInternals_WhenUnexpectedErrorOccurs() {
    Account account = WhaTestDataFactory.getAccount();
    System.runAs(viewer()) {
      try {
        // "not-an-id" fails the Id cast deep inside the services
        WhoHasAccessController.expandNode(
          WhaConstants.EXPAND_GROUP,
          'not-an-id',
          account.Id
        );
        Assert.fail('Expected AuraHandledException');
      } catch (AuraHandledException e) {
        Assert.areEqual(
          'Who Has Access could not finish this request (System.StringException).',
          e.getMessage(),
          'Generic message with the exception type only'
        );
      }
    }
  }

  private static User viewer() {
    return WhaTestDataFactory.getUser(WhaTestDataFactory.VIEWER_ALIAS);
  }
}
