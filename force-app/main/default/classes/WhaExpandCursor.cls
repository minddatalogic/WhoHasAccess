/**
 * Paging cursor carried in a node's expandId: "<baseId>><lastRowId>".
 * The first page has no cursor. Pages are keyset on the row Id
 * (ORDER BY Id, Id > lastRowId) and hold at most WhaConstants.MAX_CHILDREN rows.
 */
public class WhaExpandCursor {
  private static final String SEPARATOR = '>';

  public final String baseId; // record Id, row cause or "psId|psgId"
  public final Id afterId; // last row of the previous page, or null

  /**
   * @param rawExpandId expandId sent by the LWC
   */
  public WhaExpandCursor(String rawExpandId) {
    Boolean hasCursor =
      rawExpandId != null && rawExpandId.contains(SEPARATOR);
    this.baseId = hasCursor
      ? rawExpandId.substringBefore(SEPARATOR)
      : rawExpandId;
    this.afterId = hasCursor
      ? (Id) rawExpandId.substringAfter(SEPARATOR)
      : null;
  }

  /**
   * @return baseId as a Salesforce Id
   */
  public Id baseRecordId() {
    return (Id) baseId;
  }

  /**
   * @return True when no page has been loaded yet
   */
  public Boolean isFirstPage() {
    return afterId == null;
  }

  /**
   * @param baseId Id the page belongs to
   * @param lastRowId Last row of the current page
   * @return expandId that loads the next page
   */
  public static String encode(String baseId, Id lastRowId) {
    return baseId + SEPARATOR + lastRowId;
  }

  /**
   * Queries ask for QUERY_LIMIT rows. When the extra row came back, removes it
   * and returns the Id of the last row kept, so the caller can add a "Load more" node.
   * @param rows Rows ordered by Id; trimmed in place
   * @return Last kept row Id, or null when this is the last page
   */
  public static Id trimToPage(List<SObject> rows) {
    if (rows.size() <= WhaConstants.MAX_CHILDREN) {
      return null;
    }
    Id lastRowId = rows[WhaConstants.MAX_CHILDREN - 1].Id;
    rows.remove(WhaConstants.MAX_CHILDREN);
    return lastRowId;
  }
}
