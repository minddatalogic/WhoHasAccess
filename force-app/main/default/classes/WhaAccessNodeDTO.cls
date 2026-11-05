/**
 * One node of the access tree sent to the whoHasAccess LWC.
 * The field names are the LWC contract: do not rename them.
 */
public class WhaAccessNodeDTO {
  @AuraEnabled
  public String id; // Salesforce Id when the node is a real record
  @AuraEnabled
  public String name;
  @AuraEnabled
  public String type; // one of WhaConstants.NODE_*
  @AuraEnabled
  public String subtitle;
  @AuraEnabled
  public String accessLevel;
  @AuraEnabled
  public Integer count;
  @AuraEnabled
  public Boolean lazy = false; // children are fetched on demand via expandNode
  @AuraEnabled
  public String expandType; // one of WhaConstants.EXPAND_*
  @AuraEnabled
  public String expandId; // may carry a paging cursor, see WhaExpandCursor
  @AuraEnabled
  public List<WhaAccessNodeDTO> children;

  /**
   * @param type One of WhaConstants.NODE_*
   * @param id Salesforce Id, or null for structural nodes
   * @param name Label shown in the tree
   */
  public WhaAccessNodeDTO(String type, String id, String name) {
    this.type = type;
    this.id = id;
    this.name = name;
  }

  /**
   * @param subtitle Second line shown under the name
   * @return This node, for chaining
   */
  public WhaAccessNodeDTO withSubtitle(String subtitle) {
    this.subtitle = subtitle;
    return this;
  }

  /**
   * @param accessLevel Access the node grants, e.g. "Read Only"
   * @return This node, for chaining
   */
  public WhaAccessNodeDTO withAccessLevel(String accessLevel) {
    this.accessLevel = accessLevel;
    return this;
  }

  /**
   * @param count Number shown on the node's badge
   * @return This node, for chaining
   */
  public WhaAccessNodeDTO withCount(Integer count) {
    this.count = count;
    return this;
  }

  /**
   * Marks the node as expandable on demand.
   * @param expandType One of WhaConstants.EXPAND_*
   * @param expandId Id (and optional cursor) passed back to expandNode
   * @return This node, for chaining
   */
  public WhaAccessNodeDTO lazyOn(String expandType, String expandId) {
    this.lazy = true;
    this.expandType = expandType;
    this.expandId = expandId;
    return this;
  }

  /**
   * @param child Node to append
   * @return This node, for chaining
   */
  public WhaAccessNodeDTO add(WhaAccessNodeDTO child) {
    if (this.children == null) {
      this.children = new List<WhaAccessNodeDTO>();
    }
    this.children.add(child);
    return this;
  }

  /**
   * @return True when at least one child has been added
   */
  public Boolean hasChildren() {
    return this.children != null && !this.children.isEmpty();
  }

  /**
   * Appends text to the subtitle, separated by " · ".
   * @param text Text to append
   */
  public void appendSubtitle(String text) {
    this.subtitle = String.isBlank(this.subtitle)
      ? text
      : this.subtitle + ' · ' + text;
  }

  /**
   * Copies the node's identity, subtitle and lazy settings. Children, access
   * level and count are not copied, so the copy can take its own values.
   * @return A new node
   */
  public WhaAccessNodeDTO copy() {
    WhaAccessNodeDTO duplicate = new WhaAccessNodeDTO(
        this.type,
        this.id,
        this.name
      )
      .withSubtitle(this.subtitle);
    duplicate.lazy = this.lazy;
    duplicate.expandType = this.expandType;
    duplicate.expandId = this.expandId;
    return duplicate;
  }
}
