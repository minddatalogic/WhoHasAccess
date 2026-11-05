@IsTest
private class WhaPermissionContainerDTOTest {
  @IsTest
  static void shouldUseProfileName_WhenOwnedByProfile() {
    WhaPermissionContainerDTO container = WhaPermissionContainerDTO.fromPermissionSet(
      permissionSet(
        '{"IsOwnedByProfile":true,"Type":"Profile","Label":"X00","Profile":{"Name":"Sales User"}}'
      ),
      'Read Only'
    );
    Assert.areEqual(WhaConstants.NODE_PROFILE, container.kind, 'Profile kind');
    Assert.areEqual('Sales User', container.label, 'Profile name used');
    Assert.areEqual('Read Only', container.grantedAccess, 'Grant kept');
  }

  @IsTest
  static void shouldBePermissionSetGroup_WhenTypeIsGroup() {
    WhaPermissionContainerDTO container = WhaPermissionContainerDTO.fromPermissionSet(
      permissionSet('{"IsOwnedByProfile":false,"Type":"Group","Label":"Team"}'),
      'Read Only'
    );
    Assert.areEqual(WhaConstants.NODE_PSG, container.kind, 'PSG kind');
  }

  @IsTest
  static void shouldMarkSessionBased_WhenTypeIsSession() {
    WhaPermissionContainerDTO container = WhaPermissionContainerDTO.fromPermissionSet(
      permissionSet('{"IsOwnedByProfile":false,"Type":"Session","Label":"Temp"}'),
      'Read Only'
    );
    Assert.areEqual(WhaConstants.NODE_PERMSET, container.kind, 'Perm set kind');
    Assert.areEqual('Temp (session-based)', container.label, 'Session suffix');
  }

  @IsTest
  static void shouldUsePermissionSetIdOnly_WhenNoGroup() {
    WhaPermissionContainerDTO container = new WhaPermissionContainerDTO();
    container.permissionSetId = WhaTestDataFactory.fakeId(
      PermissionSet.SObjectType,
      1
    );
    Assert.areEqual(
      String.valueOf(container.permissionSetId),
      container.toExpandId(),
      'Only the permission set Id'
    );
  }

  @IsTest
  static void shouldRoundTripExpandId_WhenGroupPresent() {
    WhaPermissionContainerDTO container = new WhaPermissionContainerDTO();
    container.permissionSetId = WhaTestDataFactory.fakeId(
      PermissionSet.SObjectType,
      1
    );
    container.permissionSetGroupId = WhaTestDataFactory.fakeId(
      PermissionSetGroup.SObjectType,
      2
    );
    List<Id> ids = WhaPermissionContainerDTO.parseExpandId(
      container.toExpandId()
    );
    Assert.areEqual(container.permissionSetId, ids[0], 'Permission set Id');
    Assert.areEqual(container.permissionSetGroupId, ids[1], 'Group Id');
  }

  @IsTest
  static void shouldReturnNullGroup_WhenExpandIdHasNoGroup() {
    Id permissionSetId = WhaTestDataFactory.fakeId(PermissionSet.SObjectType, 1);
    List<Id> ids = WhaPermissionContainerDTO.parseExpandId(permissionSetId);
    Assert.isNull(ids[1], 'No group Id');
  }

  private static PermissionSet permissionSet(String json) {
    return (PermissionSet) System.JSON.deserialize(json, PermissionSet.class);
  }
}
