@IsTest
private class WhaAccessTreeServiceTest {
  @TestSetup
  static void setup() {
    WhaTestDataFactory.createAccessScenario();
  }

  @IsTest
  static void shouldNameRootAfterRecord_WhenTreeBuilt() {
    Account account = WhaTestDataFactory.getAccount();

    Test.startTest();
    WhaAccessNodeDTO root = service(account.Id).buildTree();
    Test.stopTest();

    Assert.areEqual(WhaConstants.NODE_RECORD, root.type, 'Root is the record');
    Assert.areEqual(WhaTestDataFactory.ACCOUNT_NAME, root.name, 'Record name');
    Assert.isTrue(root.subtitle.startsWith('Account · Internal OWD: '), 'OWD summary');
  }

  @IsTest
  static void shouldShowOrgWideDefault_WhenTreeBuilt() {
    Account account = WhaTestDataFactory.getAccount();
    String expected =
      'Org-Wide Default: ' +
      WhaLabelUtil.sharingModelLabel(WhaTestDataFactory.getSharingModel('Account'));

    Test.startTest();
    WhaAccessNodeDTO root = service(account.Id).buildTree();
    Test.stopTest();

    Assert.isNotNull(WhaTestDataFactory.findChild(root, expected), 'OWD branch: ' + expected);
  }

  @IsTest
  static void shouldIncludeBypassSharingAndRoleBranches_WhenAccountTreeBuilt() {
    Account account = WhaTestDataFactory.getAccount();

    Test.startTest();
    WhaAccessNodeDTO root = service(account.Id).buildTree();
    Test.stopTest();

    Assert.isNotNull(WhaTestDataFactory.findChild(root, 'Object Permission Bypass'), 'Bypass');
    Assert.isNotNull(WhaTestDataFactory.findChild(root, 'Record Sharing'), 'Sharing');
    WhaAccessNodeDTO hierarchy = WhaTestDataFactory.findChild(root, 'Role Hierarchy');
    Assert.isNotNull(
      WhaTestDataFactory.findChild(hierarchy, WhaTestDataFactory.TOP_ROLE_NAME),
      'Owner\'s parent role listed'
    );
  }

  @IsTest
  static void shouldOfferParentAccount_WhenContactHasAccount() {
    Account account = WhaTestDataFactory.getAccount();
    Contact child = new Contact(LastName = 'WHA Child', AccountId = account.Id);
    insert child;

    Test.startTest();
    List<WhaAccessNodeDTO> parents = service(child.Id).buildParentNodes(child);
    Test.stopTest();

    Assert.areEqual(WhaConstants.NODE_PARENT, parents[0].type, 'Parent node');
    Assert.areEqual(String.valueOf(account.Id), parents[0].id, 'Parent account');
  }

  @IsTest
  static void shouldSayNoParent_WhenContactHasNoAccount() {
    Contact orphan = new Contact(LastName = 'WHA Orphan');
    insert orphan;

    Test.startTest();
    List<WhaAccessNodeDTO> parents = service(orphan.Id).buildParentNodes(orphan);
    Test.stopTest();

    Assert.areEqual(
      'No parent record found on this record',
      parents[0].name,
      'Missing parent explained'
    );
  }

  @IsTest
  static void shouldThrow_WhenRecordDeleted() {
    Product2 product = new Product2(Name = 'WHA Gone');
    insert product;
    delete product;
    try {
      service(product.Id).buildTree();
      Assert.fail('Expected WhaException');
    } catch (WhaException e) {
      Assert.isTrue(e.getMessage().startsWith('Record not found'), 'Message');
    }
  }

  private static WhaAccessTreeService service(Id recordId) {
    return new WhaAccessTreeService(new WhaAccessContext(recordId));
  }
}
