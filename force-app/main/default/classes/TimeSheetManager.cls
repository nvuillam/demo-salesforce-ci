public with sharing class TimeSheetManager implements Queueable {

	private List<ProjectLine__c> projectLines;
	private List<TimeSheet__c> timesheets;

	public void execute(QueueableContext context) {
		this.queryUpdatedData();
		this.recalculateCARealise();
		this.processDML();
	}

	public TimeSheetManager(List<ProjectLine__c> projectLines) {
		this.projectLines = projectLines;
		System.debug('this.projectLines : ' + this.projectLines.size());

		this.timesheets = new List<TimeSheet__c>();
	}

	private void queryUpdatedData(){
		this.projectLines = [
			SELECT Id, UnitRate__c, TjmRevise__c, Type__c, (
				SELECT Id, Date__c, DurationTotal__c 
				FROM Timesheets__r 
				ORDER BY Date__c ASC
			)
			FROM ProjectLine__c
			WHERE Id IN :this.projectLines
		];
	}

	/**
	 * @description relaculate CARealise__c field on all associated timesheets
	 */
	private void recalculateCARealise(){
		for(ProjectLine__c projectLine : this.projectLines){
			System.debug('projectLine.Timesheets__r : ' + projectLine.Timesheets__r.size());
			for(TimeSheet__c timesheet : projectLine.Timesheets__r){
				this.recalculateCARealise(projectLine, timesheet); 
			}
		}
	}

	private void recalculateCARealise(ProjectLine__c projectLine, TimeSheet__c timesheet){
		/*if('Regie' == projectLine.Type__c || 'Interne' == projectLine.Type__c){
			timesheet.CARealise__c = timesheet.DurationTotal__c * projectLine.UnitRate__c;
			this.timesheets.add(timesheet);
		} else */if('Forfait' == projectLine.Type__c){
			timesheet.CARealise__c = timesheet.DurationTotal__c * projectLine.TjmRevise__c;
			this.timesheets.add(timesheet);
		}
	}

	private void processDML(){
		System.debug('this.timesheets : ' + this.timesheets.size());
		Database.update(this.timesheets, false);
	}
}