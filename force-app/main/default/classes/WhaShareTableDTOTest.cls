@IsTest
private class WhaShareTableDTOTest {
  @IsTest
  static void shouldDescribeAccountShare_WhenObjectIsAccount() {
    WhaShareTableDTO shareTable = WhaShareTableDTO.describeFor(
      Account.SObjectType.getDescribe()
    );
    Assert.areEqual('AccountShare', shareTable.shareObject, 'Share object');
    Assert.areEqual('AccountId', shareTable.parentField, 'Parent field');
    Assert.areEqual('AccountAccessLevel', shareTable.levelField, 'Level field');
    Assert.isTrue(
      shareTable.causeLabels.containsKey('Owner'),
      'RowCause picklist read from the org'
    );
  }

  @IsTest
  static void shouldReturnNull_WhenObjectHasNoShareTable() {
    Assert.isNull(
      WhaShareTableDTO.describeFor(Product2.SObjectType.getDescribe()),
      'Product2 has no share table'
    );
  }

  @IsTest
  static void shouldPrefixApexReason_WhenOrgHasLabel() {
    WhaShareTableDTO shareTable = new WhaShareTableDTO();
    shareTable.causeLabels.put('Member__c', 'Project Member');
    Assert.areEqual(
      'Apex Sharing: Project Member',
      shareTable.labelFor('Member__c'),
      'Org label with Apex prefix'
    );
  }

  @IsTest
  static void shouldUseOrgLabel_WhenStandardCause() {
    WhaShareTableDTO shareTable = new WhaShareTableDTO();
    shareTable.causeLabels.put('Manual', 'Manual Sharing');
    Assert.areEqual(
      'Manual Sharing',
      shareTable.labelFor('Manual'),
      'Org label used as is'
    );
  }

  @IsTest
  static void shouldFallBackToBuiltInLabel_WhenOrgHasNone() {
    Assert.areEqual(
      'Sharing Rule',
      new WhaShareTableDTO().labelFor('Rule'),
      'Built-in label used'
    );
  }
}
