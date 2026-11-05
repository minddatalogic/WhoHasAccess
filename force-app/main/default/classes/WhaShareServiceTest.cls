@IsTest
private class WhaShareServiceTest {
  @TestSetup
  static void setup() {
    WhaTestDataFactory.createAccessScenario();
  }

  @IsTest
  static void shouldInlineOwnerRow_WhenAccountHasOwnerShare() {
    Account account = WhaTestDataFactory.getAccount();

    Test.startTest();
    WhaAccessNodeDTO branch = service(account.Id).buildShareBranch();
    Test.stopTest();

    if (!WhaTestDataFactory.accountHasOwnerShare(account.Id)) {
      // Public Read/Write orgs may store no owner share row.
      Assert.areEqual('No share rows', branch.subtitle, 'Empty share table explained');
      return;
    }
    WhaAccessNodeDTO owner = WhaTestDataFactory.findChild(branch, 'Owner');
    Assert.isNotNull(owner, 'Owner row cause listed: ' + JSON.serialize(branch));
    Assert.isFalse(owner.lazy, 'Small causes load with the tree');
    Assert.areEqual(String.valueOf(account.OwnerId), owner.children[0].id, 'Owner row is the viewer');
    Assert.areEqual('Full Access', owner.children[0].accessLevel, 'Owner has All');
  }

  @IsTest
  static void shouldPageRows_WhenCauseExpanded() {
    Account account = WhaTestDataFactory.getAccount();

    Test.startTest();
    List<WhaAccessNodeDTO> rows = service(account.Id)
      .expandShareRows('Owner', null);
    Test.stopTest();

    if (!WhaTestDataFactory.accountHasOwnerShare(account.Id)) {
      Assert.areEqual(WhaConstants.NODE_INFO, rows[0].type, 'No owner row explained');
      return;
    }
    Assert.areEqual(1, rows.size(), 'One owner row');
    Assert.areEqual(WhaConstants.NODE_USER, rows[0].type, 'Owner is a user');
  }

  @IsTest
  static void shouldReturnInfo_WhenCauseHasNoRows() {
    Account account = WhaTestDataFactory.getAccount();

    Test.startTest();
    List<WhaAccessNodeDTO> rows = service(account.Id)
      .expandShareRows('NoSuchCause', null);
    Test.stopTest();

    Assert.areEqual('No share rows', rows[0].name, 'Empty cause explained');
  }

  @IsTest
  static void shouldExplain_WhenObjectHasNoShareTable() {
    Product2 product = new Product2(Name = 'WHA Product');
    insert product;

    Test.startTest();
    WhaShareService shareService = service(product.Id);
    WhaAccessNodeDTO branch = shareService.buildShareBranch();
    List<WhaAccessNodeDTO> rows = shareService.expandShareRows('Owner', null);
    Test.stopTest();

    Assert.areEqual('This object has no share table', branch.subtitle, 'Branch');
    Assert.areEqual('No share table', rows[0].name, 'Expand');
  }

  @IsTest
  static void shouldPageLargeCause_WhenManualSharesExceedPage() {
    if (!WhaTestDataFactory.accountAllowsManualShares()) {
      // Public Read/Write orgs cannot hold manual shares; nothing to page.
      Assert.isFalse(WhaTestDataFactory.accountAllowsManualShares(), 'Skipped');
      return;
    }
    Account account = WhaTestDataFactory.getAccount();
    Integer shareCount = WhaConstants.MAX_CHILDREN + 5;
    List<Id> groupIds = new List<Id>();
    System.runAs(new User(Id = UserInfo.getUserId())) {
      for (Group g : WhaTestDataFactory.createGroups('WHA Share', 'Regular', shareCount, false)) {
        groupIds.add(g.Id);
      }
    }
    WhaTestDataFactory.createManualAccountShares(account.Id, groupIds, 'Read');

    Test.startTest();
    WhaAccessNodeDTO manual = WhaTestDataFactory.findChild(
      service(account.Id).buildShareBranch(),
      'Manual'
    );
    List<WhaAccessNodeDTO> page1 = service(account.Id)
      .expandShareRows('Manual', null);
    WhaAccessNodeDTO more = page1[page1.size() - 1];
    List<WhaAccessNodeDTO> page2 = new WhaExpandService(
        new WhaAccessContext(account.Id)
      )
      .expand(more.expandType, more.expandId);
    Test.stopTest();

    Assert.areEqual(shareCount, manual.count, 'Summary count');
    Assert.isTrue(manual.lazy, 'Large cause is paged, not inlined');
    Assert.areEqual(WhaConstants.MAX_CHILDREN + 1, page1.size(), 'Page + MORE');
    Assert.areEqual(WhaConstants.NODE_MORE, more.type, 'Last node loads more');
    Assert.areEqual(5, page2.size(), 'Remaining rows on page 2');
    Assert.areEqual('Read Only', page2[0].accessLevel, 'Access level label');
  }

  @IsTest
  static void shouldInline_WhenCauseSmallAndRoomLeft() {
    Assert.isTrue(
      WhaShareService.isInline(WhaConstants.INLINE_PER_CAUSE, 0),
      'A cause at the per-cause limit is inlined'
    );
  }

  @IsTest
  static void shouldNotInline_WhenCauseOverPerCauseLimit() {
    Assert.isFalse(
      WhaShareService.isInline(WhaConstants.INLINE_PER_CAUSE + 1, 0),
      'Large causes are lazy'
    );
  }

  @IsTest
  static void shouldNotInline_WhenTotalWouldBeExceeded() {
    Assert.isFalse(
      WhaShareService.isInline(10, WhaConstants.INLINE_TOTAL - 5),
      'Inline total is capped'
    );
  }

  private static WhaShareService service(Id recordId) {
    return new WhaShareService(new WhaAccessContext(recordId));
  }
}
