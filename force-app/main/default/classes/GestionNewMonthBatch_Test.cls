@IsTest
public with sharing class GestionNewMonthBatch_Test {

	@IsTest
	private static void testExecute(){
		// Youpi !
		Date startOfMonth = Date.today().toStartOfMonth();

		Test.startTest();
		Database.executeBatch(new GestionNewMonthBatch());
		Test.stopTest();

		List<User> users = [
			SELECT Id, CJ__c
			FROM User 
			WHERE DAS__c = 'SF' 
			AND IsActive__c = true
			ORDER BY Id ASC
		];
		List<Gestion__c> gestions = [
			SELECT User__c, Date__c, CJ__c, CM__c, BillableDays__c, Key__c
			FROM Gestion__c
			ORDER By User__c ASC
		];
		System.assertEquals(users.size(), gestions.size());
		for(Integer i = 0; i < users.size(); i++){
			System.assertEquals(users.get(i).Id, gestions.get(i).User__c);
			System.assertEquals(users.get(i).CJ__c, gestions.get(i).CJ__c);
			System.assertEquals(startOfMonth, gestions.get(i).Date__c);
			System.assertEquals(startOfMonth.year() + '-' + startOfMonth.month() + '-' + gestions.get(i).User__c, gestions.get(i).Key__c);
		}
	}
}