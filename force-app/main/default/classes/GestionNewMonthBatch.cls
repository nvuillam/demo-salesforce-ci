public without sharing class GestionNewMonthBatch implements Database.Batchable<SObject>, Schedulable {

	public Date refDate;

	@TestVisible
	private GestionNewMonthBatch(){
		this(Date.today().year(), Date.today().month());
	}

	public GestionNewMonthBatch(Integer year, Integer month){
		this.refDate = Date.newInstance(year, month, 1);
	}

	public void execute(SchedulableContext SC) {
		Database.executeBatch(new GestionNewMonthBatch());
	}

	public Database.QueryLocator start(Database.BatchableContext BC) {
		return Database.getQueryLocator([
			SELECT Id 
			FROM User 
			WHERE DAS__c = 'SF' 
			AND IsActive = true
		]);
	}

	public void execute(Database.BatchableContext BC, List<User> users) {
		List<Gestion__c> gestions = new List<Gestion__c>();

		for (User user : users) {
			gestions.add(new Gestion__c(
				User__c = user.Id,
				Date__c = refDate
			));
		}

		insert gestions;
	}

	public void finish(Database.BatchableContext BC) {
	}
}