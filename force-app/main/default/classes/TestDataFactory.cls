/*
* Company    : HARDIS Bordeaux
* Created on : 24-07-2018
* Author     : BTH
*/
public class TestDataFactory {
    public static Account createAccount(String name, Boolean insertData){
        Account acc = new Account(Name = name);
        if(insertData) insert acc;
        return acc;
    }

    public static Contact createContact(String firstName, String lastName, Account account, Boolean insertData){
        Contact c = new Contact(FirstName = firstName, LastName = lastName, AccountId = account.Id, Phone = '+33505050505');
        if(insertData) insert c;
        return c;
    }

    public static Product2 createProduct2(String name, Boolean insertData){
        Product2 pdt = new Product2(Name = name, ProductCode = 'BADVA', Family = 'Business Applications', Description = 'Agile & Devops', IsActive = true);
        if(insertData) insert pdt;
        return pdt;
    }

    public static PricebookEntry createPricebookEntry(Id pricebookId, Product2 pdt, Boolean insertData){
        PricebookEntry pbe = new PricebookEntry(Pricebook2Id = pricebookId, Product2Id = pdt.Id, UnitPrice = 200, IsActive = true);
        if(insertData) insert pbe;
        return pbe;
    }

    public static Opportunity createOpportunity(String name, Boolean insertData){
        Opportunity opp = new Opportunity (Name = name, StageName = 'Besoin', CloseDate = Date.today());
        if(insertData) insert opp;
        return opp;
    }

    public static OpportunityLineItem createOpportunityLineItem(Opportunity opp, PricebookEntry pbe, Boolean insertData){
        OpportunityLineItem oli = new OpportunityLineItem(OpportunityId = opp.Id, Quantity = 10, PricebookEntryId = pbe.Id, UnitPrice = 200);
        if(insertData) insert oli;
        return oli;
    }

    public static OpportunityTeamMember createOpportunityTeamMember(Id userId, Opportunity opp, Boolean insertData){
        OpportunityTeamMember oppTeamMember = new OpportunityTeamMember(OpportunityId = opp.Id, UserId = userId);
        if(insertData) insert oppTeamMember;
        return oppTeamMember;
    }

    public static OpportunityContactRole createOpportunityContactRole(Opportunity opp, Contact contact, Boolean insertData){
        OpportunityContactRole oppContactRole = new OpportunityContactRole(OpportunityId = opp.Id, ContactId = contact.Id);
        if(insertData) insert oppContactRole;
        return oppContactRole;
    }
}