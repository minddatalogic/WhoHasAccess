@IsTest
private class WhaAccessNodeDTOTest {
  @IsTest
  static void shouldStartAsLeaf_WhenConstructed() {
    WhaAccessNodeDTO node = new WhaAccessNodeDTO('USER', null, 'Ann');
    Assert.isFalse(node.lazy, 'Not lazy by default');
    Assert.isNull(node.children, 'No children by default');
    Assert.isFalse(node.hasChildren(), 'hasChildren is false');
  }

  @IsTest
  static void shouldSetFields_WhenChained() {
    WhaAccessNodeDTO node = new WhaAccessNodeDTO('ROLE', null, 'CEO')
      .withSubtitle('Top')
      .withAccessLevel('Read Only')
      .withCount(3)
      .lazyOn('ROLE', 'x');
    Assert.areEqual('Top', node.subtitle, 'Subtitle set');
    Assert.areEqual('Read Only', node.accessLevel, 'Access level set');
    Assert.areEqual(3, node.count, 'Count set');
    Assert.areEqual('ROLE', node.expandType, 'Expand type set');
    Assert.areEqual('x', node.expandId, 'Expand Id set');
  }

  @IsTest
  static void shouldCreateChildList_WhenChildAdded() {
    WhaAccessNodeDTO parent = new WhaAccessNodeDTO('CATEGORY', null, 'P');
    parent.add(new WhaAccessNodeDTO('INFO', null, 'C'));
    Assert.areEqual(1, parent.children.size(), 'Child added');
    Assert.isTrue(parent.hasChildren(), 'hasChildren is true');
  }

  @IsTest
  static void shouldSetSubtitle_WhenAppendingToBlank() {
    WhaAccessNodeDTO node = new WhaAccessNodeDTO('CATEGORY', null, 'P');
    node.appendSubtitle('note');
    Assert.areEqual('note', node.subtitle, 'No separator on a blank subtitle');
  }

  @IsTest
  static void shouldSeparateWithDot_WhenAppendingToExisting() {
    WhaAccessNodeDTO node = new WhaAccessNodeDTO('CATEGORY', null, 'P')
      .withSubtitle('first');
    node.appendSubtitle('second');
    Assert.areEqual('first · second', node.subtitle, 'Joined with a dot');
  }

  @IsTest
  static void shouldNotCopyChildrenOrAccess_WhenCopied() {
    WhaAccessNodeDTO source = new WhaAccessNodeDTO('GROUP', 'id1', 'G')
      .withSubtitle('sub')
      .withAccessLevel('Read Only')
      .withCount(2)
      .lazyOn('GROUP', 'id1')
      .add(new WhaAccessNodeDTO('INFO', null, 'child'));
    WhaAccessNodeDTO copy = source.copy();
    Assert.areEqual('sub', copy.subtitle, 'Subtitle copied');
    Assert.areEqual('id1', copy.expandId, 'Expand Id copied');
    Assert.isNull(copy.children, 'Children not copied');
    Assert.isNull(copy.accessLevel, 'Access level not copied');
    Assert.isNull(copy.count, 'Count not copied');
  }
}
