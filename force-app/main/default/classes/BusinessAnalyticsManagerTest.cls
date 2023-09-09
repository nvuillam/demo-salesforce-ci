@isTest
public class BusinessAnalyticsManagerTest {
 	static Account oAccount;
    
    static Asset oAsset;
    
    static AffectationActif__c[] oAffActif;
    
    static Project__c oProject;
    
    static TimeSheet__c  oTimeSheets;
    
    static {

        oAccount = new Account (Name = 'TestAccount');
        insert oAccount;
        /*oAsset = new Asset(Name = 'testAsset', AccountId = oAccount.id, Price = 1500, Quantity = 3.5,PurchaseDate = date.today().toStartOfMonth());
        insert oAsset;
        */
        Contract cont = new Contract(AccountId = oAccount.id);
        insert cont;
        oProject = new Project__c(Name = 'test Project', Account__c = oAccount.id, Contract__c = cont.id,type__c='Forfait', IsActive__c = true);
        insert oProject;
        ProjectLine__c pl = new ProjectLine__c(Project__c = oProject.Id, Name='testPL',Active__c = true, type__c='Forfait');
        insert pl;
        oAffActif = new AffectationActif__c[] { new AffectationActif__c( project__c = oProject.id, Date__c = Date.today().toStartOfMonth(), NbJours__c = 3.5, Montant__c = 1500 ) };
        insert oAffActif;
        /*Contract c = new Contract(AccountId = oAccount.id);
        insert c;*/
        id rtid = [SELECt id from recordType where developerName = 'Facture_validee'].id;
        PreFacture__c f = new PreFacture__c(montant_ht__c = 1000, project__c = oProject.id,Date_emission__c = date.today().toStartOfMonth()/*,  Contrat__c = c.id*/, recordTypeid = rtid, non_comprise_dans_le_ca__c = false );
        insert f;
        TimeSheet__c[] ts = new TimeSheet__c[]{ new TimeSheet__c(Duration__c = 1, Project__c = oProject.id, Date__c = date.today(), User__c = userInfo.getUserId(), type__c = 'Technical', description__c='test'),
                                                new TimeSheet__c( Duration__c = 1, Project__c = oProject.id, Date__c = date.today().addDays(1), User__c = userInfo.getUserId(), type__c = 'Functional', description__c='test' )
                                                };
        insert ts;
        BusinessAnalytic__c[] bas = new BusinessAnalytic__c[]{
            BusinessAnalyticsManager.createEmptyBA(date.today().toStartOfMonth(),pl),
            BusinessAnalyticsManager.createEmptyBA(date.today().addMonths(-1).toStartOfMonth(), pl)

        };
        insert bas;
    }
    /*
    static testMethod void testProjectforfait(){
        test.startTest();
        
        ApexPages.StandardController sc = new ApexPages.StandardController(oProject);

        BusinessAnalyticsController ctrl = new BusinessAnalyticsController(sc);
        for(BusinessanalyticsManager b : ctrl.ProjectBusinessAnalyticsManagers.values())
            b.selected = true;
        ctrl.getSortedBas();
        ctrl.saveRAF();
        ctrl.saveBa();
        ctrl.getMonthsSelectOption();

    }*/
}