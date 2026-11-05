@IsTest
private class WhaLabelUtilTest {
  @IsTest
  static void shouldLabelKnownSharingModel_WhenModelIsRead() {
    Assert.areEqual(
      'Public Read Only',
      WhaLabelUtil.sharingModelLabel('Read'),
      'Read is Public Read Only'
    );
  }

  @IsTest
  static void shouldReturnNotApplicable_WhenSharingModelIsNull() {
    Assert.areEqual(
      'n/a',
      WhaLabelUtil.sharingModelLabel(null),
      'Null model shows n/a'
    );
  }

  @IsTest
  static void shouldReturnApiValue_WhenSharingModelIsUnknown() {
    Assert.areEqual(
      'SomethingNew',
      WhaLabelUtil.sharingModelLabel('SomethingNew'),
      'Unknown model passes through'
    );
  }

  @IsTest
  static void shouldLabelEditAsReadWrite_WhenAccessLevelIsEdit() {
    Assert.areEqual(
      'Read/Write',
      WhaLabelUtil.accessLevelLabel('Edit'),
      'Edit is Read/Write'
    );
  }

  @IsTest
  static void shouldReturnApiValue_WhenAccessLevelIsUnknown() {
    Assert.areEqual(
      'None',
      WhaLabelUtil.accessLevelLabel('None'),
      'Unknown level passes through'
    );
  }

  @IsTest
  static void shouldLabelSharingRule_WhenCauseIsRule() {
    Assert.areEqual(
      'Sharing Rule',
      WhaLabelUtil.rowCauseLabel('Rule'),
      'Rule is Sharing Rule'
    );
  }

  @IsTest
  static void shouldLabelApexReason_WhenCauseIsCustom() {
    Assert.areEqual(
      'Apex Sharing: Project Member',
      WhaLabelUtil.rowCauseLabel('Project_Member__c'),
      'Apex sharing reasons are readable'
    );
  }

  @IsTest
  static void shouldReturnApiValue_WhenCauseIsUnknown() {
    Assert.areEqual(
      'SomeCause',
      WhaLabelUtil.rowCauseLabel('SomeCause'),
      'Unknown cause passes through'
    );
  }

  @IsTest
  static void shouldExplainCause_WhenCauseIsManual() {
    Assert.areEqual(
      'Shared manually from the UI or by code',
      WhaLabelUtil.rowCauseHelp('Manual'),
      'Manual has help text'
    );
  }

  @IsTest
  static void shouldExplainApexReason_WhenCauseIsCustom() {
    Assert.areEqual(
      'Apex managed sharing reason',
      WhaLabelUtil.rowCauseHelp('Project_Member__c'),
      'Apex reasons have generic help'
    );
  }

  @IsTest
  static void shouldReturnNullHelp_WhenCauseIsUnknown() {
    Assert.isNull(
      WhaLabelUtil.rowCauseHelp('SomeCause'),
      'Unknown cause has no help'
    );
  }

  @IsTest
  static void shouldUseGroupName_WhenGroupIsQueue() {
    Group queue = new Group(Name = 'Sales', Type = 'Queue');
    Assert.areEqual(
      'Queue: Sales',
      WhaLabelUtil.groupLabel(queue, null),
      'Queues show their name'
    );
  }

  @IsTest
  static void shouldUseGroupName_WhenGroupIsRegular() {
    Group publicGroup = new Group(Name = 'Sales', Type = 'Regular');
    Assert.areEqual(
      'Public Group: Sales',
      WhaLabelUtil.groupLabel(publicGroup, 'Ignored'),
      'Public groups show their own name'
    );
  }

  @IsTest
  static void shouldUseRelatedName_WhenGroupIsRoleAndSubordinates() {
    Group roleGroup = new Group(Name = 'X', Type = 'RoleAndSubordinates');
    Assert.areEqual(
      'Role & Subordinates: CEO',
      WhaLabelUtil.groupLabel(roleGroup, 'CEO'),
      'Role groups show the role name'
    );
  }

  @IsTest
  static void shouldFallBackToGroupName_WhenRelatedNameMissing() {
    Group roleGroup = new Group(Name = 'Fallback', Type = 'Role');
    Assert.areEqual(
      'Role: Fallback',
      WhaLabelUtil.groupLabel(roleGroup, null),
      'Group name is used when the related name is missing'
    );
  }

  @IsTest
  static void shouldLabelAllInternalUsers_WhenGroupIsOrganization() {
    Group orgGroup = new Group(Name = 'X', Type = 'Organization');
    Assert.areEqual(
      'All Internal Users',
      WhaLabelUtil.groupLabel(orgGroup, null),
      'Organization group label'
    );
  }

  @IsTest
  static void shouldUseDeveloperName_WhenTypeUnknownAndNameMissing() {
    Group otherGroup = new Group(DeveloperName = 'Dev', Type = 'Dynamic');
    Assert.areEqual(
      'Dynamic: Dev',
      WhaLabelUtil.groupLabel(otherGroup, null),
      'Unknown types show type and developer name'
    );
  }

  @IsTest
  static void shouldExplainGroupType_WhenTypeKnown() {
    Assert.areEqual(
      'Role plus every subordinate role',
      WhaLabelUtil.groupTypeLabel('RoleAndSubordinates'),
      'Known type has help'
    );
  }

  @IsTest
  static void shouldReturnType_WhenGroupTypeUnknown() {
    Assert.areEqual(
      'NewType',
      WhaLabelUtil.groupTypeLabel('NewType'),
      'Unknown type passes through'
    );
  }
}
