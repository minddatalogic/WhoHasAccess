/**
 * Builds the common access-tree nodes: info, category, user, "Load more" and
 * placeholder nodes. Pure, no queries.
 */
public class WhaNodeFactory {
  private WhaNodeFactory() {
    // static helpers only
  }

  /**
   * @param label Message shown in the tree
   * @return A leaf INFO node
   */
  public static WhaAccessNodeDTO info(String label) {
    return new WhaAccessNodeDTO(WhaConstants.NODE_INFO, null, label);
  }

  /**
   * @param label Branch name
   * @return A CATEGORY node
   */
  public static WhaAccessNodeDTO category(String label) {
    return new WhaAccessNodeDTO(WhaConstants.NODE_CATEGORY, null, label);
  }

  /**
   * @param anyId Any Salesforce Id
   * @return True when the Id is a User Id
   */
  public static Boolean isUserId(Id anyId) {
    return anyId != null && anyId.getSObjectType() == User.SObjectType;
  }

  /**
   * @param userRecord User with Name, IsActive, Profile.Name and UserRole.Name, or null
   * @param fallbackId Id to show when the user could not be loaded
   * @return A USER node with "Profile · Role · INACTIVE" as subtitle
   */
  public static WhaAccessNodeDTO userNode(User userRecord, Id fallbackId) {
    if (userRecord == null) {
      return new WhaAccessNodeDTO(
        WhaConstants.NODE_USER,
        fallbackId,
        String.valueOf(fallbackId)
      );
    }
    List<String> details = new List<String>{
      userRecord.Profile?.Name ?? 'No profile'
    };
    if (userRecord.UserRole?.Name != null) {
      details.add(userRecord.UserRole.Name);
    }
    if (userRecord.IsActive == false) {
      details.add('INACTIVE');
    }
    return new WhaAccessNodeDTO(
        WhaConstants.NODE_USER,
        userRecord.Id,
        userRecord.Name
      )
      .withSubtitle(String.join(details, ' · '));
  }

  /**
   * @param users Users in the order they should appear
   * @return One USER node per user, same order
   */
  public static List<WhaAccessNodeDTO> userNodes(List<User> users) {
    List<WhaAccessNodeDTO> nodes = new List<WhaAccessNodeDTO>();
    for (User userRecord : users) {
      nodes.add(userNode(userRecord, userRecord.Id));
    }
    return nodes;
  }

  /**
   * Pages are read in Id order; this sorts them by name for display.
   * @param users Users in any order
   * @return One USER node per user, sorted by name (case-insensitive)
   */
  public static List<WhaAccessNodeDTO> userNodesSortedByName(
    List<User> users
  ) {
    Map<String, User> usersBySortKey = new Map<String, User>();
    for (User userRecord : users) {
      String sortKey =
        (userRecord.Name == null ? '' : userRecord.Name.toLowerCase()) +
        '|' +
        userRecord.Id;
      usersBySortKey.put(sortKey, userRecord);
    }
    List<String> sortKeys = new List<String>(usersBySortKey.keySet());
    sortKeys.sort();
    List<User> sorted = new List<User>();
    for (String sortKey : sortKeys) {
      sorted.add(usersBySortKey.get(sortKey));
    }
    return userNodes(sorted);
  }

  /**
   * "Load more" node: expanding it fetches the page after lastRowId.
   * @param expandType Expand type of the paged list
   * @param baseId Id the page belongs to
   * @param lastRowId Last row of the current page
   * @return A lazy MORE node
   */
  public static WhaAccessNodeDTO more(
    String expandType,
    String baseId,
    Id lastRowId
  ) {
    return new WhaAccessNodeDTO(
        WhaConstants.NODE_MORE,
        null,
        'Load next ' + WhaConstants.MAX_CHILDREN
      )
      .withSubtitle('More results — expand to load the next page')
      .lazyOn(expandType, WhaExpandCursor.encode(baseId, lastRowId));
  }

  /**
   * Group nodes are shared between share rows; each row needs its own copy.
   * @param source Node to copy, or null
   * @param fallbackId Id for a placeholder GROUP node when source is null
   * @return A copy of source, or the placeholder
   */
  public static WhaAccessNodeDTO copyOrPlaceholder(
    WhaAccessNodeDTO source,
    Id fallbackId
  ) {
    if (source == null) {
      return new WhaAccessNodeDTO(
        WhaConstants.NODE_GROUP,
        fallbackId,
        String.valueOf(fallbackId)
      );
    }
    return source.copy();
  }
}
