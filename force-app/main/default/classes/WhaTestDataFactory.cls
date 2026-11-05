/**
 * Test data for the Who Has Access tests.
 *
 * The standard scenario: role "WHA Top" (manager) above role "WHA Child"
 * (viewer, member); the viewer reports to the manager and holds the
 * Who_Has_Access permission set; group "WHA Test Group" contains the member;
 * account "WHA Test Account" is owned by the viewer.
 */
@IsTest
public class WhaTestDataFactory {
  public static final String VIEWER_ALIAS = 'whaview';
  public static final String MEMBER_ALIAS = 'whamemb';
  public static final String MANAGER_ALIAS = 'whamgr';
  public static final String TOP_ROLE = 'WHA_Top';
  public static final String TOP_ROLE_NAME = 'WHA Top';
  public static final String CHILD_ROLE = 'WHA_Child';
  public static final String CHILD_ROLE_NAME = 'WHA Child';
  public static final String GROUP_NAME = 'WHA Test Group';
  public static final String ACCOUNT_NAME = 'WHA Test Account';
  public static final String VIEWER_PERMISSION_SET = 'Who_Has_Access';
  public static final Integer USERS_IN_CHILD_ROLE = 2;

  /** Creates the standard scenario described in the class header. */
  public static void createAccessScenario() {
    System.runAs(new User(Id = UserInfo.getUserId())) {
      UserRole topRole = createRole(TOP_ROLE_NAME, TOP_ROLE, null);
      UserRole childRole = createRole(CHILD_ROLE_NAME, CHILD_ROLE, topRole.Id);
      Id profileId = profileWithFreeLicences(3);
      User manager = buildUser(MANAGER_ALIAS, profileId, topRole.Id, null);
      insert manager;
      User viewer = buildUser(VIEWER_ALIAS, profileId, childRole.Id, manager.Id);
      User member = buildUser(MEMBER_ALIAS, profileId, childRole.Id, manager.Id);
      insert new List<User>{ viewer, member };
      insert new PermissionSetAssignment(
        AssigneeId = viewer.Id,
        PermissionSetId = getPermissionSet(VIEWER_PERMISSION_SET).Id
      );
      Group testGroup = createGroups(GROUP_NAME, 'Regular', 1, true)[0];
      insert new GroupMember(GroupId = testGroup.Id, UserOrGroupId = member.Id);
    }
    insert new Account(Name = ACCOUNT_NAME, OwnerId = getUser(VIEWER_ALIAS).Id);
  }

  /**
   * @param name Role name
   * @param developerName Role developer name
   * @param parentRoleId Parent role, or null
   * @return The inserted role
   */
  public static UserRole createRole(
    String name,
    String developerName,
    Id parentRoleId
  ) {
    UserRole role = new UserRole(
      Name = name,
      DeveloperName = developerName,
      ParentRoleId = parentRoleId
    );
    insert role;
    return role;
  }

  /**
   * Call inside System.runAs when the test also inserts non-setup records.
   * @param namePrefix Group name; a number is appended when count > 1
   * @param type Group.Type, e.g. Regular or Queue
   * @param count Number of groups
   * @param includeBosses Group.DoesIncludeBosses
   * @return The inserted groups
   */
  public static List<Group> createGroups(
    String namePrefix,
    String type,
    Integer count,
    Boolean includeBosses
  ) {
    List<Group> groups = new List<Group>();
    for (Integer index = 0; index < count; index++) {
      groups.add(
        new Group(
          Name = count == 1 ? namePrefix : namePrefix + ' ' + index,
          Type = type,
          DoesIncludeBosses = includeBosses
        )
      );
    }
    insert groups;
    return groups;
  }

  /**
   * @param groupId Group to add to
   * @param memberIds Users or groups to add
   */
  public static void addMembers(Id groupId, List<Id> memberIds) {
    List<GroupMember> members = new List<GroupMember>();
    for (Id memberId : memberIds) {
      members.add(new GroupMember(GroupId = groupId, UserOrGroupId = memberId));
    }
    insert members;
  }

  /**
   * Manual shares are only allowed when Account's OWD is Private or Read.
   * @param accountId Account to share
   * @param userOrGroupIds Users or groups to share with
   * @param accessLevel Read or Edit
   */
  public static void createManualAccountShares(
    Id accountId,
    List<Id> userOrGroupIds,
    String accessLevel
  ) {
    List<AccountShare> shares = new List<AccountShare>();
    for (Id userOrGroupId : userOrGroupIds) {
      shares.add(
        new AccountShare(
          AccountId = accountId,
          UserOrGroupId = userOrGroupId,
          AccountAccessLevel = accessLevel,
          OpportunityAccessLevel = 'None',
          CaseAccessLevel = 'None'
        )
      );
    }
    insert shares;
  }

  /**
   * @return True when the org's Account OWD allows manual shares
   */
  public static Boolean accountAllowsManualShares() {
    String model = getSharingModel('Account');
    return model == 'Private' || model == 'Read';
  }

  /**
   * Public Read/Write orgs (such as package build orgs) may hold no owner share row.
   * @param accountId Account to check
   * @return True when the account has an Owner row in AccountShare
   */
  public static Boolean accountHasOwnerShare(Id accountId) {
    return ![
      SELECT Id
      FROM AccountShare
      WHERE AccountId = :accountId AND RowCause = 'Owner'
      LIMIT 1
    ]
    .isEmpty();
  }

  /**
   * @param objectName Object API name
   * @return EntityDefinition.InternalSharingModel
   */
  public static String getSharingModel(String objectName) {
    return [
      SELECT InternalSharingModel
      FROM EntityDefinition
      WHERE QualifiedApiName = :objectName
      LIMIT 1
    ]
    .InternalSharingModel;
  }

  /**
   * Builds a well-formed Id that does not exist, for in-memory records.
   * @param sObjectType Type of the Id
   * @param index Number to make it unique
   * @return A fake Id
   */
  public static Id fakeId(Schema.SObjectType sObjectType, Integer index) {
    return (Id) (sObjectType.getDescribe().getKeyPrefix() +
    String.valueOf(index).leftPad(12, '0'));
  }

  public static User getUser(String alias) {
    return [
      SELECT Id, Name, UserRoleId, ManagerId
      FROM User
      WHERE Alias = :alias
      ORDER BY CreatedDate DESC
      LIMIT 1
    ];
  }

  public static Account getAccount() {
    return [SELECT Id, Name, OwnerId FROM Account WHERE Name = :ACCOUNT_NAME LIMIT 1];
  }

  public static Group getGroup(String name) {
    return [SELECT Id, Name, Type FROM Group WHERE Name = :name LIMIT 1];
  }

  public static UserRole getRole(String developerName) {
    return [
      SELECT Id, Name, ParentRoleId
      FROM UserRole
      WHERE DeveloperName = :developerName
      LIMIT 1
    ];
  }

  public static PermissionSet getPermissionSet(String name) {
    return [SELECT Id, Label FROM PermissionSet WHERE Name = :name LIMIT 1];
  }

  /**
   * @param type Group.Type of the role's automatic group
   * @param roleId Role Id
   * @return The automatic group Salesforce keeps for the role
   */
  public static Group getRoleGroup(String type, Id roleId) {
    return [
      SELECT Id, Type
      FROM Group
      WHERE Type = :type AND RelatedId = :roleId
      LIMIT 1
    ];
  }

  /**
   * @param parent Node to search
   * @param namePrefix Start of the child's name
   * @return First child whose name starts with namePrefix, or null
   */
  public static WhaAccessNodeDTO findChild(
    WhaAccessNodeDTO parent,
    String namePrefix
  ) {
    for (WhaAccessNodeDTO child : parent?.children ?? new List<WhaAccessNodeDTO>()) {
      if (child.name != null && child.name.startsWith(namePrefix)) {
        return child;
      }
    }
    return null;
  }

  /**
   * @param nodes Nodes to search
   * @param nodeId Id to look for
   * @return True when a node has that Id
   */
  public static Boolean containsId(List<WhaAccessNodeDTO> nodes, Id nodeId) {
    for (WhaAccessNodeDTO node : nodes) {
      if (node.id == String.valueOf(nodeId)) {
        return true;
      }
    }
    return false;
  }

  /** Demo orgs can run out of Salesforce licences, so fall back to Platform. */
  private static Id profileWithFreeLicences(Integer needed) {
    Map<String, Integer> freeByLicence = new Map<String, Integer>();
    for (UserLicense licence : [
      SELECT Name, TotalLicenses, UsedLicenses
      FROM UserLicense
      WHERE Name IN ('Salesforce', 'Salesforce Platform')
    ]) {
      freeByLicence.put(
        licence.Name,
        licence.TotalLicenses - licence.UsedLicenses
      );
    }
    Integer freeSalesforce = freeByLicence.get('Salesforce') ?? 0;
    Integer freePlatform = freeByLicence.get('Salesforce Platform') ?? 0;
    String profileName = freeSalesforce < needed && freePlatform >= needed
      ? 'Standard Platform User'
      : 'Standard User';
    return [SELECT Id FROM Profile WHERE Name = :profileName LIMIT 1].Id;
  }

  private static User buildUser(
    String alias,
    Id profileId,
    Id roleId,
    Id managerId
  ) {
    String unique = alias + System.currentTimeMillis();
    return new User(
      Alias = alias,
      Email = unique + '@example.com',
      Username = unique + '@wha.example.com',
      LastName = alias,
      ProfileId = profileId,
      UserRoleId = roleId,
      ManagerId = managerId,
      TimeZoneSidKey = 'Asia/Kolkata',
      LocaleSidKey = 'en_US',
      EmailEncodingKey = 'UTF-8',
      LanguageLocaleKey = 'en_US'
    );
  }
}
