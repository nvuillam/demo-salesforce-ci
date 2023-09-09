public with sharing class TimeSheetQueue {

	private static List<ProjectLine__c> projectLines = new List<ProjectLine__c>();

	public static void addProjectLine(ProjectLine__c projectLine){
		projectLines.add(projectLine);
	}

	public static void process(){
		if(!System.isQueueable()) {
			System.enqueueJob(new TimeSheetManager(projectLines));
		}
	}
}