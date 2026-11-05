/**
 * Territory-based access (Territory and TerritoryAndSubordinates groups).
 * Works in orgs without Enterprise Territory Management: queries fail there,
 * and the tree shows a note instead.
 */
public with sharing class WhaTerritoryService {
  private final WhaTerritorySelector territorySelector = new WhaTerritorySelector();
  private final WhaUserSelector userSelector = new WhaUserSelector();

  /**
   * @param territoryId Territory2 Id
   * @param withSubTerritories True to list sub-territories first
   * @param afterId Last association of the previous page, or null
   * @return Sub-territory and user nodes, or a note when territories are off
   */
  public List<WhaAccessNodeDTO> expandTerritoryUsers(
    Id territoryId,
    Boolean withSubTerritories,
    Id afterId
  ) {
    List<WhaAccessNodeDTO> nodes = new List<WhaAccessNodeDTO>();
    try {
      if (withSubTerritories && afterId == null) {
        nodes.addAll(buildSubTerritoryNodes(territoryId));
      }
      nodes.addAll(buildUserPage(territoryId, withSubTerritories, afterId));
    } catch (QueryException e) {
      nodes.add(
        WhaNodeFactory.info('Territory data unavailable: ' + e.getMessage())
      );
    }
    if (nodes.isEmpty()) {
      nodes.add(WhaNodeFactory.info('No users in this territory'));
    }
    return nodes;
  }

  /**
   * @param territoryIds Territory2 Ids
   * @return Name per territory; empty when territories are not enabled
   */
  public Map<Id, String> getTerritoryNames(Set<Id> territoryIds) {
    try {
      return territorySelector.selectNames(territoryIds);
    } catch (QueryException e) {
      return new Map<Id, String>(); // territories not enabled: names stay blank
    }
  }

  private List<WhaAccessNodeDTO> buildSubTerritoryNodes(Id territoryId) {
    List<WhaAccessNodeDTO> nodes = new List<WhaAccessNodeDTO>();
    for (SObject territory : territorySelector.selectChildren(territoryId)) {
      nodes.add(
        new WhaAccessNodeDTO(
            WhaConstants.NODE_GROUP,
            territory.Id,
            'Territory: ' + territory.get('Name')
          )
          .withSubtitle('Sub-territory')
          .lazyOn(WhaConstants.EXPAND_TERRITORY_SUB, territory.Id)
      );
    }
    return nodes;
  }

  private List<WhaAccessNodeDTO> buildUserPage(
    Id territoryId,
    Boolean withSubTerritories,
    Id afterId
  ) {
    List<SObject> page = territorySelector.selectUserAssociationPage(
      territoryId,
      afterId
    );
    Id lastRowId = WhaExpandCursor.trimToPage(page);
    Set<Id> userIds = new Set<Id>();
    for (SObject association : page) {
      userIds.add((Id) association.get('UserId'));
    }
    List<WhaAccessNodeDTO> nodes = WhaNodeFactory.userNodes(
      userSelector.selectByIds(userIds).values()
    );
    if (lastRowId != null) {
      String pageExpandType = withSubTerritories
        ? WhaConstants.EXPAND_TERRITORY_SUB
        : WhaConstants.EXPAND_TERRITORY;
      nodes.add(WhaNodeFactory.more(pageExpandType, territoryId, lastRowId));
    }
    return nodes;
  }
}
