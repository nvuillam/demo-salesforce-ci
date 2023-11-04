@isTest
private class TimeSheetQuickCreateCtrl_Test {

	private static testMethod void testTimeSheetQuickCreateCtrl() {
		
		Account acc = new Account(Name = 'Synefo');
		insert acc;
		
		Project__c project = new Project__c(Account__c = acc.Id, Name = 'TimeSheet', ProjectTeam__c = UserInfo.getName(), IsActive__c = true, RequireTimeSheetDescription__c = false);
		insert project;

		ProjectLine__c pl = new ProjectLine__c(Project__c = project.id, Name='Test',NumeroDeLigne__c=1, Type__c='Régie');
		insert pl;

		projectMember__c pm = new ProjectMember__c(Project__c=project.id, ProjectLine__c = pl.id, User__c = userInfo.getUserId());
		insert pm;

		Test.startTest();
		TimeSheetQuickCreateCtrl ctrl = new TimeSheetQuickCreateCtrl();
		
		
		system.assertEquals(5, ctrl.last5days.size());
		system.assertEquals(5, ctrl.durationsByDates.size());
		system.assertEquals(5, ctrl.dayNamesByDates.size());
		
		ctrl.timeSheet.Project__c = project.Id;
		ctrl.timeSheet.ProjectLine__c = pl.id;

		ctrl.saveTimeSheet();
		ctrl.prevWeek();
		ctrl.nextWeek();
		ctrl.curWeek();
		
		system.assertEquals(1, ctrl.durationsByDates.get(ctrl.last5days[ctrl.last5days.size() - 1]));
		Test.stopTest();
	}

}