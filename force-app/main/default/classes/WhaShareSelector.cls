/**
 * Reads share-table rows (AccountShare, Obj__Share...) for one record.
 *
 * without sharing / SYSTEM_MODE: share rows are only partly visible to normal
 * users. WhaAccessGuard runs first. Table and field names come from the
 * describe (WhaShareTableDTO), never from user input; values are bound.
 */
public without sharing class WhaShareSelector {
  private final WhaShareTableDTO shareTable;
  private final Id recordId;

  /**
   * @param shareTable Share table of the record's object
   * @param recordId Record whose share rows are read
   */
  public WhaShareSelector(WhaShareTableDTO shareTable, Id recordId) {
    this.shareTable = shareTable;
    this.recordId = recordId;
  }

  /**
   * One aggregate query; charged one query row per cause.
   * @return Share row count per RowCause
   */
  public Map<String, Integer> countRowsByCause() {
    Map<String, Integer> countsByCause = new Map<String, Integer>();
    List<AggregateResult> results = (List<AggregateResult>) Database.queryWithBinds(
      'SELECT RowCause rowCause, COUNT(Id) total FROM ' +
        shareTable.shareObject +
        ' WHERE ' +
        shareTable.parentField +
        ' = :recordId GROUP BY RowCause',
      new Map<String, Object>{ 'recordId' => recordId },
      AccessLevel.SYSTEM_MODE
    );
    for (AggregateResult result : results) {
      countsByCause.put(
        (String) result.get('rowCause'),
        (Integer) result.get('total')
      );
    }
    return countsByCause;
  }

  /**
   * @param causes Row causes to load
   * @param maxRows Row limit
   * @return Share rows (Id, UserOrGroupId, RowCause, access level) ordered by Id
   */
  public List<SObject> selectRowsForCauses(
    List<String> causes,
    Integer maxRows
  ) {
    if (causes == null || causes.isEmpty()) {
      return new List<SObject>();
    }
    return Database.queryWithBinds(
      baseQuery() + ' AND RowCause IN :causes ORDER BY Id LIMIT ' + maxRows,
      new Map<String, Object>{ 'recordId' => recordId, 'causes' => causes },
      AccessLevel.SYSTEM_MODE
    );
  }

  /**
   * @param cause Row cause to page through
   * @param afterId Last share row of the previous page, or null
   * @return Up to WhaConstants.QUERY_LIMIT share rows ordered by Id
   */
  public List<SObject> selectPageForCause(String cause, Id afterId) {
    Map<String, Object> binds = new Map<String, Object>{
      'recordId' => recordId,
      'cause' => cause
    };
    String soql = baseQuery() + ' AND RowCause = :cause';
    if (afterId != null) {
      soql += ' AND Id > :afterId';
      binds.put('afterId', afterId);
    }
    soql += ' ORDER BY Id LIMIT ' + WhaConstants.QUERY_LIMIT;
    return Database.queryWithBinds(soql, binds, AccessLevel.SYSTEM_MODE);
  }

  /**
   * @return Field name holding the access level on this share table
   */
  public String getLevelField() {
    return shareTable.levelField;
  }

  private String baseQuery() {
    return 'SELECT Id, UserOrGroupId, RowCause, ' +
      shareTable.levelField +
      ' FROM ' +
      shareTable.shareObject +
      ' WHERE ' +
      shareTable.parentField +
      ' = :recordId';
  }
}
