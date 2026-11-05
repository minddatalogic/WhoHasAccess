/**
 * Who Has Access — explains who can see a record, and why.
 *
 * Thin @AuraEnabled entry point for the whoHasAccess LWC. Each method checks
 * access (WhaAccessGuard), delegates to a service and turns errors into
 * AuraHandledException. The services read share, group and permission tables
 * through `without sharing` selectors, so the guard must always run first.
 *
 *   getAccessTree -> WhaAccessTreeService   (first two levels of the tree)
 *   expandNode    -> WhaExpandService       (lazy children, paged)
 *   getUserAccess -> WhaUserAccessService   (effective access of one user)
 */
public with sharing class WhoHasAccessController {
  private static final String UNEXPECTED_ERROR = 'Who Has Access could not finish this request';

  /**
   * @param recordId Record to analyse
   * @return Root RECORD node with the OWD, bypass, sharing and role branches
   * @throws AuraHandledException when access is denied or resolution fails
   */
  @AuraEnabled
  public static WhaAccessNodeDTO getAccessTree(Id recordId) {
    try {
      WhaAccessGuard.assertCanAnalyse(recordId);
      return new WhaAccessTreeService(new WhaAccessContext(recordId))
        .buildTree();
    } catch (Exception error) {
      throw toAuraException(error);
    }
  }

  /**
   * @param expandType Expand type of the lazy node (WhaConstants.EXPAND_*)
   * @param expandId The node's expandId, optionally with a paging cursor
   * @param recordId Record being analysed
   * @return Up to MAX_CHILDREN child nodes plus a MORE node when paged
   * @throws AuraHandledException when access is denied or resolution fails
   */
  @AuraEnabled
  public static List<WhaAccessNodeDTO> expandNode(
    String expandType,
    String expandId,
    Id recordId
  ) {
    try {
      WhaAccessGuard.assertCanAnalyse(recordId);
      return new WhaExpandService(new WhaAccessContext(recordId))
        .expand(expandType, expandId);
    } catch (Exception error) {
      throw toAuraException(error);
    }
  }

  /**
   * @param userId User to check
   * @param recordId Record being analysed
   * @return The user's record, object and system access
   * @throws AuraHandledException when access is denied or resolution fails
   */
  @AuraEnabled
  public static WhaUserAccessDTO getUserAccess(Id userId, Id recordId) {
    try {
      WhaAccessGuard.assertCanAnalyse(recordId);
      return new WhaUserAccessService(new WhaAccessContext(recordId))
        .getUserAccess(userId);
    } catch (Exception error) {
      throw toAuraException(error);
    }
  }

  /**
   * WhaException messages are written for users and pass through. Anything
   * else gets a generic message with the exception type, so query text and
   * internal details never reach the browser.
   */
  private static AuraHandledException toAuraException(Exception error) {
    if (error instanceof AuraHandledException) {
      return (AuraHandledException) error;
    }
    String message = error instanceof WhaException
      ? error.getMessage()
      : UNEXPECTED_ERROR + ' (' + error.getTypeName() + ').';
    AuraHandledException auraError = new AuraHandledException(message);
    auraError.setMessage(message);
    return auraError;
  }
}
