/**
 * Manager-based access (Manager and ManagerAndSubordinatesInternal groups):
 * a user's manager chain, and a user's direct reports.
 */
public with sharing class WhaManagerService {
  private final WhaUserSelector userSelector = new WhaUserSelector();

  /**
   * @param userId The group's user
   * @return The user followed by their direct and indirect managers
   */
  public List<WhaAccessNodeDTO> expandManagerChain(Id userId) {
    List<WhaAccessNodeDTO> nodes = new List<WhaAccessNodeDTO>();
    for (
      User chainUser : userSelector.selectManagerChain(
        userId,
        WhaConstants.MAX_MANAGER_DEPTH
      )
    ) {
      WhaAccessNodeDTO node = WhaNodeFactory.userNode(chainUser, chainUser.Id);
      node.subtitle =
        (chainUser.Id == userId ? 'Group user' : 'Manager') +
        ' · ' +
        node.subtitle;
      nodes.add(node);
    }
    return nodes;
  }

  /**
   * Each report is lazy, so the user can drill into their own reports.
   * @param userId Manager's user Id
   * @param includeSelf True at group level (show the group's own user first)
   * @param afterId Last report of the previous page, or null
   * @return User nodes, plus a MORE node when there are more reports
   */
  public List<WhaAccessNodeDTO> expandReports(
    Id userId,
    Boolean includeSelf,
    Id afterId
  ) {
    List<WhaAccessNodeDTO> nodes = new List<WhaAccessNodeDTO>();
    if (includeSelf && afterId == null) {
      nodes.addAll(
        WhaNodeFactory.userNodes(
          userSelector.selectByIds(new Set<Id>{ userId }).values()
        )
      );
    }
    List<User> page = userSelector.selectActiveReportsPage(userId, afterId);
    Id lastRowId = WhaExpandCursor.trimToPage(page);
    for (WhaAccessNodeDTO reportNode : WhaNodeFactory.userNodesSortedByName(page)) {
      reportNode.lazyOn(WhaConstants.EXPAND_MANAGER_SUB, reportNode.id);
      reportNode.subtitle = 'Direct report · ' + reportNode.subtitle;
      nodes.add(reportNode);
    }
    if (lastRowId != null) {
      nodes.add(
        WhaNodeFactory.more(WhaConstants.EXPAND_MANAGER_SUB, userId, lastRowId)
      );
    }
    if (nodes.isEmpty()) {
      nodes.add(WhaNodeFactory.info('No direct reports'));
    }
    return nodes;
  }
}
