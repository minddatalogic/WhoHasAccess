@IsTest
private class WhaAccessContextTest {
  @IsTest
  static void shouldThrow_WhenRecordIdIsNull() {
    try {
      new WhaAccessContext(null);
      Assert.fail('Expected WhaException');
    } catch (WhaException e) {
      Assert.areEqual('A record Id is required.', e.getMessage(), 'Message');
    }
  }

  @IsTest
  static void shouldDescribeObject_WhenRecordIsAccount() {
    WhaAccessContext context = new WhaAccessContext(
      WhaTestDataFactory.fakeId(Account.SObjectType, 1)
    );
    Assert.areEqual('Account', context.objectName, 'Object name');
    Assert.areEqual('Name', context.getNameField(), 'Name field');
    Assert.isTrue(context.hasOwnerField(), 'Account has an owner');
  }

  @IsTest
  static void shouldQueryIdNameAndOwner_WhenRecordIsAccount() {
    Set<String> fields = new WhaAccessContext(
        WhaTestDataFactory.fakeId(Account.SObjectType, 1)
      )
      .getRecordFields();
    Assert.isTrue(
      fields.containsAll(new Set<String>{ 'Id', 'Name', 'OwnerId' }),
      'Id, name and owner queried: ' + fields
    );
  }

  @IsTest
  static void shouldTreatAccountIdAsParent_WhenRecordIsContact() {
    WhaAccessContext context = new WhaAccessContext(
      WhaTestDataFactory.fakeId(Contact.SObjectType, 1)
    );
    Assert.isTrue(
      context.getParentFieldNames().contains('AccountId'),
      'Contact hangs off Account'
    );
  }

  @IsTest
  static void shouldUseRecordName_WhenNameFilled() {
    Account record = new Account(
      Id = WhaTestDataFactory.fakeId(Account.SObjectType, 1),
      Name = 'Acme'
    );
    Assert.areEqual(
      'Acme',
      new WhaAccessContext(record.Id).getRecordName(record),
      'Name shown'
    );
  }

  @IsTest
  static void shouldFallBackToId_WhenNameBlank() {
    Account record = new Account(
      Id = WhaTestDataFactory.fakeId(Account.SObjectType, 1)
    );
    Assert.areEqual(
      String.valueOf(record.Id),
      new WhaAccessContext(record.Id).getRecordName(record),
      'Id shown when there is no name'
    );
  }
}
