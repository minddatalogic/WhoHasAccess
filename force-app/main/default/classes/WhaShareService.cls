/**
 * Record sharing: the share-table rows of the analysed record, grouped by
 * RowCause. Small causes (<= INLINE_PER_CAUSE rows, <= INLINE_TOTAL overall)
 * load with the tree; larger ones are lazy and page MAX_CHILDREN rows at a time.
 */
public with sharing class WhaShareService {
  private final WhaAccessContext context;
  private final WhaGroupService groupService = new WhaGroupService();
  private final WhaUserSelector userSelector = new WhaUserSelector();
  private WhaShareTableDTO shareTable;
  private Boolean shareTableResolved = false;

  /**
   * @param context Analysed record
   */
  public WhaShareService(WhaAccessContext context) {
    this.context = context;
  }

  /**
   * @return The "Record Sharing" branch with one node per RowCause
   */
  public WhaAccessNodeDTO buildShareBranch() {
    WhaShareTableDTO table = getShareTable();
    if (table == null) {
      return WhaNodeFactory.category('Record Sharing')
        .withSubtitle('This object has no share table')
        .add(
          WhaNodeFactory.info(
            'Sharing is not tracked per record for this object'
          )
        );
    }
    WhaAccessNodeDTO branch = WhaNodeFactory.category(
      'Record Sharing (' + table.shareObject + ')'
    );
    WhaShareSelector shareSelector = new WhaShareSelector(
      table,
      context.recordId
    );
    Map<String, Integer> countsByCause = shareSelector.countRowsByCause();
    Integer totalRows = 0;
    for (Integer causeCount : countsByCause.values()) {
      totalRows += causeCount;
    }
    if (totalRows == 0) {
      return branch
        .withSubtitle('No share rows')
        .add(WhaNodeFactory.info('No share rows found'));
    }
    branch.withSubtitle(
      totalRows +
        ' share row(s) across ' +
        countsByCause.size() +
        ' row cause(s)'
    );
    addCauseNodes(branch, countsByCause, shareSelector);
    return branch;
  }

  /**
   * @param cause RowCause to page through
   * @param afterId Last share row of the previous page, or null
   * @return One node per share row, plus a MORE node when there are more
   */
  public List<WhaAccessNodeDTO> expandShareRows(String cause, Id afterId) {
    WhaShareTableDTO table = getShareTable();
    if (table == null) {
      return new List<WhaAccessNodeDTO>{
        WhaNodeFactory.info('No share table')
      };
    }
    WhaShareSelector shareSelector = new WhaShareSelector(
      table,
      context.recordId
    );
    List<SObject> rows = shareSelector.selectPageForCause(cause, afterId);
    Id lastRowId = WhaExpandCursor.trimToPage(rows);
    List<WhaAccessNodeDTO> nodes = buildRowNodes(rows, table.levelField);
    if (lastRowId != null) {
      nodes.add(
        WhaNodeFactory.more(WhaConstants.EXPAND_SHARE_ROWS, cause, lastRowId)
      );
    }
    if (nodes.isEmpty()) {
      nodes.add(WhaNodeFactory.info('No share rows'));
    }
    return nodes;
  }

  /** Adds a node per cause; small causes get their rows in one extra query. */
  private void addCauseNodes(
    WhaAccessNodeDTO branch,
    Map<String, Integer> countsByCause,
    WhaShareSelector shareSelector
  ) {
    Map<String, WhaAccessNodeDTO> nodesByCause = new Map<String, WhaAccessNodeDTO>();
    List<String> inlineCauses = new List<String>();
    Integer inlineRows = 0;
    for (String cause : countsByCause.keySet()) {
      Integer causeCount = countsByCause.get(cause);
      WhaAccessNodeDTO causeNode = new WhaAccessNodeDTO(
          WhaConstants.NODE_ROWCAUSE,
          null,
          shareTable.labelFor(cause)
        )
        .withSubtitle(WhaLabelUtil.rowCauseHelp(cause))
        .withCount(causeCount);
      if (isInline(causeCount, inlineRows)) {
        inlineCauses.add(cause);
        inlineRows += causeCount;
      } else {
        causeNode.lazyOn(WhaConstants.EXPAND_SHARE_ROWS, cause);
      }
      nodesByCause.put(cause, causeNode);
      branch.add(causeNode);
    }
    List<SObject> rows = shareSelector.selectRowsForCauses(
      inlineCauses,
      WhaConstants.INLINE_TOTAL
    );
    List<WhaAccessNodeDTO> rowNodes = buildRowNodes(rows, shareTable.levelField);
    for (Integer index = 0; index < rows.size(); index++) {
      String cause = (String) rows[index].get('RowCause');
      nodesByCause.get(cause).add(rowNodes[index]);
    }
  }

  /** Resolves users and groups for share rows with a fixed number of queries. */
  private List<WhaAccessNodeDTO> buildRowNodes(
    List<SObject> rows,
    String levelField
  ) {
    Set<Id> userIds = new Set<Id>();
    Set<Id> groupIds = new Set<Id>();
    for (SObject row : rows) {
      Id userOrGroupId = (Id) row.get('UserOrGroupId');
      if (WhaNodeFactory.isUserId(userOrGroupId)) {
        userIds.add(userOrGroupId);
      } else {
        groupIds.add(userOrGroupId);
      }
    }
    Map<Id, User> usersById = userSelector.selectByIds(userIds);
    Map<Id, WhaAccessNodeDTO> groupNodesById = groupService.buildGroupNodes(
      groupIds
    );
    List<WhaAccessNodeDTO> nodes = new List<WhaAccessNodeDTO>();
    for (SObject row : rows) {
      Id userOrGroupId = (Id) row.get('UserOrGroupId');
      WhaAccessNodeDTO node = WhaNodeFactory.isUserId(userOrGroupId)
        ? WhaNodeFactory.userNode(usersById.get(userOrGroupId), userOrGroupId)
        : WhaNodeFactory.copyOrPlaceholder(
            groupNodesById.get(userOrGroupId),
            userOrGroupId
          );
      nodes.add(
        node.withAccessLevel(
          WhaLabelUtil.accessLevelLabel((String) row.get(levelField))
        )
      );
    }
    return nodes;
  }

  @TestVisible
  private static Boolean isInline(Integer causeCount, Integer inlineRowsSoFar) {
    return causeCount <= WhaConstants.INLINE_PER_CAUSE &&
      inlineRowsSoFar + causeCount <= WhaConstants.INLINE_TOTAL;
  }

  private WhaShareTableDTO getShareTable() {
    if (!shareTableResolved) {
      shareTable = WhaShareTableDTO.describeFor(context.objectDescribe);
      shareTableResolved = true;
    }
    return shareTable;
  }
}
