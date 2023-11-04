/**
 * Created by MSALI on 12/04/2018.
 */

public with sharing class DAL {

    public static Opportunity getOpportunityToClone(Id idOpportunity) {
        Opportunity opportunityToClone;

        if (idOpportunity != null) {
            opportunityToClone = [
                    SELECT Id,Name,Account.Name,StageName,Probability,CloseDate,Amount,DAS__c,Type,Entite__c,Technologie__c,Territoire__c,LeadSource,Modalites_de_facturation__c,Description,
                            Forfait_Regie__c,Budget_client__c,Commentaire_accord__c,Etat_avancement__c,Date_de_debut_de_projet__c
                    FROM Opportunity
                    WHERE Id = :idOpportunity
            ];
        }
        return opportunityToClone;
    }
/*
    public static List<OpportunityTeamMember> getOpportunityTeamToClone(Id idOpportunity) {
        List<OpportunityTeamMember> members = new List<OpportunityTeamMember>();
        if (idOpportunity != null) {
            for (OpportunityTeamMember member : [SELECT Id,User.Name,TeamMemberRole,OpportunityAccessLevel,OpportunityId FROM OpportunityTeamMember
            WHERE OpportunityId = :idOpportunity]) {
                members.add(member);
            }
        }
        return members;
    }

    public static List<OpportunityLineItem> getOpportunityProdutcsToClone(Id idOpportunity) {
        List<OpportunityLineItem> products = new List<OpportunityLineItem>();
        if (idOpportunity != null) {
            for (OpportunityLineItem product : [SELECT Id,PricebookEntryId,OpportunityId,Name,Product2.Name,ProductCode,ListPrice,Quantity,
                    Famille_de_produit__c,Description,ServiceDate,UnitPrice FROM OpportunityLineItem WHERE OpportunityId = :idOpportunity]) {
                products.add(product);
            }
        }
        return products;
    }

    public static List<OpportunityContactRole> getOpportunityContactRolesToClone(Id idOpportunity) {
        List<OpportunityContactRole> contacts = new List<OpportunityContactRole>();
        if (idOpportunity != null) {
            for (OpportunityContactRole c : [SELECT Id,Role,ContactId,Contact.Name,OpportunityId,Opportunity.Name from OpportunityContactRole
            WHERE OpportunityId = :idOpportunity]) {
                contacts.add(c);
            }
        }
        return contacts;
    }
*/
    //NEW
    public static Map<Id, List<OpportunityLineItem>> getOpportunityLineItemFromOppSource (Set<Id> idsOppSources)
    {
        Map<Id, List<OpportunityLineItem>> result = new Map<Id, List<OpportunityLineItem>> ();
        if(idsOppSources.size() > 0)
        {
            for(OpportunityLineItem opl : [ SELECT Id,PricebookEntryId,OpportunityId,Name,Product2.Name,ProductCode,ListPrice,Quantity,
                                                Famille_de_produit__c,Description,ServiceDate,UnitPrice
                                            FROM OpportunityLineItem
                                            WHERE OpportunityId IN :idsOppSources])
            {
                if(!result.containsKey(opl.OpportunityId))
                {
                    result.put(opl.OpportunityId, new list<OpportunityLineItem>());
                }
                result.get(opl.OpportunityId).add(opl);
            }
        }
        return result;
    }

    public static Map<Id, List<OpportunityContactRole>> getOpportunityContactRoleFromOppSource (Set<Id> idsOppSources)
    {
        Map<Id, List<OpportunityContactRole>> result = new Map<Id, List<OpportunityContactRole>> ();
        if(idsOppSources.size() > 0)
        {
            for(OpportunityContactRole ocr : [  SELECT Id,Role,ContactId,Contact.Name,OpportunityId,Opportunity.Name
                                                FROM OpportunityContactRole
                                                WHERE OpportunityId IN :idsOppSources])
            {
                if(!result.containsKey(ocr.OpportunityId))
                {
                    result.put(ocr.OpportunityId, new list<OpportunityContactRole>());
                }
                result.get(ocr.OpportunityId).add(ocr);
            }
        }
        return result;
    }

    public static Map<Id, List<OpportunityTeamMember>> getOpportunityTeamMemberFromOppSource (Set<Id> idsOppSources)
    {
        Map<Id, List<OpportunityTeamMember>> result = new Map<Id, List<OpportunityTeamMember>> ();
        if(idsOppSources.size() > 0)
        {
            for(OpportunityTeamMember otm :    [SELECT Id,User.Name,TeamMemberRole,OpportunityAccessLevel,OpportunityId
                                                FROM OpportunityTeamMember
                                                WHERE OpportunityId IN :idsOppSources])
            {
                if(!result.containsKey(otm.OpportunityId))
                {
                    result.put(otm.OpportunityId, new list<OpportunityTeamMember>());
                }
                result.get(otm.OpportunityId).add(otm);
            }
        }
        return result;
    }

}