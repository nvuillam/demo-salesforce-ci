/**
 * Created by MSALI on 26/04/2018.
 */
@isTest
public with sharing class TEST_CloneComponentOpportunityController {

    @isTest
    public static void TestClonerOpportunite() {

        Account acc = new Account( Name = 'Client1');
        insert acc;

        Opportunity opportunityToClone = new Opportunity(Name = 'Opp to clone11', Account = acc, StageName = 'Besoin', CloseDate = Date.Today()
        , Probability = 0.1, DAS__c = 'BA', Entite__c = 'Lyon', Type = 'Migration', LeadSource = 'Autre', Territoire__c = 'Lyon');
        insert opportunityToClone;


        Product2 produit = new Product2(Name = 'Produit', Family = 'Adelia Studio', isActive = True, ProductCode = 'll');
        insert produit;

        Id pricebookId = Test.getStandardPricebookId();

        PricebookEntry pb = new PricebookEntry(Pricebook2Id=pricebookId,Product2=produit,Product2Id=produit.Id,UnitPrice=30,isActive=true);
        insert pb;

        Pricebook2 p = new Pricebook2(Name='Custom pricebook',isActive=true);
        insert p;

        PricebookEntry customPrice = new PricebookEntry(Pricebook2Id= p.Id,Product2Id=produit.Id,UnitPrice=10,IsActive=true);
        insert customPrice;


        OpportunityLineItem oppLineItem = new OpportunityLineItem( OpportunityId=opportunityToClone.Id,PricebookEntryId=customPrice.Id, Product2 = produit, Quantity = 2, UnitPrice = 20);
        insert oppLineItem;

        contact contact = new Contact(LastName='Benoit',Account=acc,Email='Test@gmail.com',MobilePhone='+33760509396');
        insert contact;

        OpportunityContactRole contactRole = new OpportunityContactRole(Role='Client',OpportunityId=opportunityToClone.Id,ContactId=contact.id);
        insert contactRole;
    }
    @isTest
    public static void testSelectOptions(){
        Account acc = new Account( Name = 'Client1');
        insert acc;

        Opportunity opportunity = new Opportunity(Name = 'Opp', Account = acc, StageName = 'Besoin', CloseDate = Date.Today()
        , Probability = 0.1, DAS__c = 'BA', Entite__c = 'Lyon', Type = 'Migration', LeadSource = 'Autre', Territoire__c = 'Lyon');
        insert opportunity;
    }
}