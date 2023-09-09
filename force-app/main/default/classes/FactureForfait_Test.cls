/**
 * Created by DHU on 26/12/2018.
 */
@isTest
public with sharing class FactureForfait_Test {
    private static testMethod void testFactureForfait(){

        insert new ActivationSettings__c(LigneFactureTR__c=true, ProjectLine_TR__c=true, PreFactureTR__c = true, SetupOwnerId=userInfo.getOrganizationId());
        Account acc = new Account(Name = 'Synefo');
        insert acc;

        Project__c project = new Project__c(Account__c = acc.Id, Name = 'TimeSheet', ProjectTeam__c = UserInfo.getName(), IsActive__c = true, RequireTimeSheetDescription__c = false);
        insert project;

        ProjectLine__c pl = new ProjectLine__c(Project__c = project.id, Name='Test',NumeroDeLigne__c=1, Type__c='Forfait');
        insert pl;

        AffectationActif__c aa = new AffectationActif__c(ProjectLine__c = pl.id, Project__c = project.id, Montant__c = 10000, NbJours__c = 10);
        insert aa;

        projectMember__c pm = new ProjectMember__c(Project__c=project.id, ProjectLine__c = pl.id, User__c = userInfo.getUserId());
        insert pm;

        Test.startTest();

        ApexPages.StandardSetController ssc = new ApexPages.StandardSetController(new List<AffectationActif__c> {aa});
        FactureForfait ctrl = new FactureForfait(ssc); //Test sans rien de selectionné
        system.assertEquals(1, ApexPages.getMessages().size());

        ssc.setSelected(new List<AffectationActif__c>{aa});
        ctrl = new FactureForfait(ssc);
        ctrl.preFacture.percent_Facture__c = 10;

        ctrl.preFacture.Date_emission__c = date.today();
        ctrl.genererFacture();
        ctrl.preFacture.percent_Facture__c = 0;
        ctrl.aafTupples.get(0).lf.InvoicedAmount__c = 1000;
        ctrl.genererFacture();
        ctrl.validateDescription();

        LigneFacture__c l = [SELECT Id,InvoicedAmount__c, AffectationActif__c FROM LigneFacture__c WHERE AffectationActif__c =: aa.Id];
        System.assertEquals(1000, l.InvoicedAmount__c);
        l.InvoicedAmount__c = 2000;
        update l;
         l = [SELECT Id,InvoicedAmount__c, AffectationActif__c , PreFacture__r.Montant_HT__c FROM LigneFacture__c WHERE AffectationActif__c = : aa.Id];
        system.assertEquals(2000, l.PreFacture__r.Montant_HT__c);
        delete l;


        ctrl.returnToContract();
        ctrl.projectId = null;
        ctrl.returnToContract();
        Test.stopTest();
    }

}