/**
 * Created by DHU on 30/07/2018.
 */

public with sharing class TimeSheetHandler implements ITrigger {



    public static Map<Id,ProjectLine__c>ProjectLinesByIds;
    public static Map<Id,User>UserByIds;

	private static Map<String, Id> gestionIdsByKey = new Map<String, Id>();


    public void bulkBefore() {
        Set<Id> concernedProjectLines = new Set<Id>();
        Set<Id> relatedUser = new Set<Id>();

		if(Trigger.isInsert || Trigger.isUpdate){
            for (TimeSheet__c t : (TimeSheet__c[]) trigger.new) {
                if (!concernedProjectLines.contains(t.projectLine__c))
                    concernedProjectLines.add(t.projectLine__c);
                if( !relatedUser.contains(t.User__c))
                    relatedUser.add(t.User__c);
					
				gestionIdsByKey.put(formatGestionKey(t), null);
			}

			// récupération des enregistrements Gestion__c nécessaires
			for(Gestion__c gestion : [
				SELECT Id, Key__c
				FROM Gestion__c
				WHERE Key__c IN: gestionIdsByKey.keySet()
			]){
				gestionIdsByKey.put(gestion.Key__c, gestion.Id);
			}
        }

        ProjectLinesByIds = new Map<Id,ProjectLine__c>( [ SELECT Id,Type__c, typeActivite__c, SectionAnalytique__c, Project__c  FROM ProjectLine__c WHERE Id in : concernedProjectLines ] );
        UserByIds = new Map<Id, User>([SELECT id, SectionAnalytique__c FROM User WHERE Id in : relatedUser]);
    }

    public void bulkAfter() {
    }

    public void beforeInsert(SObject so) {
        beforeInsertUpdate(null, (TimeSheet__c) so);
    }

    public void beforeUpdate(SObject oldSo, SObject so) {
        beforeInsertUpdate((TimeSheet__c) oldSo, (TimeSheet__c) so);
    }

    public void beforeDelete(SObject so) {
    }

    public void afterInsert(SObject so) {
        TimeSheet__c t = (TimeSheet__c) so;
        if ( t.Date__c < Date.Today().ToStartOfMonth() && t.BusinessAnalytic__c == null )
            BusinessAnalyticsQueue.addItem(t);
    }

    public void afterUpdate(SObject oldSo, SObject so) {
        TimeSheet__c t = (TimeSheet__c) so;
        if ( t.Date__c < Date.Today().ToStartOfMonth() && t.BusinessAnalytic__c == null )
            BusinessAnalyticsQueue.addItem(t);
    }

    public void afterDelete(SObject so) {
        TimeSheet__c t = (TimeSheet__c) so;
        if ( t.Date__c < Date.Today().ToStartOfMonth() && t.BusinessAnalytic__c == null )
            BusinessAnalyticsQueue.addItem(t);
    }

    public void andFinally() {
        if(Trigger.isAfter){
            BusinessAnalyticsQueue.processRefreshBAPrevMonths();
		}
    }

    public static void beforeInsertUpdate(TimeSheet__c oldSheet, TimeSheet__c newSheet){
        if(newSheet.projectLine__c != null) {
            ProjectLine__c l = ProjectLinesByIds.get(newSheet.ProjectLine__c);

            if( TriggerFactory.isChanged('projectLine__c', oldSheet,newSheet) || newSheet.SectionAnalytiqueLigne__c == null || newSheet.SectionAnalytiqueUser__c == null || newSheet.Project__c == null) {
                newSheet.TypeActivite__c = l.typeActivite__c;
                newSheet.SectionAnalytiqueLigne__c = ProjectLinesByIds.get(newSheet.ProjectLine__c).SectionAnalytique__c;
                newSheet.SectionAnalytiqueUser__c = UserByIds.get(newSheet.User__c).SectionAnalytique__c;
                newSheet.Project__c =  ProjectLinesByIds.get(newSheet.ProjectLine__c).Project__c;
            }
        }

		// assignation de l'enregistrement de gestion (init et changements importants)
		if(newSheet.Gestion__c == null || TriggerFactory.isChanged('User__c,Date__c', oldSheet, newSheet)){
			assignGestion(newSheet);
		}
	}

	private static void assignGestion(TimeSheet__c timesheet){
		String key = formatGestionKey(timesheet);
		
		// association si l'enregistrement Gestion__c est disponible
		if(gestionIdsByKey.containsKey(key)){
			timesheet.Gestion__c = gestionIdsByKey.get(key);
		}
	}

	private static String formatGestionKey(TimeSheet__c timesheet){
		// void Gestion__c.Key__c
		return timesheet.Date__c.year() + '-' + timesheet.Date__c.month() + '-' + timesheet.User__c;
	}

}