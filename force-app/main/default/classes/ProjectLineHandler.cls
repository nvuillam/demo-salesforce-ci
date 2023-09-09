/**
 * Created by Didier Huguet on 08/11/2018.
 */

public with sharing class ProjectLineHandler implements ITrigger{

    static User currentUser;

    private static Map<Id,List<ProjectLine__c>> ProjectLinesToCheckExtId;
    private static Set<Id> ProjectToRetrieve;
    private static Map<Id, Id> newProjectIdsByLineIds = new Map<Id, Id>();

    static {
        CurrentUser = [SELECT Id, SectionAnalytique__c FROM User WHERE Id=:userInfo.getUserId()];
        ProjectLinesToCheckExtId = new Map<Id, List<ProjectLine__c>>();
        ProjectToRetrieve = new Set<Id>();
    }

    public void bulkBefore() {
    }

    public void bulkAfter() {
    }

    public void beforeInsert(SObject so) {
        ProjectLine__c l = (ProjectLine__c) so;
        if(l.SectionAnalytique__c == null)
            l.SectionAnalytique__c = CurrentUser.SectionAnalytique__c;
        if(l.NumeroDeLigne__c != null && l.NumeroDeLigne__c != 0 && l.ExternalId__c == null && !l.DoNotImportWebSiCra__c ){
            if(!ProjectLinesToCheckExtId.containsKey(l.Project__c))
                ProjectLinesToCheckExtId.put(l.Project__c, new List<ProjectLine__c>());
            ProjectLinesToCheckExtId.get( l.Project__c).Add( l );
        }
    }

    public void beforeUpdate(SObject oldSo, SObject so) {
        ProjectLine__c l = (ProjectLine__c) so;
        if(l.SectionAnalytique__c == null)
            l.SectionAnalytique__c = CurrentUser.SectionAnalytique__c;
        if(l.NumeroDeLigne__c != null && l.NumeroDeLigne__c != 0 && l.ExternalId__c == null && !l.DoNotImportWebSiCra__c ) {
            if(!ProjectLinesToCheckExtId.containsKey(l.Project__c))
                ProjectLinesToCheckExtId.put(l.Project__c, new List<ProjectLine__c>());
            ProjectLinesToCheckExtId.get( l.Project__c).Add( l );
        }
    }

    public void beforeDelete(SObject so) {
    }

    public void afterInsert(SObject so) {
    }

    public void afterUpdate(SObject oldSo, SObject so) {
        //refresh des BA après un update de ligne
        Set<String> typeToCheck = new Set<String> {'Régie plafonnée','Forfait'};
        if(typeToCheck.contains( ( (String) so.get('Type__c') )+ '')  && TriggerFactory.isChanged('WorkedQuantity__c,SoldAmount__c,RevisedQuantity__c,InvoicedAmount__c', oldSo,so)){
            TimeSheetQueue.addProjectLine((ProjectLine__c)so);
            BusinessAnalyticsQueue.addItem((ProjectLine__c)so);
        }

		if(TriggerFactory.isChanged('Project__c', oldSo,so)){
			newProjectIdsByLineIds.put(so.Id, (Id) so.get('Project__c'));
		}
    }

    public void afterDelete(SObject so) {
    }

    public void andFinally() { 
		TimeSheetQueue.process();
		//On recalcule toujours le mois précédent et le mois en cours, on est couvert avec le champ Vérouillé si jamais c'est une ts qui a changé
        BusinessAnalyticsQueue.processRefreshBA(Date.today().addMonths(-1));

        if(trigger.isBefore && ProjectToRetrieve != null){
            set<String> ExtIdToAffect = new Set<String>();
            set<String> ExistingExtId = new Set<String>();
            for( Project__c p : [SELECT Id, CodeProjetWebSI__c FROM Project__c WHERE Id in : ProjectLinesToCheckExtId.keySet() AND CodeProjetWebSI__c != null] ){
                for(ProjectLine__c pl : ProjectLinesToCheckExtId.get(p.Id)){
                    pl.ExternalId__c = p.CodeProjetWebSI__c.left(6)+'/'+pl.NumeroDeLigne__c;
                    pl.DoNotImportWebSiCra__c = false;
                    ExtIdToAffect.add( p.CodeProjetWebSI__c.left(6)+'/'+pl.NumeroDeLigne__c );
                }
            }
            for(ProjectLine__c pl : [SELECT Id, ExternalId__c FROM ProjectLine__c WHERE ExternalId__c in : ExtIdToAffect]){
                ExistingExtId.add( pl.ExternalId__c );
            }
            Set<String> affectedExtId = new Set<String>();
            for(Id pid : ProjectLinesToCheckExtId.keySet()){
                for(ProjectLine__c pl : ProjectLinesToCheckExtId.get(pid)){
                    if( affectedExtId.contains( pl.ExternalId__c ) || ExistingExtId.contains( pl.ExternalId__c )){
                        pl.ExternalId__c = null;
                        pl.DoNotImportWebSiCra__c = true;
                    } else {
                        affectedExtId.add( pl.ExternalId__c );
                    }
                }
            }
        }

		if(newProjectIdsByLineIds.size() > 0){
			updateProjectOfProjectMembers();
		}
    }

	/**
	 * Update project on project members to track project line changes
	 */
	private static void updateProjectOfProjectMembers(){
		List<ProjectMember__c> projectMembers = new List<ProjectMember__c>();

		for(ProjectMember__c pm : [
			SELECT Id, ProjectLine__c
			FROM ProjectMember__c
			WHERE ProjectLine__c IN :newProjectIdsByLineIds.keySet()
		]){
			projectMembers.add(pm);
			pm.Project__c = newProjectIdsByLineIds.get(pm.ProjectLine__c);
		}

		update projectMembers;
	}
}