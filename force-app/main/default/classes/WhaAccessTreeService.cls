/**
 * Builds the first two levels of the access tree for one record, following
 * the "Who has access" design board:
 *   1. Org-wide default (public -> profiles / permission sets with Read;
 *      controlled by parent -> the parent records)
 *   2. Object permission bypass (View All, Modify All, View / Modify All Data)
 *   3. Record sharing, by RowCause (skipped when controlled by parent)
 *   4. Role hierarchy above the owner
 */
public with sharing class WhaAccessTreeService {
  private final WhaAccessContext context;
  private final WhaRecordSelector recordSelector = new WhaRecordSelector();
  private final WhaPermissionService permissionService;
  private final WhaShareService shareService;
  private final WhaRoleService roleService = new WhaRoleService();

  /**
   * @param context Analysed record
   */
  public WhaAccessTreeService(WhaAccessContext context) {
    this.context = context;
    this.permissionService = new WhaPermissionService(context);
    this.shareService = new WhaShareService(context);
  }

  /**
   * @return Root RECORD node with the four branches
   */
  public WhaAccessNodeDTO buildTree() {
    SObject record = recordSelector.selectRecord(context);
    EntityDefinition sharingModel = recordSelector.selectSharingModel(
      context.objectName
    );
    String internalModel = sharingModel?.InternalSharingModel;
    String externalModel = sharingModel?.ExternalSharingModel;

    WhaAccessNodeDTO root = new WhaAccessNodeDTO(
        WhaConstants.NODE_RECORD,
        context.recordId,
        context.getRecordName(record)
      )
      .withSubtitle(
        context.objectLabel +
          ' · Internal OWD: ' +
          WhaLabelUtil.sharingModelLabel(internalModel) +
          ' · External OWD: ' +
          WhaLabelUtil.sharingModelLabel(externalModel)
      );
    root.add(buildOrgWideDefaultBranch(record, internalModel));
    root.add(permissionService.buildBypassBranch());
    if (!isControlledByParent(internalModel)) {
      root.add(shareService.buildShareBranch());
    }
    if (context.hasOwnerField()) {
      root.add(
        roleService.buildHierarchyAboveOwner((Id) record.get('OwnerId'))
      );
    }
    return root;
  }

  private WhaAccessNodeDTO buildOrgWideDefaultBranch(
    SObject record,
    String internalModel
  ) {
    Boolean publicRead = internalModel == 'Read';
    Boolean publicWrite = isPublicReadWrite(internalModel);
    WhaAccessNodeDTO branch = WhaNodeFactory.category(
        'Org-Wide Default: ' + WhaLabelUtil.sharingModelLabel(internalModel)
      )
      .withAccessLevel(publicWrite ? 'Read/Write' : publicRead ? 'Read' : null);
    if (publicRead || publicWrite) {
      branch.withSubtitle(
        'Every user whose Profile / Permission Set grants Read on ' +
        context.objectLabel
      );
      permissionService.addContainerNodes(
        branch,
        permissionService.buildObjectReadContainers(publicWrite)
      );
    } else if (isControlledByParent(internalModel)) {
      branch.withSubtitle(
        'Access is inherited from the parent record — analyse the parent'
      );
      for (WhaAccessNodeDTO parentNode : buildParentNodes(record)) {
        branch.add(parentNode);
      }
    } else {
      branch.withSubtitle('Private — access must be granted by sharing below');
    }
    return branch;
  }

  /**
   * @param record Analysed record, with its parent lookup fields queried
   * @return One PARENT node per filled parent lookup, or an INFO node
   */
  @TestVisible
  private List<WhaAccessNodeDTO> buildParentNodes(SObject record) {
    List<WhaAccessNodeDTO> nodes = new List<WhaAccessNodeDTO>();
    for (String fieldName : context.getParentFieldNames()) {
      Id parentId = (Id) record.get(fieldName);
      if (parentId == null) {
        continue;
      }
      String parentLabel = parentId.getSObjectType().getDescribe().getLabel();
      nodes.add(
        new WhaAccessNodeDTO(
            WhaConstants.NODE_PARENT,
            parentId,
            parentLabel + ' (' + fieldName + ')'
          )
          .withSubtitle('Click to analyse who has access to the parent')
      );
    }
    if (nodes.isEmpty()) {
      nodes.add(WhaNodeFactory.info('No parent record found on this record'));
    }
    return nodes;
  }

  private static Boolean isPublicReadWrite(String model) {
    return model != null &&
      (model.startsWith('ReadWrite') || model == 'FullAccess');
  }

  private static Boolean isControlledByParent(String model) {
    return model != null && model.startsWith('ControlledBy');
  }
}
