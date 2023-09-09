/**
 * Created by DHU on 19/12/2018.
 */

@IsTest
private class LTNG02_ProjectSetup_Test {
    @IsTest
    private static void testLTNG02_ProjectSetup() {
        ActivationSettings__c t = new ActivationSettings__c(SetupOwnerId=UserInfo.getOrganizationId(), ProjectLine_TR__c=true, TimeSheet_TR__c=true);
        insert t;
        Account acc = new Account(Name = 'Synefo');
        insert acc;

        Project__c project = new Project__c(Account__c = acc.Id, Name = 'TimeSheet', ProjectTeam__c = UserInfo.getName(), IsActive__c = true, RequireTimeSheetDescription__c = true);
        insert project;
        User otherUser = [SELECt id FROM User Where Id !=: UserInfo.getUserId() LIMIT 1];
        Test.startTest();
        //On émule la création d'une nouvelle ligne
        LTNG02_ProjectSetup.lineWrapper l = new LTNG02_ProjectSetup.lineWrapper(new ProjectLine__c());
        l.analytic = 'SCRM92S';
        l.initialQuantity = 100;
        l.revisedQuantity = 100;
        l.relatedAffectationActif = new AffectationActif__c( Project__c = project.id, NbJours__c=100, Montant__c=10000, Date__c = date.today() );
        l.name = 'testLine';
        l.type = 'Forfait';
        l.isActive = true;
        l.flattenedMembers = userInfo.getUserId()+';'+otherUser.Id;
        //Création de la ligne
        LTNG02_ProjectSetup.ProjectDescriptorWrapper ret = LTNG02_ProjectSetup.upsertLines(JSON.serialize(new List<LTNG02_ProjectSetup.lineWrapper> {l}),project.id);
        System.assertEquals(1, ret.lines.size());
        System.assertEquals(0, ret.lines.get(0).codeWebSi);
        System.assertNotEquals(null, ret.lines.get(0).id);
        System.assertEquals(2, [SELECT Id FROM ProjectMember__c].size());

        //On se supprime de la ligne en tant que project member
        ret.lines.get(0).flattenedMembers = otherUser.Id;
        ret = LTNG02_ProjectSetup.upsertLines(JSON.serialize(ret.lines),project.id);
        System.assertEquals(1, [SELECT Id FROM ProjectMember__c].size());

        //On se remet sur la ligne
        LTNG02_ProjectSetup.ImOnTheLine(ret.lines.get(0).id);
        System.assertEquals(2, [SELECT Id FROM ProjectMember__c].size());

        //On se resupprime de la ligne
        LTNG02_ProjectSetup.ImOnTheLine(ret.lines.get(0).id);
        System.assertEquals(1, [SELECT Id FROM ProjectMember__c].size());

        //On désactive
        LTNG02_ProjectSetup.updateActiveLineStatus(ret.lines.get(0).id,false);
        System.assertEquals(false, [SELECT Id, Active__c FROM ProjectLine__c LIMIT 1].get(0).Active__c);

        //On supprime la ligne
        LTNG02_ProjectSetup.destroyLines(JSON.serialize(ret.lines), project.id);
        system.assertEquals(0,[SELECT Id FROM ProjectLine__c].size());
        Test.stopTest();
    }
}