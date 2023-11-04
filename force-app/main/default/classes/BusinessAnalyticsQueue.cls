/**
 * Created by DHU on 28/11/2018.
 */

public with sharing class BusinessAnalyticsQueue implements Queueable {

    private Set<Id> ProjectLinesIds;

    private Date WorkDate;

    private static set<Id> addedProjectLinesId;

    private static Map<Id,Date> LinesWithPrevBaToUpdate;

    private static Boolean preventLineTrigger;


    static{
        addedProjectLinesId = new set<Id>();
        preventLineTrigger = false;
        LinesWithPrevBaToUpdate = new Map<Id, Date>();
    }

    public BusinessAnalyticsQueue(Set<Id> plIds, Date wd){

        this.ProjectLinesIds = plIds;
        this.WorkDate = wd == null ? Date.Today(): wd;
    }


    public void execute(QueueableContext param1) {
        system.debug('###IN BusinessAnalyticsQueue.execute with');
        system.debug('ProjectLine '+ ProjectLinesIds);
        system.debug('WorkDate '+ workdate);
        recomputeAndApplyNext(ProjectLinesIds,workDate,false); //On ne ferme pas les mois suivants
    }

    public static void recomputeAndApplyNext(Set<Id> lids, Date wd, boolean doClose){
        system.debug('Execute BA Queue');

        List<Id> projectsLinesToRefresh = new List<Id>();
        projectsLinesToRefresh.addAll(lids);
        Map<String, BusinessAnalyticsManager> bas = BusinessAnalyticsManager.init(projectsLinesToRefresh,wd);
        BusinessAnalytic__c[] toUp = new BusinessAnalytic__c[]{};
        List<TimeSheet__c> tsToUp = new List<TimeSheet__c>();
        system.debug('businessAnalytics to upsert');
        system.debug(bas.values());
        for(BusinessAnalyticsManager ba : bas.values()) {
            if(doClose)
                ba.calculatedBa.Verrouille__c = true;
            toUp.add(ba.calculatedBa);
            tsToUp.addAll(ba.updateTimesheets());
        }
        database.upsert(toUp, BusinessAnalytic__c.externalId__c);
        database.update(tsToUp);
        // On répercute sur les mois suivants.
        if(wd.toStartOfMonth() < Date.today().toStartOfMonth()){
            BusinessAnalyticsQueue nextMonth = new BusinessAnalyticsQueue(lids,wd.toStartOfMonth().addMonths(1));
            if(!test.isRunningTest())
                System.enqueueJob(nextMonth);
        }
    }

    public static void addItem( TimeSheet__c t ){
        System.debug('Adding OldTimesheet');
        preventLineTrigger = true;
        if( t.Date__c < Date.today().toStartOfMonth() && ( !LinesWithPrevBaToUpdate.containsKey(t.ProjectLine__c) || LinesWithPrevBaToUpdate.get(t.ProjectLine__c) > t.Date__c ) ){
            LinesWithPrevBaToUpdate.put(t.ProjectLine__c,t.Date__c.toStartOfMonth());
        }
    }

    //public static void addItem( LigneFacture__c l )

    public static void addItem(ProjectLine__c pl){
        if(!preventLineTrigger) {
            if ( /*pl.Type__c == 'Régie plafonnée' || */ pl.Type__c == 'Forfait' && !addedProjectLinesId.contains(pl.id)) {
                addedProjectLinesId.add(pl.CalculDeTFNR__c == 'Par Projet' ? pl.Project__c : pl.id);
            }
        }
    }

    public static void processRefreshBAPrevMonths(){
        System.debug('IN processRefreshBAPrevMonths');
        Map<Id,Date> relatedProject = new Map<Id,Date>();
        if(!LinesWithPrevBaToUpdate.isEmpty()) {
            for (ProjectLine__c l : [SELECT id, Name,CalculDeTFNR__c, Project__c, (SELECT id, Date__c, Verrouille__c FROM BusinessAnalytics__r WHERE Verrouille__c = false ORDER BY Date__c ASC) FROM ProjectLine__c WHERE Id in :LinesWithPrevBaToUpdate.keySet() AND Type__c IN ('Forfait' /*, 'Régie Plafonnée' */ )]) {
                if (l.CalculDeTFNR__c == 'Par Projet') {
                    if (!relatedProject.containsKey(l.Project__c) || LinesWithPrevBaToUpdate.get(l.Id) < relatedProject.get(l.Project__c))
                        relatedProject.put(l.Project__c, LinesWithPrevBaToUpdate.get(l.Id));
                } else {
                    enqueueLineCompute(l.id, l.BusinessAnalytics__r, LinesWithPrevBaToUpdate.get(l.Id));
                }
            }
            for (Project__c p : [SELECT Id, CalculDeTFNR__c, (SELECT id, Date__c, Verrouille__c FROM BusinessAnalytics__r WHERE Verrouille__c = false ORDER BY Date__c ASC) FROM Project__c WHERE Id IN :relatedProject.keySet()]) {
                enqueueLineCompute(p.id, p.BusinessAnalytics__r, relatedProject.get(p.Id));
            }
        }else{
            system.debug('LinesWithPrevBaToUpdate is Empty => nothing to do');
        }
        System.debug('OUT processRefreshBAPrevMonths');
    }

    private static void enqueueLineCompute( Id entityId, BusinessAnalytic__c[] relatedAnalytic, Date startWorkDate){ //RelatedAnalytic classé par ordre croissant
        System.debug('IN enqueueLineCompute startWorkDate ' + startWorkDate);
        Date WorkDate = startWorkDate.toStartOfMonth();
        for(BusinessAnalytic__c ba : relatedAnalytic){
            if( ba.Date__c >= startWorkDate ){
                system.debug( 'Recomputing from '+ba.Date__c );
                WorkDate = ba.Date__c;
                break;
            }
        }
        if(!system.isQueueable()) {
            BusinessAnalyticsQueue job = new BusinessAnalyticsQueue(new Set<Id>{
                    entityId
            }, WorkDate);
            System.enqueueJob(job); //Attention job added to the queue
            System.debug('OUT enqueueLineCompute');
        }
    }

    public static void processRefreshBA(Date wd){
        if(wd == null)
            wd = Date.today();
        if(!addedProjectLinesId.isEmpty()) {
            BusinessAnalyticsQueue instance = new BusinessAnalyticsQueue( addedProjectLinesId, wd );
            System.enqueueJob(instance);
            addedProjectLinesId = new Set<Id>();
        }
    }



}