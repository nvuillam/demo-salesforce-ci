@IsTest
public with sharing class ProjectLineHandlerTest {
	
	@IsTest
	private static void testUpdateProjectAfterProjectMemberCreation(){
		Account acc = new Account(Name = 'Synefo');
		insert acc;

        update new User(Id = userInfo.getUserId(),SectionAnalytique__c='SCRM92S' );

		List<Project__c> projects = new List<Project__c>();
		projects.add(new Project__c(SectionAnalytique__c='SCRM92S',Account__c = acc.Id, Name = 'TimeSheet', ProjectTeam__c = UserInfo.getName(), IsActive__c = true, RequireTimeSheetDescription__c = true));
		projects.add(new Project__c(SectionAnalytique__c='SCRM92S',Account__c = acc.Id, Name = 'TimeSheet 2', ProjectTeam__c = UserInfo.getName(), IsActive__c = true, RequireTimeSheetDescription__c = true));
		insert projects;

		ProjectLine__c pl = new ProjectLine__c(SectionAnalytique__c='SCRM92S',type__c = 'Forfait', InitialQuantity__c = 100, RevisedQuantity__c = 100, Name = 'TestLines', Active__c=true, NumeroDeLigne__c=1, Project__c = projects.get(0).Id);
		insert pl;

		ProjectMember__c pm = new ProjectMember__c(ProjectLine__c = pl.id, Project__c = projects.get(0).id, User__c = userInfo.getUserId());
		insert pm;

		AffectationActif__c aa = new AffectationActif__c(NbJours__c = 100, Montant__c = 10000, Date__c = Date.today(), Name='testAffectation Actif', Project__c=projects.get(0).Id, ProjectLine__c=pl.Id);
		insert aa;

        //On insere l'activation setting pour déclencher des business analytique
        ActivationSettings__c s = new ActivationSettings__c(TimeSheet_TR__c=true, ProjectLine_TR__c = true);
        insert s;

		Test.startTest();
		pl.Project__c = projects.get(1).Id;
		update pl;
		Test.stopTest();

		System.assertEquals(projects.get(1).Id, [SELECT Id, Project__c FROM ProjectMember__c WHERE Id =: pm.Id].Project__c);
	}
}