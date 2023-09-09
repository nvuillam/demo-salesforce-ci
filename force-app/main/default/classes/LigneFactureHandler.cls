/**
 * Created by DHU on 27/05/2019.
 */

public with sharing class LigneFactureHandler implements ITrigger {

    public static set<Id> AffectationActifToRecompute;
    public static set<Id> FacturesToRecompute;

    static {
        AffectationActifToRecompute = new set<Id>();
        FacturesToRecompute = new set<Id>();
    }

    public void bulkBefore() {
    }

    public void bulkAfter() {
        List<LigneFacture__c> ls = (LigneFacture__c[]) (Trigger.isDelete ? Trigger.old : Trigger.new );
        for(LigneFacture__c l : ls){
            if(l.AffectationActif__c != null && ! AffectationActifToRecompute.contains(l.AffectationActif__c)){
                AffectationActifToRecompute.add(l.AffectationActif__c);
            }
            if(Trigger.isUpdate) {
                LigneFacture__c old = ((LigneFacture__c) Trigger.oldMap.get(l.Id));
                if (old.AffectationActif__c != l.AffectationActif__c && !AffectationActifToRecompute.contains(old.AffectationActif__c)) {
                    AffectationActifToRecompute.add(old.AffectationActif__c);
                }
            }
            FacturesToRecompute.add(l.PreFacture__c);
        }
    }

    public void beforeInsert(SObject so) {
    }

    public void beforeUpdate(SObject oldSo, SObject so) {
    }

    public void beforeDelete(SObject so) {
    }

    public void afterInsert(SObject so) {
    }

    public void afterUpdate(SObject oldSo, SObject so) {
    }

    public void afterDelete(SObject so) {
    }

    public void andFinally() {
        if(!AffectationActifToRecompute.isEmpty()){
            List<AffectationActif__c> toUp = new List<AffectationActif__c>();
            for(AggregateResult agg : [SELECT AffectationActif__c, SUM(InvoicedAmount__c) montantFacture FROM LigneFacture__c WHERE AffectationActif__c IN : AffectationActifToRecompute  GROUP BY AffectationActif__c ]){
                system.debug('computing montant Facture');
                system.debug(agg);
                toUp.add(new AffectationActif__c(Id = (Id) agg.get('AffectationActif__c'), MontantFacture__c = (Decimal) agg.get('montantFacture')));
            }
            update toUp;
        }
        List<PreFacture__c> toUp = new List<PreFacture__c>();
        for(AggregateResult agg : [SELECT PreFacture__c, Sum(InvoicedAmount__c) montant FROM LigneFacture__c WHERE PreFacture__c in : FacturesToRecompute AND PreFacture__r.isDeleted = false GROUP BY Prefacture__c]){
            toUp.add(new PreFacture__c(Id = (Id) agg.get('PreFacture__c'), Montant_HT__c = (Decimal) agg.get('montant')));
        }
        update toUp;
    }
}