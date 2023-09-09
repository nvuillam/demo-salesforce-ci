@isTest
public class ProjectRegieManagerCtrlTest {
    static Account oAccount;
    
    static Asset oAsset;
    
    static AffectationActif__c[] oAffActif;
    
    static Project__c oProject;
    static ProjectLine__c oProjectLine;

    static TimeSheet__c  oTimeSheets;
    
    static {
        ActivationSettings__c ac = new ActivationSettings__c();
        ac.PreFactureTR__c = true;
        ac.SetupOwnerId = UserInfo.getOrganizationId();
        insert ac;
        oAccount = new Account (Name = 'TestAccount');
        insert oAccount;
       /* oAsset = new Asset(Name = 'testAsset', AccountId = oAccount.id, Price = 1500, Quantity = 1.5);
        insert oAsset;*/
        

        oProject = new Project__c(Name = 'test Project', Account__c = oAccount.id);
        insert oProject;

        oProjectLine = new ProjectLine__c(SectionAnalytique__c='SCRM92S',type__c = 'Régie', InitialQuantity__c = 100, RevisedQuantity__c = 100, UnitRate__c=750, Name = 'TestLines', Active__c=true, NumeroDeLigne__c=1, Project__c = oProject.Id);
        insert oProjectLine;

        oAffActif = new AffectationActif__c[] { new AffectationActif__c( ProjectLine__c = oProjectLine.id,project__c = oProject.id, Date__c = Date.today().toStartOfMonth(), NbJours__c = 1.5, Montant__c = 1500 ) };
        insert oAffActif;
        
        ProjectMember__c oProjectMember = new ProjectMember__c(ProjectLine__c = oProjectLine.Id,User__c = userInfo.getUserId(), TJMTechnical__c = 752, project__c = oProject.id,TJMFunctional__c = 1000);
        insert oProjectMember;
        
        TimeSheet__c[] ts = new TimeSheet__c[]{ new TimeSheet__c(ProjectLine__c=oProjectLine.id, Duration__c = 1, Project__c = oProject.id, Date__c = date.today().addMonths(-1), User__c = userInfo.getUserId(), Description__c = 'Test Desc'),
                                                new TimeSheet__c(ProjectLine__c=oProjectLine.id, Duration__c = 1, Project__c = oProject.id, Date__c = date.today().addMonths(-1).addDays(1), User__c = userInfo.getUserId(), Description__c = 'test Desc' )
                                                };
        insert ts;
    }
    
    static testMethod void testProjectRegie(){
        test.startTest();
        
        ApexPages.StandardController sc = new ApexPages.StandardController(oProject);

        ProjectRegieManagerCtrl pr = new ProjectRegieManagerCtrl(sc);
        pr.tsWrapper.get(0).getTimesheets();
        pr.tsWrapper.get(0).getRemainingAfterOperation();

        pr.tsWrapper.get(0).timeSheetsByLine.values().get(0).get(0).getMonth();
        pr.createAssetInvoice();
        pr.tsWrapper.get(0).assetsTU.get(0).bSelected = true;
        pr.saveAll();
        PreFacture__c[] fs = [SELECT Id,(SELECT Id, AffectationActif__c FROM LignesFacture__r) FROM PreFacture__c];
        update fs; //Couverture update
        System.assertEquals(1,fs.size());
        Id createdAAf = fs.get(0).LignesFacture__r.get(0).AffectationActif__c;
        delete fs;
        System.assertEquals(0,[SELECT Id FROM AffectationActif__c WHERE Id = :createdAAf].size());
    }
}