/*
----------------------------------------------------------------------
-- - Name          : AP01_CloneOppWithRelatedLists_TEST
-- - Author        : ECO
-- - Description   : AP01_CloneOpportunityWithRelatedLists
-- - Module        : CRM HARDIS
--
-- Maintenance History:
--
-- Date         Name  Version  Remarks
-- -----------  ----  -------  ---------------------------------------
-- 30-05-2018   ECO    1.0      Initial version
----------------------------------------------------------------------
*/
@isTest
private class AP01_CloneOppWithRelatedLists_TEST{
    static Account account;
    static Contact contact;
    static Product2 pdt;
    static PricebookEntry pbe;
    static Opportunity opp;
    static OpportunityLineItem oppLineItem;
    static OpportunityTeamMember oppTeamMember;
    static OpportunityContactRole oppContactRole;

    static {
        account = TestDataFactory.createAccount('Test', true);
        contact = TestDataFactory.createContact('Toto', 'Tutu', account, true);
        pdt = TestDataFactory.createProduct2('Agile & Devops', true);
        pbe = TestDataFactory.createPricebookEntry(Test.getStandardPricebookId(), pdt, true);
        opp = TestDataFactory.createOpportunity('opp test', true);
        oppLineItem = TestDataFactory.createOpportunityLineItem(opp, pbe, true);
        oppTeamMember = TestDataFactory.createOpportunityTeamMember(UserInfo.getUserId(), opp, true);
        oppContactRole = TestDataFactory.createOpportunityContactRole(opp, contact, true);
    }

    @isTest
    static void testBindRelatedLists (){
        Opportunity newOpp = TestDataFactory.createOpportunity('opp 2', false);
        newOpp.OpportunityToClone__c = opp.Id;
        insert newOpp;

        List<OpportunityContactRole> result = [ SELECT Id,Role,ContactId,Contact.Name,OpportunityId,Opportunity.Name
                                                FROM OpportunityContactRole
                                                WHERE OpportunityId = :newOpp.Id];

        System.assertNotEquals(0, result.size());
    }
}