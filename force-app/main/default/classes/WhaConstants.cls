/**
 * Constants shared by the Who Has Access classes: node and expand types sent to
 * the whoHasAccess LWC, paging limits and the custom permission name.
 *
 * Plain strings rather than enums: they are the wire format the LWC reads, and
 * some values (GROUP) are reserved words in Apex.
 */
public class WhaConstants {
  public static final String CUSTOM_PERMISSION = 'Who_Has_Access_Viewer';

  // ─── Paging and depth limits ──────────────────────────────────────────
  public static final Integer MAX_CHILDREN = 200; // per expand call; more are paged
  public static final Integer QUERY_LIMIT = MAX_CHILDREN + 1; // one extra row = another page exists
  public static final Integer INLINE_PER_CAUSE = 50; // row causes up to this size load with the tree
  public static final Integer INLINE_TOTAL = 200; // max share rows loaded with the tree
  public static final Integer MAX_ROLE_DEPTH = 25; // Salesforce recommends <= 10 levels
  public static final Integer MAX_MANAGER_DEPTH = 50;

  // ─── Node types (WhaAccessNodeDTO.type) ───────────────────────────────
  public static final String NODE_RECORD = 'RECORD';
  public static final String NODE_CATEGORY = 'CATEGORY';
  public static final String NODE_ROWCAUSE = 'ROWCAUSE';
  public static final String NODE_USER = 'USER';
  public static final String NODE_GROUP = 'GROUP';
  public static final String NODE_ROLE = 'ROLE';
  public static final String NODE_PROFILE = 'PROFILE';
  public static final String NODE_PERMSET = 'PERMSET';
  public static final String NODE_PSG = 'PSG';
  public static final String NODE_PARENT = 'PARENT';
  public static final String NODE_INFO = 'INFO';
  public static final String NODE_MORE = 'MORE';

  // ─── Expand types (WhaAccessNodeDTO.expandType) ───────────────────────
  // Keep in sync with the switch in WhaExpandService.expand.
  public static final String EXPAND_SHARE_ROWS = 'SHARE_ROWS';
  public static final String EXPAND_GROUP = 'GROUP';
  public static final String EXPAND_ROLE = 'ROLE';
  public static final String EXPAND_ROLE_SUB = 'ROLE_SUB';
  public static final String EXPAND_ROLE_SUB_INTERNAL = 'ROLE_SUB_INT';
  public static final String EXPAND_MANAGER_UP = 'MANAGER_UP';
  public static final String EXPAND_MANAGER_SUB = 'MANAGER_SUB';
  public static final String EXPAND_PERMSET = 'PERMSET';
  public static final String EXPAND_TERRITORY = 'TERRITORY';
  public static final String EXPAND_TERRITORY_SUB = 'TERRITORY_SUB';
  public static final String EXPAND_CHATTER = 'CHATTER';

  private WhaConstants() {
    // constants only
  }
}
