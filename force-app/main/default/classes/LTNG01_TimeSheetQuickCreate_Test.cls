@isTest
private class LTNG01_TimeSheetQuickCreate_Test {

	private static testMethod void testLTNG01_TimeSheetQuickCreate() {
		
		Account acc = new Account(Name = 'Synefo');
		insert acc;

        update new User(Id = userInfo.getUserId(),SectionAnalytique__c='SCRM92S' );

		Project__c project = new Project__c(SectionAnalytique__c='SCRM92S',Account__c = acc.Id, Name = 'TimeSheet', ProjectTeam__c = UserInfo.getName(), IsActive__c = true, RequireTimeSheetDescription__c = true);
		insert project;

		ProjectLine__c pl = new ProjectLine__c(SectionAnalytique__c='SCRM92S',type__c = 'Forfait', InitialQuantity__c = 100, RevisedQuantity__c = 100, Name = 'TestLines', Active__c=true, NumeroDeLigne__c=1, Project__c = project.Id);
		insert pl;

		ProjectMember__c pm = new ProjectMember__c(ProjectLine__c = pl.id, Project__c = project.id, User__c = userInfo.getUserId());
		insert pm;

		AffectationActif__c aa = new AffectationActif__c(NbJours__c = 100, Montant__c = 10000, Date__c = Date.today(), Name='testAffectation Actif', Project__c=project.Id, ProjectLine__c=pl.Id);
		insert aa;

        //On insere l'activation setting pour déclencher des business analytique
        ActivationSettings__c s = new ActivationSettings__c(TimeSheet_TR__c=true, ProjectLine_TR__c = true);
        insert s;

		Test.startTest();
		LTNG01_TimeSheetQuickCreate.getInitParams(String.valueOf(date.today().toStartOfMonth().addDays(-1)));
		LTNG01_TimeSheetQuickCreate.saveTS(1, 'Training',String.valueOf(date.today().toStartOfMonth().addDays(-1)), 'desc', project.Id,pl.id,pm.id, new TimeSheet__c(Phase__c = 'Cadrage'));
		LTNG01_TimeSheetQuickCreate.saveTS(1, 'Training', String.valueOf(date.today()), 'desc', project.Id,pl.id,pm.id, new TimeSheet__c());
		
		Test.stopTest();
	}

}