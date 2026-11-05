/**
 * Reads Enterprise Territory Management data (Territory2,
 * UserTerritory2Association). All dynamic SOQL so the class compiles in orgs
 * without territories; every method throws QueryException there.
 *
 * without sharing / SYSTEM_MODE: WhaAccessGuard runs first.
 */
public without sharing class WhaTerritorySelector {
  /**
   * @param territoryId Territory2 Id
   * @return Direct sub-territories (Id, Name), up to MAX_CHILDREN, in name order
   * @throws QueryException when territories are not enabled
   */
  public List<SObject> selectChildren(Id territoryId) {
    return Database.queryWithBinds(
      'SELECT Id, Name FROM Territory2 WHERE ParentTerritory2Id = :territoryId ORDER BY Name LIMIT ' +
      WhaConstants.MAX_CHILDREN,
      new Map<String, Object>{ 'territoryId' => territoryId },
      AccessLevel.SYSTEM_MODE
    );
  }

  /**
   * @param territoryId Territory2 Id
   * @param afterId Last association of the previous page, or null
   * @return Up to WhaConstants.QUERY_LIMIT rows with Id and UserId, by Id
   * @throws QueryException when territories are not enabled
   */
  public List<SObject> selectUserAssociationPage(Id territoryId, Id afterId) {
    Map<String, Object> binds = new Map<String, Object>{
      'territoryId' => territoryId
    };
    String soql = 'SELECT Id, UserId FROM UserTerritory2Association WHERE Territory2Id = :territoryId';
    if (afterId != null) {
      soql += ' AND Id > :afterId';
      binds.put('afterId', afterId);
    }
    soql += ' ORDER BY Id LIMIT ' + WhaConstants.QUERY_LIMIT;
    return Database.queryWithBinds(soql, binds, AccessLevel.SYSTEM_MODE);
  }

  /**
   * @param territoryIds Territory2 Ids
   * @return Name per territory
   * @throws QueryException when territories are not enabled
   */
  public Map<Id, String> selectNames(Set<Id> territoryIds) {
    Map<Id, String> namesById = new Map<Id, String>();
    if (territoryIds == null || territoryIds.isEmpty()) {
      return namesById;
    }
    for (
      SObject territory : Database.queryWithBinds(
        'SELECT Id, Name FROM Territory2 WHERE Id IN :territoryIds',
        new Map<String, Object>{ 'territoryIds' => territoryIds },
        AccessLevel.SYSTEM_MODE
      )
    ) {
      namesById.put(territory.Id, (String) territory.get('Name'));
    }
    return namesById;
  }
}
