public with sharing class FactureForfait {

    //public List<AffectationActif__c> affectationActifs {get;set;}

    public List<aafTupple> aafTupples{get;set;}

    public PreFacture__c preFacture {get;set;}

    public decimal montantHt{get;set;}

    public boolean reviewDesc{get;set;}

    public id ProjectId{get;set;}

    public boolean isError{get;set;}

    public String retUrl{get;set;}

    public FactureForfait(ApexPages.standardSetController scc){
        reviewDesc = false;
        List<AffectationActif__c> selectedAAF = (List<AffectationActif__c>) scc.getSelected();
        isError = false;
        returl = Apexpages.currentPage().getParameters().get('retUrl');
        if(retUrl == null)
            retUrl = '/';
        system.debug(selectedAAF);

        if(selectedAAF.size() == 0){
            isError = true;
            apexPages.addMessage(new Apexpages.message(ApexPages.severity.FATAL,'Vous devez cocher des affectations d\'actif à facturer avant de cliquer sur "Générer facture"'));
        }else{
            this.projectId = selectedAAF.get(0).Project__c;
            if(!isError){
                preFacture = new PreFacture__c(name = 'a');

                String Description = 'Projet Salesforce\n';
                decimal totalHT = 0;
                preFacture.non_comprise_dans_le_CA__c = false;
                this.aafTupples = new List<aafTupple>();
                for(AffectationActif__c a : selectedAAF) {
                    this.aafTupples.add(new aafTupple(a));
                    Description += (a.ProjectLine__r.referenceClient__c == null ? a.ProjectLine__r.Name : a.ProjectLine__r.referenceClient__c) + ' : ' + formatCurrency(a.montant__c) + ' €\n';
                    totalHt += a.Montant__c;
                }
                montantHt = totalHT;
                preFacture.Description__c = Description;
            }
        }
    }

    public pageReference returnToContract(){
        Pagereference ret;
        if(projectId == null )
            ret = new pageReference(returl);
        else
                ret = new pageReference('/'+projectId);
        return ret;

    }

    public pageReference genererFacture(){
        pageReference ret;
        if( preFacture.percent_Facture__c > 0 && preFacture.percent_Facture__c <100 ){
            preFacture.Description__c += '\nDont '+ preFacture.percent_Facture__c+'% Facturé à la '+ preFacture.Fait_generateur__c +' soit '+formatCurrency((preFacture.percent_Facture__c * montantHt)/100)+' €' ;
        }
        else{
            preFacture.Description__c =  'Projet Salesforce\n';
            Decimal montant = 0;
            for(aafTupple aa : this.aafTupples){
                montant += aa.lf.InvoicedAmount__c;
                preFacture.Description__c +=  aa.lf.Name + ' : ' + formatCurrency(aa.lf.InvoicedAmount__c) + ' €\n';
            }
            preFacture.Description__c += 'Total ' + formatCurrency(montant) + ' €'+(PreFacture.Fait_generateur__c != null ? ' facturé à la '+preFacture.Fait_generateur__c : '' );
        }

        //preFacture.Montant_HT__c 				= (preFacture.percent_Facture__c * montantHt)					/100;
        preFacture.project__c                  = projectId;
        preFacture.Name                        = 'TMP-'+(Math.random()*10000).round();
        reviewDesc = true;
        return ret;
    }

    public pageReference validateDescription(){
        pageReference ret;
        try{
            insert preFacture;
            List<LigneFacture__c> lfs = new List<LigneFacture__c>();
            for(aafTupple aa : this.aafTupples){
                lfs.add(aa.toligne(preFacture.percent_Facture__c,preFacture.Id));
            }
            insert lfs;
            ret = new pageReference('/'+ preFacture.id);
        }catch(Exception e){
            system.debug(e.getMessage());
            Apexpages.addMessage(new Apexpages.Message(ApexPAges.Severity.FATAL,e.getMEssage()));
        }
        return ret;
    }



    public static string formatCurrency(decimal input){
        String formattedValue = '';
        //Arrondi éventuel et formatage selon la 'locale' de l'utilisateur
        formattedValue = input == null ? '' : input.format();
        //Si on a qu'un chiffre après la virgule, on rajoute un 0 pour avoir '123 456,70' au lieu de '123 456,7'
        if(formattedValue.substringAfterLast(',').length() == 1)
            formattedValue += '0';
        return formattedValue;
    }

    public class aafTupple{
        public AffectationActif__c aaf{get;set;}
        public LigneFacture__c lf{get;set;}
        public aafTupple(AffectationActif__c aaf){
            this.aaf = aaf;
            this.lf = new LigneFacture__c(AffectationActif__c = aaf.Id , invoicedAmount__c = aaf.ResteAFacturer__c, SectionAnalytique__c=aaf.SectionAnalytique__c, ProjectLine__c = aaf.ProjectLine__c, Name = (aaf.ProjectLine__r.referenceClient__c == null ? aaf.ProjectLine__r.Name : aaf.ProjectLine__r.referenceClient__c));
        }
        public LigneFacture__c toligne(decimal percentInvoiced, Id PrefactureId){
            if(percentInvoiced != null && percentInvoiced > 0){
                this.lf.invoicedAmount__c = this.aaf.Montant__c * percentInvoiced / 100;
            }
            this.lf.invoicedQuantity__c = ( aaf.NbJours__c != null && aaf.NbJours__c > 0 ) ? this.lf.InvoicedAmount__c / ( aaf.Montant__c / aaf.NbJours__c ) : 0;
            this.lf.PreFacture__c = PrefactureId;
            return this.lf;
        }
    }


}