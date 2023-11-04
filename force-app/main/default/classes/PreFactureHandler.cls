/**
 * Created by DHU on 27/05/2019.
 */

public with sharing class PreFactureHandler implements ITrigger {

    public static Id[] FacturesRegiesDeleted;

    static {
        FacturesRegiesDeleted = new Id[]{};
    }

    public void bulkBefore() {
    }

    public void bulkAfter() {
    }

    public void beforeInsert(SObject so) {
    }

    public void beforeUpdate(SObject oldSo, SObject so) {
    }

    public void beforeDelete(SObject so) {
        if( (Boolean) so.get( 'PrefactureRegie__c' ) )
            FacturesRegiesDeleted.add(so.Id);
    }

    public void afterInsert(SObject so) {
    }

    public void afterUpdate(SObject oldSo, SObject so) {
    }

    public void afterDelete(SObject so) {

    }

    public void andFinally() {
        if(!FacturesRegiesDeleted.isEmpty()) {
            AffectationActif__c[] aasToDelete = new AffectationActif__c[]{};
            for(LigneFacture__c l : [SELECT Id, AffectationActif__c, InvoicedAmount__c, AffectationActif__r.Montant__c FROM LigneFacture__c WHERE PreFacture__c IN : FacturesRegiesDeleted AND AffectationActif__c != null])
                if(l.InvoicedAmount__c == l.AffectationActif__r.Montant__c)
                    aasToDelete.add(new AffectationActif__c(Id = l.AffectationActif__c));
            FacturesRegiesDeleted = new Id[]{};
            if(!aasToDelete.isEmpty())
                delete aasToDelete;
        }
    }
}