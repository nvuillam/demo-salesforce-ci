/*
----------------------------------------------------------------------
-- - Name          : AP01_CloneOpportunityWithRelatedLists
-- - Author        : ECO
-- - Description   : methods for Global Action CloneOppWithRelatedList
-- - Module        : CRM HARDIS
--
-- Maintenance History:
--
-- Date         Name  Version  Remarks  
-- -----------  ----  -------  ---------------------------------------
-- 29-05-2018   ECO    1.0      Initial version
----------------------------------------------------------------------
*/
public class AP01_CloneOpportunityWithRelatedLists {
    public static void bindRelatedLists(List<Opportunity> newListOpp){
        //Init des oppSources d'où lon souhaite cloner les listes associées
        Set<Id> oppSources = new Set<Id>();
        for(Opportunity newOpportunity : newListOpp) {
            if(newOpportunity.OpportunityToClone__c != null){
                oppSources.add(newOpportunity.OpportunityToClone__c);
            }
        }
        if(!oppSources.isEmpty()){
            //Récup des listes associées mappées par Id des opp sources
            Map<Id, List<OpportunityLineItem>> mapOpportunityLineItemMappedByOpportunity = DAL.getOpportunityLineItemFromOppSource(oppSources);
            Map<Id, List<OpportunityContactRole>> mapOpportunityContactRoleMappedByOpportunity = DAL.getOpportunityContactRoleFromOppSource(oppSources);
            Map<Id, List<OpportunityTeamMember>> mapOpportunityTeamMemberMappedByOpportunity = DAL.getOpportunityTeamMemberFromOppSource(oppSources);

            List<OpportunityLineItem> opportunityLineItemsToInsert = new List<OpportunityLineItem>();
            List<OpportunityContactRole> opportunityContactRolesToInsert = new List<OpportunityContactRole>();
            List<OpportunityTeamMember> opportunityTeamMembersToInsert = new List<OpportunityTeamMember>();

            for(Opportunity newOpportunity : newListOpp){
                if(newOpportunity.OpportunityToClone__c != null){
                    if(mapOpportunityLineItemMappedByOpportunity.containsKey(newOpportunity.OpportunityToClone__c)) {
                        for (OpportunityLineItem oppLineItem : mapOpportunityLineItemMappedByOpportunity.get(newOpportunity.OpportunityToClone__c).deepClone(false)) {
                            oppLineItem.OpportunityId = newOpportunity.Id;
                            opportunityLineItemsToInsert.add(oppLineItem);
                        }
                    }
                    if(mapOpportunityContactRoleMappedByOpportunity.containsKey(newOpportunity.OpportunityToClone__c)){
                        for(OpportunityContactRole oppContactRole : mapOpportunityContactRoleMappedByOpportunity.get(newOpportunity.OpportunityToClone__c).deepClone(false)){
                            oppContactRole.OpportunityId = newOpportunity.Id;
                            opportunityContactRolesToInsert.add(oppContactRole);
                        }
                    }
                    if(mapOpportunityTeamMemberMappedByOpportunity.containsKey(newOpportunity.OpportunityToClone__c)){
                        for(OpportunityTeamMember oppTeamMember : mapOpportunityTeamMemberMappedByOpportunity.get(newOpportunity.OpportunityToClone__c).deepClone(false)){
                            oppTeamMember.OpportunityId = newOpportunity.Id;
                            opportunityTeamMembersToInsert.add(oppTeamMember);
                        }
                    }
                }
            }

            insert opportunityLineItemsToInsert;
            insert opportunityContactRolesToInsert;
            insert opportunityTeamMembersToInsert;
        }
    }
}