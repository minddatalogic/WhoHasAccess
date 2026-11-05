@IsTest
private class WhaNodeFactoryTest {
  @IsTest
  static void shouldBuildLeafInfoNode_WhenInfoCalled() {
    WhaAccessNodeDTO node = WhaNodeFactory.info('Hello');
    Assert.areEqual(WhaConstants.NODE_INFO, node.type, 'INFO type');
    Assert.areEqual('Hello', node.name, 'Label kept');
    Assert.isFalse(node.lazy, 'Info nodes are leaves');
  }

  @IsTest
  static void shouldBuildCategoryNode_WhenCategoryCalled() {
    Assert.areEqual(
      WhaConstants.NODE_CATEGORY,
      WhaNodeFactory.category('Branch').type,
      'CATEGORY type'
    );
  }

  @IsTest
  static void shouldRecogniseUserId_WhenIdIsUser() {
    Assert.isTrue(
      WhaNodeFactory.isUserId(UserInfo.getUserId()),
      'Running user Id is a user Id'
    );
  }

  @IsTest
  static void shouldRejectNonUserId_WhenIdIsGroupOrNull() {
    Id groupId = WhaTestDataFactory.fakeId(Group.SObjectType, 1);
    Assert.isFalse(WhaNodeFactory.isUserId(groupId), 'Group Id is not a user');
    Assert.isFalse(WhaNodeFactory.isUserId(null), 'Null is not a user');
  }

  @IsTest
  static void shouldShowIdAsName_WhenUserMissing() {
    Id userId = WhaTestDataFactory.fakeId(User.SObjectType, 1);
    WhaAccessNodeDTO node = WhaNodeFactory.userNode(null, userId);
    Assert.areEqual(String.valueOf(userId), node.name, 'Falls back to the Id');
    Assert.areEqual(WhaConstants.NODE_USER, node.type, 'Still a USER node');
  }

  @IsTest
  static void shouldFlagInactiveUser_WhenUserInactive() {
    User inactive = new User(
      Id = WhaTestDataFactory.fakeId(User.SObjectType, 1),
      LastName = 'Gone',
      IsActive = false
    );
    WhaAccessNodeDTO node = WhaNodeFactory.userNode(inactive, inactive.Id);
    Assert.areEqual(
      'No profile · INACTIVE',
      node.subtitle,
      'Missing profile and inactive flag shown'
    );
  }

  @IsTest
  static void shouldSortByName_WhenUserNodesSorted() {
    // Name is read-only on User, so build the records from JSON
    List<User> users = new List<User>{
      namedUser(1, 'zed'),
      namedUser(2, 'Amy')
    };
    List<WhaAccessNodeDTO> nodes = WhaNodeFactory.userNodesSortedByName(users);
    Assert.areEqual(2, nodes.size(), 'One node per user');
    Assert.areEqual(String.valueOf(users[1].Id), nodes[0].id, 'Amy sorts before zed');
  }

  @IsTest
  static void shouldEncodeCursor_WhenMoreNodeBuilt() {
    Id lastRowId = WhaTestDataFactory.fakeId(GroupMember.SObjectType, 7);
    WhaAccessNodeDTO more = WhaNodeFactory.more('GROUP', 'base', lastRowId);
    Assert.areEqual(WhaConstants.NODE_MORE, more.type, 'MORE type');
    Assert.isTrue(more.lazy, 'MORE is expandable');
    Assert.areEqual('base>' + lastRowId, more.expandId, 'Cursor encoded');
  }

  @IsTest
  static void shouldBuildPlaceholder_WhenSourceMissing() {
    Id groupId = WhaTestDataFactory.fakeId(Group.SObjectType, 1);
    WhaAccessNodeDTO node = WhaNodeFactory.copyOrPlaceholder(null, groupId);
    Assert.areEqual(WhaConstants.NODE_GROUP, node.type, 'Placeholder is GROUP');
    Assert.areEqual(String.valueOf(groupId), node.name, 'Named by Id');
  }

  @IsTest
  static void shouldCopySource_WhenSourceGiven() {
    WhaAccessNodeDTO source = new WhaAccessNodeDTO('ROLE', null, 'CEO')
      .lazyOn('GROUP', 'x');
    WhaAccessNodeDTO copy = WhaNodeFactory.copyOrPlaceholder(source, null);
    Assert.areNotEqual(source, copy, 'A new instance is returned');
    Assert.areEqual('CEO', copy.name, 'Name copied');
    Assert.isTrue(copy.lazy, 'Lazy flag copied');
  }

  private static User namedUser(Integer index, String name) {
    Id userId = WhaTestDataFactory.fakeId(User.SObjectType, index);
    return (User) System.JSON.deserialize(
      System.JSON.serialize(new Map<String, Object>{ 'Id' => userId, 'Name' => name }),
      User.class
    );
  }
}
